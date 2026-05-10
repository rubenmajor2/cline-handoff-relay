"""emsu_classifier_hook.py — Cline-Router classifier + R1-R9 fail-safe.

Plugs into LiteLLM Proxy v1.83.14+ via `litellm_settings.callbacks` config.
Subclasses `litellm.integrations.custom_logger.CustomLogger` per the
canonical pre-call / post-call hook API.

Design C (hybrid) per spec §2:
  - Tier 1: fast heuristic — handles ~70-80% of turns at ~200μs
  - Tier 2: tiny Ollama llama3.2:1b only on ambiguous ~20-30% (~30-80ms)

Fail-safe R1-R9 per spec §4. Audit log to ~/.cline-router/audit.sqlite.

Reversal: don't load this hook, OR set CLINE_ROUTER_FORCE_ANTHROPIC=1 to
short-circuit every classifier call to "hard" so 100% goes to Anthropic.
"""
from __future__ import annotations

import asyncio
import hashlib
import json
import os
import re
import sqlite3
import time
import traceback
from pathlib import Path
from typing import Any, Optional

# litellm imports — these are stable across 1.74-1.84 per subagent research
try:
    from litellm.integrations.custom_logger import CustomLogger
    import litellm
except ImportError:
    # Allow tests / lint to load module without litellm present
    class CustomLogger:  # type: ignore
        pass
    litellm = None  # type: ignore


# ===========================================================================
# Configuration
# ===========================================================================

AUDIT_DB_PATH = Path.home() / ".cline-router" / "audit.sqlite"
AUDIT_DB_PATH.parent.mkdir(parents=True, exist_ok=True)

# Phase 5 ROLLOUT MODE — REVISION 1 dropped the shadow phase per Ruben Q2=YES.
# Default is now "live": route per classifier, fall back on R1-R9 fire.
#   "live"     = rewrite + fall back on R1-R9 (default; Phase 5B/5C)
#   "disabled" = log only, do NOT rewrite model (emergency reversal kill switch)
#   "shadow"   = legacy synonym for disabled (kept for backwards compat)
ROLLOUT_MODE = os.environ.get("CLINE_ROUTER_MODE", "live")

FORCE_ANTHROPIC = os.environ.get("CLINE_ROUTER_FORCE_ANTHROPIC") in ("1", "true", "yes")

# Default Ollama route model. Overridden by hook based on availability:
# emsu-qwen:7b-lora > qwen2.5-coder:14b > qwen2.5-coder:32b
DEFAULT_OLLAMA_MODEL = os.environ.get("CLINE_ROUTER_OLLAMA_MODEL", "ollama-qwen-14b")

# Classifier tunables (calibrated via Phase F backtest, then frozen)
TIER1_ROUTINE_CONF = 0.85
TIER2_ROUTINE_CONF = 0.80

# R9 latency floor (seconds). If Ollama takes longer than this we still
# return the answer but tag it "slow" and demote class for next hour.
OLLAMA_SLOW_FLOOR_SEC = 8.0

# Anthropic 2026 pricing (per 1M tokens). Used for cost estimation in audit.
COST_USD_PER_M = {
    "claude-sonnet-4-6":  {"in": 3.00, "out": 15.00},
    "claude-opus-4-7":    {"in": 15.00, "out": 75.00},
    "claude-haiku-4-5":   {"in": 1.00, "out": 5.00},
}


# ===========================================================================
# Hard-floor regex (.clinerules/40 v2)
# ===========================================================================

HARD_FLOOR_PATTERNS = [
    # money
    (re.compile(r"\b(refund|chargeback|charge.*card|authorize\.?net|authnet|"
                r"quickbooks|qb\s*invoice|payment_suspension|payment\s*plan|"
                r"affirm\s*loan|void\s*transaction|credit\s*memo)\b", re.I),
     "money"),
    # regulator / accreditor
    (re.compile(r"\b(capce|azdhs|ca\s*emsa|tdshs|bpss|nremt|asbpce|"
                r"regulator|grievance|noi|notice\s*of\s*investigation|"
                r"accreditor|state.*ems\s*bureau)\b", re.I),
     "regulator"),
    # student-facing compose
    (re.compile(r"\b(student-facing|outbound\s*to.*student|email\s*the\s*student|"
                r"sms.*student|grading@|info@emsuniversity|"
                r"compose.*student\s*reply|draft.*student\s*email)\b", re.I),
     "student_compose"),
    # patient / clinical advice
    (re.compile(r"\b(patient|clinical\s*decision|medical\s*advice|"
                r"prescribing|treatment\s*recommendation)\b", re.I),
     "patient"),
    # surfaces where wrong code costs Ruben time
    (re.compile(r"\b(code_patch_large|safe.deploy|deploy.*production|"
                r"migrate.*schema|drop.*table)\b", re.I),
     "high_blast_code"),
]


# Tools that strongly suggest routine work — REVISION 1 expanded set based on
# measured tool frequency over 79,547 turns / 30d. Original spec whitelist
# only matched 1.8% of real turns; this set should hit 45-60%.
ROUTINE_TOOL_NAMES = frozenset({
    # Read-only file/dir ops
    "read_file", "list_files", "search_files",
    # Read-only DB / MCP queries
    "mcp::execute_query", "mcp::fetch_data", "mcp::read_query",
    "mcp::describe_table", "mcp::list_tables", "mcp::run_moodle_query",
    # Read-only EMSU lookups
    "mcp::check_student", "mcp::check_ticket", "mcp::check_qb_invoices",
    "mcp::check_server_logs", "mcp::server_status",
    "mcp::check_moodle_enrollment", "mcp::check_proctoring_status",
    "mcp::check_exam_enforcement", "mcp::check_integrity_reflections",
    "mcp::check_exam_overrides", "mcp::check_externship_status",
    "mcp::check_class_roster", "mcp::check_student_comms",
    "mcp::check_grievance", "mcp::lookup_paperwork_state",
    "mcp::get_student_360", "mcp::get_externship_pending_queue",
    "mcp::get_my_waiting_tickets", "mcp::get_voice_escalation_queue",
    "mcp::get_voice_call_context",
    # Read-only RUBEN/KAIZEN
    "mcp::orchestrator_status", "mcp::list_events", "mcp::get_event_detail",
    "mcp::list_decisions", "mcp::list_ideas", "mcp::get_idea_progress",
    "mcp::get_patterns", "mcp::get_config", "mcp::get_activity_feed",
    "mcp::get_proactive_items", "mcp::error_watchdog", "mcp::workflow_stats",
    "mcp::check_ruben_state", "mcp::get_ruben_issues", "mcp::get_ruben_failures",
    "mcp::kaizen_session_summary", "mcp::kaizen_scan_failures",
    "mcp::kaizen_coverage_report",
    # Read-only handoff/server-file
    "mcp::read_handoff_notes", "mcp::read_server_file",
    # ssh + execute_command — read-mostly; the deploy/sudo regex below catches the rest
    "mcp::ssh_command", "execute_command",
    # Browser + search
    "browser_action", "mcp::brave_web_search", "mcp::brave_local_search",
    # Routine writes (handoff notes, ideas — internal-only state)
    "mcp::update_handoff_notes", "mcp::create_idea",
    # iMessage reads (sends are HARD per rule 31)
    "mcp::read_messages", "mcp::search_messages", "mcp::list_chats",
    "mcp::find_chat", "mcp::get_chat_participants",
    # Completion + Q-cards
    "attempt_completion",
})

# Tools that ALWAYS go to Anthropic regardless of context — REVISION 1 §2 HARD_TOOL_NAMES.
# Override the routine whitelist when both match.
HARD_TOOL_NAMES = frozenset({
    "write_to_file", "replace_in_file",            # code changes
    "use_subagents",                                # delegating = hard parent task
    "mcp::reload_php_fpm",                          # production impact
    "mcp::deploy_moodle_content",                   # production change
    "mcp::safe_deploy_file",                        # production change
    "mcp::purge_moodle_cache",                      # production state change
    "mcp::send_message",                            # external comm rule 31
    "mcp::post_discord_message",                    # external comm
    "mcp::add_ticket_comment",                      # student-facing potential
    "mcp::update_ticket",                           # state change
    "mcp::add_observations", "mcp::create_entities", # memory writes that affect future agents
    "mcp::execute_command",                         # if not native execute_command
})

# When execute_command / mcp::ssh_command land, escalate to HARD if the command
# string contains any of these dangerous-write tokens.
SSH_HARD_REGEX = re.compile(
    r"\b(sudo|systemctl|service\s+\w+\s+(restart|reload|stop|start)|"
    r"deploy|safe-deploy|safe_deploy|drop\s+(table|database)|"
    r"migrate\s+(up|down|reset)|truncate|alter\s+(table|database)|"
    r"rm\s+-rf|chmod\s+\d{3,4}\s+/(etc|var|opt)|chown|"
    r"git\s+(push|reset|rebase\s+-i|force)|"
    r"docker\s+(rm|kill|stop)|kubectl\s+(delete|apply))\b",
    re.I)


# ===========================================================================
# Audit DB
# ===========================================================================

def _audit_db_init():
    with sqlite3.connect(AUDIT_DB_PATH) as db:
        db.executescript("""
        CREATE TABLE IF NOT EXISTS turns (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ts INTEGER NOT NULL,
          request_hash TEXT NOT NULL,
          classifier_label TEXT NOT NULL,
          classifier_confidence REAL,
          classifier_reason TEXT,
          classifier_tier INTEGER,
          ollama_called INTEGER NOT NULL,
          ollama_model TEXT,
          ollama_latency_ms INTEGER,
          ollama_input_tokens INTEGER,
          ollama_output_tokens INTEGER,
          fail_reason TEXT,
          fallback_called INTEGER NOT NULL,
          fallback_model TEXT,
          fallback_latency_ms INTEGER,
          total_latency_ms INTEGER NOT NULL,
          estimated_cost_saved_usd REAL,
          estimated_cost_paid_usd REAL,
          request_size_bytes INTEGER,
          response_size_bytes INTEGER,
          rollout_mode TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_turns_ts ON turns(ts);
        CREATE INDEX IF NOT EXISTS idx_turns_fail ON turns(fail_reason);
        CREATE VIEW IF NOT EXISTS v_daily_rollup AS
        SELECT
          date(ts, 'unixepoch', 'localtime') AS day,
          COUNT(*) AS turns,
          SUM(ollama_called) AS routed_to_local,
          SUM(fallback_called) AS fallbacks,
          ROUND(100.0 * SUM(fallback_called) / NULLIF(SUM(ollama_called), 0), 1) AS fallback_rate_pct,
          ROUND(SUM(estimated_cost_saved_usd), 2) AS dollars_saved,
          ROUND(SUM(estimated_cost_paid_usd), 2) AS dollars_paid_anthropic,
          ROUND(AVG(total_latency_ms), 0) AS avg_latency_ms,
          ROUND(MAX(total_latency_ms), 0) AS p95_latency_ms
        FROM turns GROUP BY 1 ORDER BY 1 DESC;
        """)
        db.commit()

_audit_db_init()


def _audit_write(row: dict):
    cols = ",".join(row.keys())
    qs = ",".join("?" for _ in row)
    try:
        with sqlite3.connect(AUDIT_DB_PATH) as db:
            db.execute(f"INSERT INTO turns ({cols}) VALUES ({qs})", tuple(row.values()))
            db.commit()
    except Exception as e:
        # Audit must never break the proxy. Log and continue.
        print(f"[cline-router] audit write failed: {e}")


# ===========================================================================
# Classifier
# ===========================================================================

def _last_user_text(messages: list[dict]) -> str:
    for m in reversed(messages or []):
        if m.get("role") == "user":
            c = m.get("content")
            if isinstance(c, str):
                return c
            if isinstance(c, list):
                # Anthropic content blocks
                texts = [b.get("text", "") for b in c if isinstance(b, dict) and b.get("type") == "text"]
                return "\n".join(texts)
    return ""


def _last_tool_name(messages: list[dict]) -> Optional[str]:
    """Find name of the tool_use block in the most recent assistant message."""
    for m in reversed(messages or []):
        if m.get("role") == "assistant":
            c = m.get("content")
            if isinstance(c, list):
                for b in reversed(c):
                    if isinstance(b, dict) and b.get("type") == "tool_use":
                        return b.get("name")
    return None


def _last_tool_input_text(messages: list[dict], tool_name: str) -> str:
    """Return concatenated string fields from the most recent tool_use input
    that matches tool_name. Used by the SSH/execute_command hard-escalation
    check to peek at the actual command string.
    """
    for m in reversed(messages or []):
        if m.get("role") == "assistant":
            c = m.get("content")
            if isinstance(c, list):
                for b in reversed(c):
                    if (isinstance(b, dict) and b.get("type") == "tool_use"
                            and b.get("name") == tool_name):
                        inp = b.get("input", {}) or {}
                        if isinstance(inp, dict):
                            return " ".join(str(v) for v in inp.values()
                                            if isinstance(v, (str, int, float)))
                        if isinstance(inp, str):
                            return inp
                        return ""
    return ""


def _has_thinking_blocks(messages: list[dict]) -> bool:
    for m in messages or []:
        c = m.get("content")
        if isinstance(c, list):
            for b in c:
                if isinstance(b, dict) and b.get("type") == "thinking":
                    return True
    return False


def _has_unknown_content_blocks(messages: list[dict]) -> bool:
    """Detect content block types Ollama can't translate."""
    KNOWN = {"text", "image", "tool_use", "tool_result"}
    for m in messages or []:
        c = m.get("content")
        if isinstance(c, list):
            for b in c:
                if isinstance(b, dict) and b.get("type") not in KNOWN:
                    return True
    return False


def _total_token_estimate(req: dict) -> int:
    """Rough token estimate from char count / 4."""
    blob = json.dumps(req, default=str)
    return len(blob) // 4


def classify_pure_heuristic(req: dict) -> tuple[str, float, str]:
    """Tier 1 classifier. Returns (label, confidence, reason).
    Label is one of: routine | hard | ambiguous.
    """
    system = req.get("system", "") or ""
    if isinstance(system, list):
        system = "\n".join(b.get("text", "") for b in system if isinstance(b, dict))
    msgs = req.get("messages", []) or []
    last_user = _last_user_text(msgs)
    last_tool = _last_tool_name(msgs)
    combined = (system + "\n" + last_user).lower()

    # ----- Force-fallback signals -----
    if _has_thinking_blocks(msgs):
        return ("hard", 1.0, "thinking_blocks_present")
    if _has_unknown_content_blocks(msgs):
        return ("hard", 1.0, "unknown_content_blocks")

    # ----- Hard-floor regex (.clinerules/40 v2) -----
    for pat, label in HARD_FLOOR_PATTERNS:
        if pat.search(combined):
            return ("hard", 1.0, f"hard_floor:{label}")

    # ----- Tool-name based routing (REVISION 1 §2) -----
    if last_tool:
        # Hard-tool blacklist beats routine whitelist
        if last_tool in HARD_TOOL_NAMES:
            return ("hard", 0.95, f"hard_tool:{last_tool}")

        # ssh / execute_command — peek at the command string; deploy/sudo escalates to HARD
        if last_tool in ("mcp::ssh_command", "execute_command"):
            ssh_cmd = _last_tool_input_text(msgs, last_tool)
            if ssh_cmd and SSH_HARD_REGEX.search(ssh_cmd):
                return ("hard", 0.95, f"ssh_hard_token:{last_tool}")
            # Otherwise read-mostly — routine
            return ("routine", TIER1_ROUTINE_CONF, f"routine_tool:{last_tool}")

        if last_tool in ROUTINE_TOOL_NAMES:
            return ("routine", TIER1_ROUTINE_CONF, f"routine_tool:{last_tool}")

    # ----- Ambiguous → tier 2 -----
    return ("ambiguous", 0.5, "needs_tier_2")


async def classify_tiny_model(req: dict) -> tuple[str, float, str]:
    """Tier 2 classifier — call llama3.2:1b via LiteLLM Ollama route.
    Returns (label, confidence, reason).
    """
    if litellm is None:
        return ("hard", 0.6, "tier2:litellm_unavailable")
    system = req.get("system", "") or ""
    if isinstance(system, list):
        system = "\n".join(b.get("text", "") for b in system if isinstance(b, dict))
    last_user = _last_user_text(req.get("messages", []) or [])
    last_tool = _last_tool_name(req.get("messages", []) or []) or "none"
    summary = (system[:400] + "\n---\nlast_user: " + last_user[:300] +
               "\n---\nlast_tool: " + last_tool)
    prompt = (
        "Classify this developer-tool turn as ROUTINE or HARD.\n\n"
        "ROUTINE = simple read/edit/query/status. One-shot tool call. No reasoning chain.\n"
        "HARD    = multi-step reasoning, regulator/money/student-facing, large code patch,\n"
        "          ambiguous request, plan composition, voice/tone-sensitive output.\n\n"
        f"Turn: {summary[:1200]}\n\n"
        "Answer with one word (ROUTINE or HARD) followed by a confidence 0-1.\n"
        "Example: ROUTINE 0.9\nExample: HARD 0.75"
    )
    try:
        resp = await litellm.acompletion(
            model="ollama-classifier",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=10, temperature=0,
        )
        text = (resp.choices[0].message.content or "").strip()
        m = re.match(r"^(routine|hard)\s+([0-9.]+)", text, re.I)
        if not m:
            return ("hard", 0.6, f"tier2:unparseable:{text[:40]}")
        label = m.group(1).lower()
        conf = float(m.group(2))
        return (label, conf, f"tier2:llama3.2-1b")
    except Exception as e:
        return ("hard", 0.6, f"tier2:err:{type(e).__name__}")


async def classify(req: dict) -> tuple[str, float, str, int]:
    """Returns (label, confidence, reason, tier_used)."""
    if FORCE_ANTHROPIC:
        return ("hard", 1.0, "force_anthropic_env", 0)

    label, conf, reason = classify_pure_heuristic(req)
    if label != "ambiguous":
        return (label, conf, reason, 1)

    label2, conf2, reason2 = await classify_tiny_model(req)
    if label2 == "routine" and conf2 >= TIER2_ROUTINE_CONF:
        return ("routine", conf2, reason2, 2)
    return ("hard", max(conf2, 0.6), f"tier2_default:{reason2}", 2)


# ===========================================================================
# R1-R9 fail-safe rules — run AFTER Ollama response, return None on pass
# or fail_reason str on detection.
# ===========================================================================

def r2_shape_invalid(resp: dict) -> Optional[str]:
    """Anthropic shape: role=assistant, content=list of blocks."""
    try:
        if resp.get("role") != "assistant":
            return "r2:shape:role_not_assistant"
        content = resp.get("content")
        if not isinstance(content, list):
            return "r2:shape:content_not_list"
        for b in content:
            t = b.get("type")
            if t not in ("text", "tool_use", "image"):
                return f"r2:shape:unknown_block:{t}"
            if t == "tool_use":
                if not b.get("name") or "input" not in b:
                    return "r2:shape:malformed_tool_use"
        return None
    except Exception as e:
        return f"r2:shape:exc:{type(e).__name__}"


def r3_empty_or_garbage(resp: dict) -> Optional[str]:
    content = resp.get("content", []) or []
    texts = [b.get("text", "") for b in content if b.get("type") == "text"]
    tool_count = sum(1 for b in content if b.get("type") == "tool_use")
    full_text = "".join(texts).strip()
    if len(full_text) + tool_count * 50 < 30:
        return "r3:empty_or_undersized"
    if not full_text and tool_count == 0:
        return "r3:no_content"
    # repeated char detection
    if len(full_text) > 50 and len(set(full_text)) < 5:
        return "r3:repeated_chars"
    return None


REFUSAL_RE = re.compile(
    r"\b(I cannot|I can't help with|As an AI(?: language model)?|"
    r"I'm sorry,? but I (cannot|can't)|I'm unable to|"
    r"I do not have the ability)\b", re.I)


def r4_refusal_on_routine(resp: dict, request: dict) -> Optional[str]:
    text = " ".join(b.get("text", "") for b in resp.get("content", []) if b.get("type") == "text")
    if REFUSAL_RE.search(text):
        sys = request.get("system", "") or ""
        if isinstance(sys, list):
            sys = " ".join(b.get("text", "") for b in sys if isinstance(b, dict))
        if "refuse" not in sys.lower() and "decline" not in sys.lower():
            return "r4:refusal_on_routine"
    return None


def r5_tool_schema(resp: dict, request: dict) -> Optional[str]:
    declared = {t.get("name") for t in (request.get("tools") or []) if isinstance(t, dict)}
    for b in resp.get("content", []) or []:
        if b.get("type") == "tool_use":
            if declared and b.get("name") not in declared:
                return f"r5:tool_unknown:{b.get('name')}"
            if not isinstance(b.get("input"), dict):
                return "r5:tool_input_not_dict"
    return None


def r6_truncation(resp: dict, request: dict) -> Optional[str]:
    if resp.get("stop_reason") != "max_tokens":
        return None
    content = resp.get("content", []) or []
    last_text = ""
    for b in reversed(content):
        if b.get("type") == "text":
            last_text = b.get("text", "")
            break
    if last_text.endswith(("...", ".", "!", "?", "}", "]", ")")):
        return None
    if request.get("max_tokens", 4096) > 2048:
        return "r6:truncated_with_budget"
    return None


def r7_ngram_loop(resp: dict) -> Optional[str]:
    text = " ".join(b.get("text", "") for b in resp.get("content", []) or [] if b.get("type") == "text")
    if len(text) < 200:
        return None
    words = text.split()
    if len(words) < 25:
        return None
    grams = {}
    for i in range(len(words) - 4):
        g = " ".join(words[i:i+5])
        grams[g] = grams.get(g, 0) + 1
        if grams[g] > 4 and len(text) < 500 * len(words) // 25:
            return f"r7:ngram_loop:{g[:30]}"
    return None


def r9_latency(latency_ms: int, label: str) -> Optional[str]:
    if label == "routine" and latency_ms > OLLAMA_SLOW_FLOOR_SEC * 1000:
        return f"r9:ollama_slow:{latency_ms}ms"
    return None


def run_fail_safe(resp: dict, request: dict, latency_ms: int, label: str) -> Optional[str]:
    """Run R2-R9 in order. R1 (hard-floor) fired pre-call. Return first fail
    reason, or None if all pass."""
    for check in (
        lambda: r2_shape_invalid(resp),
        lambda: r3_empty_or_garbage(resp),
        lambda: r4_refusal_on_routine(resp, request),
        lambda: r5_tool_schema(resp, request),
        lambda: r6_truncation(resp, request),
        lambda: r7_ngram_loop(resp),
        lambda: r9_latency(latency_ms, label),
    ):
        reason = check()
        if reason:
            return reason
    return None


# ===========================================================================
# Cost estimation
# ===========================================================================

def estimate_cost_usd(model: str, in_tok: int, out_tok: int) -> float:
    price = COST_USD_PER_M.get(model)
    if not price:
        return 0.0
    return (in_tok / 1_000_000.0) * price["in"] + (out_tok / 1_000_000.0) * price["out"]


# ===========================================================================
# CustomLogger hook — registered in config.yaml
# ===========================================================================

class EmsuRouterHook(CustomLogger):
    """The hook LiteLLM calls on every request + response."""

    def __init__(self):
        super().__init__()
        self.request_state = {}  # request_hash → tier-1 decision

    # ---------- Pre-call ----------

    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        """Called before any model call. We can mutate `data` to rewrite model.
        Per LiteLLM docs/proxy/call_hooks for 1.83.14.
        """
        if call_type not in ("completion", "acompletion"):
            return data

        # Don't classify our own tier-2 calls (recursion guard)
        if data.get("model") == "ollama-classifier":
            return data

        t0 = time.time()
        try:
            label, conf, reason, tier = await classify(data)
        except Exception as e:
            print(f"[cline-router] classifier crash: {e}\n{traceback.format_exc()}")
            label, conf, reason, tier = "hard", 1.0, f"classifier_crash:{type(e).__name__}", 0

        classify_ms = int((time.time() - t0) * 1000)
        req_hash = hashlib.sha256(json.dumps(data, sort_keys=True, default=str).encode()).hexdigest()[:16]
        self.request_state[req_hash] = {
            "label": label, "conf": conf, "reason": reason, "tier": tier,
            "classify_ms": classify_ms, "original_model": data.get("model"),
            "t_start": time.time(),
        }
        data["_emsu_request_hash"] = req_hash

        # Routing decision
        if ROLLOUT_MODE in ("shadow", "disabled"):
            # Emergency kill switch: log only. Don't rewrite model.
            # Cline still hits the original Anthropic model. Per REVISION 1, this
            # is no longer the default — only used for reversal.
            return data

        if label == "routine":
            data["model"] = DEFAULT_OLLAMA_MODEL
            # Keep an audit field so post-call hook knows
            self.request_state[req_hash]["routed_to"] = DEFAULT_OLLAMA_MODEL
        else:
            self.request_state[req_hash]["routed_to"] = data.get("model")

        return data

    # ---------- Post-call success ----------

    async def async_post_call_success_hook(self, data, user_api_key_dict, response):
        req_hash = data.get("_emsu_request_hash")
        state = self.request_state.pop(req_hash, None)
        if not state:
            return response

        total_ms = int((time.time() - state["t_start"]) * 1000)
        ollama_called = state.get("routed_to", "").startswith("ollama-")
        fallback_called = False
        fail_reason = None
        fallback_resp = response

        # Normalize response into dict (LiteLLM ModelResponse → dict)
        try:
            resp_dict = response.model_dump() if hasattr(response, "model_dump") else dict(response)
        except Exception:
            resp_dict = {}

        # Anthropic-shape response from LiteLLM has top-level 'choices' (OpenAI shape).
        # We need to detect failure modes on the OPENAI-SHAPE blob since LiteLLM
        # translates outbound. Build a synthetic Anthropic-shape for R2-R7 checks.
        anth_shape = _openai_to_anthropic_shape(resp_dict)

        if ROLLOUT_MODE not in ("shadow", "disabled") and ollama_called:
            fail_reason = run_fail_safe(anth_shape, data, total_ms, state["label"])
            if fail_reason and litellm is not None:
                # SILENT FALLBACK: call Anthropic with the original request
                fallback_called = True
                try:
                    fb_data = dict(data)
                    fb_data["model"] = state.get("original_model") or "claude-sonnet-4-6"
                    fb_data.pop("_emsu_request_hash", None)
                    fallback_resp = await litellm.acompletion(**fb_data)
                except Exception as e:
                    print(f"[cline-router] fallback call failed: {e}")

        # Audit log
        usage = resp_dict.get("usage", {}) or {}
        in_tok = usage.get("prompt_tokens", 0) or 0
        out_tok = usage.get("completion_tokens", 0) or 0
        cost_paid = 0.0
        cost_saved = 0.0
        if ollama_called and not fallback_called:
            # We would have paid Sonnet; we paid 0
            cost_saved = estimate_cost_usd("claude-sonnet-4-6", in_tok, out_tok)
        elif fallback_called:
            cost_paid = estimate_cost_usd(state.get("original_model") or "claude-sonnet-4-6", in_tok, out_tok)
        else:
            cost_paid = estimate_cost_usd(state.get("original_model") or "claude-sonnet-4-6", in_tok, out_tok)

        _audit_write({
            "ts": int(time.time()),
            "request_hash": req_hash,
            "classifier_label": state["label"],
            "classifier_confidence": state["conf"],
            "classifier_reason": state["reason"],
            "classifier_tier": state["tier"],
            "ollama_called": int(ollama_called and not fallback_called),
            "ollama_model": state.get("routed_to") if ollama_called else None,
            "ollama_latency_ms": total_ms,
            "ollama_input_tokens": in_tok if ollama_called else 0,
            "ollama_output_tokens": out_tok if ollama_called else 0,
            "fail_reason": fail_reason,
            "fallback_called": int(fallback_called),
            "fallback_model": state.get("original_model") if fallback_called else None,
            "fallback_latency_ms": 0,   # not tracked separately yet
            "total_latency_ms": total_ms,
            "estimated_cost_saved_usd": round(cost_saved, 6),
            "estimated_cost_paid_usd": round(cost_paid, 6),
            "request_size_bytes": len(json.dumps(data, default=str)),
            "response_size_bytes": len(json.dumps(resp_dict, default=str)),
            "rollout_mode": ROLLOUT_MODE,
        })

        return fallback_resp if fallback_called else response

    # ---------- Streaming variant (Phase 5B+) ----------

    async def async_post_call_streaming_iterator_hook(self, user_api_key_dict, response, request_data):
        """For SSE streaming responses, we can't replay easily. Pass through
        and log on stream end. R1-R9 will run on the assembled output
        in a future iteration.
        """
        async for chunk in response:
            yield chunk
        # TODO Phase 5B: assemble streamed chunks into full response and run R2-R9.

    # ---------- Failure hook ----------

    async def async_post_call_failure_hook(self, original_exception, user_api_key_dict, request_data):
        """Called when the model call itself raises. Log + let it propagate."""
        req_hash = request_data.get("_emsu_request_hash")
        state = self.request_state.pop(req_hash, None)
        if not state:
            return
        try:
            _audit_write({
                "ts": int(time.time()),
                "request_hash": req_hash,
                "classifier_label": state["label"],
                "classifier_confidence": state["conf"],
                "classifier_reason": state["reason"],
                "classifier_tier": state["tier"],
                "ollama_called": 1 if state.get("routed_to", "").startswith("ollama-") else 0,
                "ollama_model": state.get("routed_to"),
                "ollama_latency_ms": int((time.time() - state["t_start"]) * 1000),
                "ollama_input_tokens": 0,
                "ollama_output_tokens": 0,
                "fail_reason": f"call_exception:{type(original_exception).__name__}",
                "fallback_called": 0,
                "fallback_model": None,
                "fallback_latency_ms": 0,
                "total_latency_ms": int((time.time() - state["t_start"]) * 1000),
                "estimated_cost_saved_usd": 0,
                "estimated_cost_paid_usd": 0,
                "request_size_bytes": len(json.dumps(request_data, default=str)),
                "response_size_bytes": 0,
                "rollout_mode": ROLLOUT_MODE,
            })
        except Exception:
            pass


# ===========================================================================
# OpenAI-shape → Anthropic-shape converter (for R2-R7 checks)
# ===========================================================================

def _openai_to_anthropic_shape(resp: dict) -> dict:
    """LiteLLM returns OpenAI shape (choices[0].message). Convert to
    Anthropic-shape ({role, content[blocks], stop_reason, usage}) for R-rule
    inspection. Lossless for our purposes."""
    try:
        choice = (resp.get("choices") or [{}])[0]
        msg = choice.get("message", {}) or {}
        blocks = []
        if msg.get("content"):
            blocks.append({"type": "text", "text": msg["content"]})
        for tc in msg.get("tool_calls", []) or []:
            fn = tc.get("function", {}) or {}
            try:
                args = json.loads(fn.get("arguments", "{}"))
            except Exception:
                args = {}
            blocks.append({
                "type": "tool_use",
                "id": tc.get("id"),
                "name": fn.get("name"),
                "input": args,
            })
        stop_map = {"stop": "end_turn", "length": "max_tokens",
                    "tool_calls": "tool_use", "function_call": "tool_use"}
        return {
            "role": "assistant",
            "content": blocks,
            "stop_reason": stop_map.get(choice.get("finish_reason"), "end_turn"),
            "usage": resp.get("usage", {}),
        }
    except Exception:
        return {"role": "assistant", "content": [], "stop_reason": "end_turn"}


# Module-level singleton — what config.yaml `callbacks` references.
emsu_router_instance = EmsuRouterHook()
