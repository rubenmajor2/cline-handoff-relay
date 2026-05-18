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

# 2026-05-11 cline-rag-2026-05-11: RAG augmentation client.
# Calls https://emsuniversity.com/emtskills/api/rag_context.php (WOPR) and
# prepends top-5 EMSU corpus hits to the system prompt before the LoRA call.
# Non-fatal: if WOPR is unreachable or returns nothing, augment_system_prompt
# returns the original system text unchanged.
try:
    from rag_client import augment_system_prompt  # type: ignore
except ImportError:
    def augment_system_prompt(system_text: str, last_user_text: str):  # type: ignore
        return system_text, {"skipped": "import_failed"}


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

# Default Ollama route model. 2026-05-11 16:38 PT: flipped to 7B EMSU-LoRA
# per Ruben directive ("flip it and test it as it works test it live") after
# the +121% EMSU-flavor lift vs base Qwen on the held-out backtest (N=10,
# 8/10 wins, 31 vs 14 EMSU terms). R1-R9 fail-safe still catches any drift
# and silently falls back to Sonnet. Reversal: set
# CLINE_ROUTER_OLLAMA_MODEL=ollama-qwen-14b or CLINE_ROUTER_FORCE_ANTHROPIC=1.
DEFAULT_OLLAMA_MODEL = os.environ.get("CLINE_ROUTER_OLLAMA_MODEL", "emsu-qwen2.5-coder-7b-lora")

# 2026-05-14: pre-call tripwire injection for subagent + call_ollama drift.
# When enabled, prepends a system instruction on `hard` (Anthropic-bound)
# turns reminding the model to use call_ollama and use_subagents per
# .clinerules/40 v3 + .clinerules/74 addendum. Default OFF — flip with
# CLINE_ROUTER_TRIPWIRE_INJECT=1 once validated on a non-critical turn.
TRIPWIRE_INJECT = os.environ.get("CLINE_ROUTER_TRIPWIRE_INJECT", "0") in ("1", "true", "yes")

# 2026-05-18: Anthropic prompt-cache diagnostics. When enabled, every
# Anthropic-bound (`hard`) turn carries the beta header that asks Anthropic
# to compute cache-miss reasons + diff this request against the prior one.
# Anthropic surfaces the results in the Console "Cache Diagnostics" panel
# (data appears within ~1h) and ALSO returns a `diagnostics` field on each
# response which we log to ~/.cline-router/audit.sqlite (table cache_diag)
# for offline analysis.
#
# To work, this needs TWO things:
#   1. anthropic-beta header on the request  (one-liner via extra_headers)
#   2. diagnostics: {previous_message_id: <id>} body field, where <id> is
#      the response.id from the prior Anthropic call in this Cline window.
# Without (2), Anthropic has nothing to diff against and the panel stays
# empty even though the header is present.
#
# Key for "this Cline window": (n_messages, first_user[:200], original_model)
# tracked in a process-local dict CACHE_DIAG_PREV_ID. Survives until the
# router restarts; one launchd kickstart resets all windows' chains which
# is fine — the first turn after restart writes a NEW prev_id and the
# diff resumes on turn 2.
#
# Verified header value 2026-05-18: `cache-diagnosis-2026-04-07` (note
# SINGULAR `diagnosis`). The plural variant is silently ignored by
# Anthropic — Ruben's other LLM had this wrong. See .clinerules/45.
#
# Reversal: set CLINE_ROUTER_CACHE_DIAG=0 to disable. Or revert the file
# from the backup .bak-2026-05-18-pre-cache-diag.
CACHE_DIAG_ENABLED = os.environ.get("CLINE_ROUTER_CACHE_DIAG", "1") not in ("0", "false", "no")
CACHE_DIAG_BETA = "cache-diagnosis-2026-04-07"
CACHE_DIAG_PREV_ID: dict[str, dict] = {}   # window_key -> {"prev_id": str, "ts": epoch}
# Window-keys older than this are evicted (prevents unbounded growth from
# transient one-off Cline windows). 24h is generous for normal usage.
CACHE_DIAG_TTL_SEC = 24 * 3600


# 2026-05-14: tripwire system message. Short, high-priority, mirrors
# .clinerules/40 v3 + .clinerules/74 addendum language.
TRIPWIRE_SYSTEM_MSG = (
    "ROUTER TRIPWIRE (enforced 2026-05-14, see .clinerules/40 v3 + 74 addendum):\n"
    "1. EMSU policy / routing / classification question -> your FIRST tool call "
    "MUST be `call_ollama` with model='emsu-qwen2.5-coder:7b-lora'. The 7B-LoRA "
    "is fine-tuned on EMSU corpus and free. Skip ONLY if: pure framework code "
    "question, hard-floor surface, single-file bounded read, deterministic "
    "lookup, or already-dispatched this turn.\n"
    "2. About to fire a 2nd READ tool call (read_file, list_files, search_files, "
    "MCP fetch, ssh-grep) on this turn before any state-mutating call? "
    "STOP. Fan out as `use_subagents` with parallel Haiku prompts instead. "
    "Skip ONLY if: 2nd read's args literally depend on 1st read's result, "
    "or already inside a subagent.\n"
    "These are TRIPWIRES (measurable events), not defaults."
)

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

# -----------------------------------------------------------------------------
# Intent-based classifier (2026-05-10 fix — closes first-turn $7.54 leak).
#
# Root cause: classify_pure_heuristic only routes "routine" when it can see a
# prior assistant tool_use block. On the FIRST turn of a new task Cline hasn't
# called any tool yet — the user is asking, Cline will decide AFTER the LLM
# replies. So last_tool=None → ambiguous → tier-2 → tier-2 defaults "hard"
# → forwarded to Opus 4.7 at full context = ~$5-8 per "read me /etc/hosts"
# request.
#
# Fix: look at the user's actual ask. If they're explicitly asking for a
# routine read/list/show/check/grep with a short request, classify routine
# BEFORE the model picks a tool. This is the classic "intent-based" routing
# the spec calls for.
#
# Bounds:
#   - User text <= 800 chars (long asks = likely multi-step reasoning)
#   - No question marks chained with conjunctions ("AND THEN", "OR ALSO")
#   - No "compose", "draft", "write" verbs (those are HARD)
#   - Hard-floor regex still beats this (already runs upstream)
# -----------------------------------------------------------------------------
INTENT_ROUTINE_RE = re.compile(
    r"(?:^|\b)("
    # read/show/display
    r"read\s+(?:me\s+|out\s+|the\s+|some\s+|this\s+|that\s+)?(?:contents?\s+of\s+)?|"
    r"show\s+(?:me\s+|us\s+|the\s+|some\s+|this\s+|that\s+|what['s]*\s+(?:in|is))|"
    r"display\s+(?:the\s+|contents?\s+of\s+|me\s+)|"
    r"print\s+(?:the\s+|contents?\s+of\s+|out\s+)|"
    r"cat\s+/|head\s+(?:-n\s+\d+\s+|of\s+)?/|tail\s+(?:-n\s+\d+\s+|of\s+)?/|"
    # list/enumerate
    r"list\s+(?:the\s+|all\s+|every\s+|files?\s+in\s+|directories\s+in\s+|contents?\s+of\s+)|"
    r"ls\s+(?:-[lah]+\s+)?[/~]|"
    r"enumerate\s+(?:the\s+|all\s+)|"
    # check/lookup/find/get
    r"check\s+(?:the\s+|if\s+|whether\s+|on\s+|for\s+)|"
    r"look\s*(?:up|at)\s+(?:the\s+|this\s+|that\s+|student\s+|ticket\s+|order\s+|user\s+)|"
    r"find\s+(?:me\s+|the\s+|all\s+|files?\s+|every\s+)|"
    r"get\s+(?:me\s+|the\s+|current\s+|recent\s+|latest\s+)|"
    r"fetch\s+(?:the\s+|me\s+)|"
    # query/search
    r"grep\s+(?:-[rni]+\s+)?[\"']?|"
    r"search\s+(?:for\s+|the\s+|files?\s+)|"
    r"query\s+(?:the\s+|for\s+)|"
    # status/info
    r"(?:what(?:'s|\s+is)\s+(?:the\s+|in\s+|inside\s+|contents?\s+of\s+))|"
    r"(?:tell\s+me\s+(?:what['s]*\s+in\s+|the\s+contents?\s+of\s+))|"
    r"status\s+of\s+|"
    r"how\s+(?:big|large|many)\s+(?:is\s+|are\s+)|"
    # describe (sql/schema)
    r"describe\s+(?:the\s+|table\s+)|"
    r"show\s+(?:tables|columns|schema|create)|"
    r"select\s+(?:\*|count|id|name)\s+from\b"
    r")",
    re.I,
)

# Hard-veto verbs — even if INTENT_ROUTINE_RE matched, these escalate back to HARD.
INTENT_HARD_VETO_RE = re.compile(
    r"\b("
    r"compose|draft|write\s+(?:the\s+|a\s+|me\s+|an\s+)|reply\s+to|"
    r"refactor|redesign|rewrite|migrate\s+|deploy\s+|"
    r"explain\s+why|reason\s+about|think\s+through|plan\s+|architect\s+|design\s+"
    r")\b",
    re.I,
)


def classify_intent_from_user_text(last_user: str) -> Optional[tuple[str, float, str]]:
    """Return (label, conf, reason) if the user's text looks like an explicit
    routine read/list/check/query, otherwise None. Runs AFTER hard-floor regex
    so safety-critical surfaces are still preserved.
    """
    if not last_user:
        return None
    text = last_user.strip()
    if len(text) > 800:
        return None  # long asks tend to be multi-step
    if INTENT_HARD_VETO_RE.search(text):
        return None
    m = INTENT_ROUTINE_RE.search(text)
    if not m:
        return None
    return ("routine", TIER1_ROUTINE_CONF, f"intent:{m.group(1).strip().lower()[:30]}")



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

        -- 2026-05-18 cache-diagnosis: one row per Anthropic-bound response,
        -- captures Anthropic's diagnostics payload + the message_id we tracked
        -- for the next-turn diff. NULL diagnostics is normal (first turn of a
        -- window, or no divergence). Operator queries this offline to find
        -- which specific cache prefix change caused each miss.
        CREATE TABLE IF NOT EXISTS cache_diag (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ts INTEGER NOT NULL,
          request_hash TEXT NOT NULL,
          window_key TEXT NOT NULL,
          model TEXT,
          message_id TEXT,
          previous_message_id_sent TEXT,
          diagnostics_json TEXT,
          cache_miss_reason TEXT,
          usage_input_tokens INTEGER,
          usage_cache_read INTEGER,
          usage_cache_creation INTEGER,
          usage_output_tokens INTEGER
        );
        CREATE INDEX IF NOT EXISTS idx_cache_diag_ts ON cache_diag(ts);
        CREATE INDEX IF NOT EXISTS idx_cache_diag_window ON cache_diag(window_key);
        CREATE INDEX IF NOT EXISTS idx_cache_diag_miss ON cache_diag(cache_miss_reason);
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


def _safe_size(obj) -> int:
    """json.dumps an arbitrary object for size measurement, returning 0 on
    failure (e.g. circular refs in LiteLLM internal objects). The point is
    audit logging — never let it raise."""
    try:
        return len(json.dumps(obj, default=str))
    except Exception:
        try:
            return len(str(obj))
        except Exception:
            return 0


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
# Cache diagnostics helpers (2026-05-18)
# ===========================================================================

def _cache_diag_window_key(data: dict) -> str:
    """Stable identifier for "this Cline window" used to chain
    previous_message_id across turns.

    Cline doesn't expose a session-id; we synthesize one from the (model,
    n_messages>=2, first_user_chars[:200], original_model). Two simultaneous
    Cline windows on the same model whose first user-turn texts diverge in
    the first 200 chars will be tracked separately, which is the right
    behavior. Identical first-200-char first turns will share a key — fine,
    they're in the same conversation arc.

    Falls back to a per-process-uniq tag on hash failure so we still log.
    """
    try:
        msgs = data.get("messages") or []
        # Use only the FIRST user message in the conversation as the anchor.
        first_user = ""
        for m in msgs:
            if m.get("role") == "user":
                c = m.get("content")
                if isinstance(c, str):
                    first_user = c
                elif isinstance(c, list):
                    first_user = "\n".join(
                        b.get("text", "") for b in c
                        if isinstance(b, dict) and b.get("type") == "text"
                    )
                break
        seed = {
            "model": data.get("model"),
            "first_user_200": first_user[:200],
        }
        return hashlib.sha256(
            json.dumps(seed, sort_keys=True, default=str).encode()
        ).hexdigest()[:16]
    except Exception:
        return f"unkeyed:{os.getpid()}"


def _cache_diag_evict_stale():
    """Drop window-key entries older than CACHE_DIAG_TTL_SEC. Called from the
    post-call hook so it amortizes naturally."""
    try:
        now = time.time()
        stale = [k for k, v in CACHE_DIAG_PREV_ID.items()
                 if now - v.get("ts", 0) > CACHE_DIAG_TTL_SEC]
        for k in stale:
            CACHE_DIAG_PREV_ID.pop(k, None)
    except Exception:
        pass


def _cache_diag_write(row: dict):
    cols = ",".join(row.keys())
    qs = ",".join("?" for _ in row)
    try:
        with sqlite3.connect(AUDIT_DB_PATH) as db:
            db.execute(f"INSERT INTO cache_diag ({cols}) VALUES ({qs})", tuple(row.values()))
            db.commit()
    except Exception as e:
        print(f"[cline-router] cache_diag write failed: {e}")


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
    # 2026-05-11: hard-floor regex must NOT scan the full message history.
    # In a long Cline conversation, words like "refund" or "payment" appear
    # somewhere in history naturally → every turn would lock to hard_floor.
    # Scope hard-floor scan to system prompt + last user ask only. Truncate
    # system to first 6KB (Cline's static system prompt content) to avoid
    # accidental matches in retrieved RAG context appended to system later.
    hard_floor_scan_text = (system[:6000] + "\n" + last_user).lower()

    # ----- Force-fallback signals -----
    # 2026-05-11: thinking_blocks no longer auto-HARDs the turn. The pre-call
    # hook strips thinking blocks before forwarding to Ollama (Anthropic-only
    # feature). Classifier proceeds on the underlying message text. This lets
    # users keep Adaptive Thinking=Medium for Anthropic-bound (hard) turns
    # AND get free 7B routing for routine turns.
    if _has_unknown_content_blocks(msgs):
        return ("hard", 1.0, "unknown_content_blocks")

    # ----- Hard-floor regex (.clinerules/40 v2) -----
    for pat, label in HARD_FLOOR_PATTERNS:
        if pat.search(hard_floor_scan_text):
            return ("hard", 1.0, f"hard_floor:{label}")

    # ----- Intent-based routing (2026-05-10 fix) -----
    # First-turn requests have no prior assistant tool_use yet (last_tool=None).
    # Look at the user's explicit ask to classify routine reads/lists/checks
    # before falling into the "ambiguous → tier-2 defaults hard" trap that was
    # silently costing $5-8 per "read me /etc/hosts"-shape request on Opus.
    intent_decision = classify_intent_from_user_text(last_user)
    if intent_decision is not None:
        return intent_decision

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

    # 2026-05-11: tier-2 in-process LiteLLM call has been throwing
    # BadRequestError for weeks (see audit rows 13-17, 22). When tier-2
    # crashes, the original logic defaulted ambiguous→HARD → every Cline
    # turn went to Opus at $4 each. Instead: if the user's ask is short
    # (<800 chars) and didn't hit any hard-floor, treat as routine.
    # R3/R4 post-call fallback will catch bad 7B responses. Net effect:
    # short user asks go to 7B for free, big complex asks (long text →
    # length>800) go to Anthropic. Easy reversal: restore the tier-2
    # call below by reverting this block.
    last_user = _last_user_text(req.get("messages", []) or [])
    if last_user and len(last_user.strip()) < 800:
        return ("routine", 0.7, "ambiguous_short_user→route_routine", 1)

    # Big asks → still try tier-2 (in case it ever works), else default hard.
    try:
        label2, conf2, reason2 = await classify_tiny_model(req)
    except Exception as e:
        return ("hard", 0.6, f"tier2:exc:{type(e).__name__}", 2)
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
    # Tuned 2026-05-11: threshold dropped from 30 → 15 chars so short factual
    # answers like "OK" / "Yes" / "23" don't trigger fallback. tool_count*50
    # bonus retained — any tool_use call is intrinsically valid output.
    content = resp.get("content", []) or []
    texts = [b.get("text", "") for b in content if b.get("type") == "text"]
    tool_count = sum(1 for b in content if b.get("type") == "tool_use")
    full_text = "".join(texts).strip()
    if not full_text and tool_count == 0:
        return "r3:no_content"
    if len(full_text) + tool_count * 50 < 15:
        return "r3:empty_or_undersized"
    # repeated char detection
    if len(full_text) > 50 and len(set(full_text)) < 5:
        return "r3:repeated_chars"
    return None


REFUSAL_RE = re.compile(
    r"\b(I cannot|I can't help with|As an AI(?: language model)?|"
    r"I'm sorry,? but I (cannot|can't)|I'm unable to|"
    r"I do not have the ability)\b", re.I)


def r4_refusal_on_routine(resp: dict, request: dict) -> Optional[str]:
    # Tuned 2026-05-11: require BOTH refusal regex AND short total length
    # (<200 chars). A long response that begins "I cannot do X but here's Y"
    # is helpful — only treat as refusal when the response is short enough
    # that there's no helpful body after the refusal phrase.
    text = " ".join(b.get("text", "") for b in resp.get("content", []) if b.get("type") == "text")
    if REFUSAL_RE.search(text) and len(text.strip()) < 200:
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
    # 2026-05-12 fix: LiteLLM stores the model as "anthropic/claude-sonnet-4-6"
    # but COST_USD_PER_M keys are "claude-sonnet-4-6". Strip the provider prefix
    # so the lookup succeeds and dollars_saved / dollars_paid stop showing $0.00.
    model_key = (model or "").split("/")[-1]
    price = COST_USD_PER_M.get(model_key) or COST_USD_PER_M.get(model or "")
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

        2026-05-10: added "anthropic_messages" to the allow-list. Cline ships
        /v1/messages (Anthropic-native) not /v1/chat/completions, and LiteLLM
        1.83.14 routes /v1/messages through ProxyBaseLLMRequestProcessing
        which fires this hook with call_type="anthropic_messages". Without
        this, every Cline turn skipped classification and went straight to
        Anthropic at full price (0 audit rows since proxy went live).
        """
        if call_type not in ("completion", "acompletion", "anthropic_messages"):
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
        # 2026-05-10: defensive hash. LiteLLM 1.83.x passes objects with
        # circular references (e.g. LiteLLM_Verification_token + internal
        # client refs) into the pre-call hook. json.dumps blows up with
        # "Circular reference detected" → 500 to Cline → hook gate that
        # was the point of this whole patch never gets to run on the
        # request. Hash only the stable subset of fields we actually care
        # about. Falls back to time-based unique if even that fails.
        try:
            hash_seed = {
                "model": data.get("model"),
                "max_tokens": data.get("max_tokens"),
                "n_messages": len(data.get("messages") or []),
                "first_user": _last_user_text(data.get("messages") or [])[:200],
                "t": time.time(),
            }
            req_hash = hashlib.sha256(
                json.dumps(hash_seed, sort_keys=True, default=str).encode()
            ).hexdigest()[:16]
        except Exception:
            req_hash = hashlib.sha256(f"{time.time()}-{id(data)}".encode()).hexdigest()[:16]
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

            # 2026-05-11 (late): strip Anthropic-only fields before forwarding
            # to Ollama. Cline's Adaptive Thinking shipsthinking content blocks
            # + a top-level `thinking` request param. Ollama returns
            # `"emsu-qwen2.5-coder:7b-lora" does not support thinking` 500 on
            # both. We strip them only when routing to Ollama; the original
            # Anthropic-bound (hard) path is unchanged.
            try:
                # Strip top-level `thinking` request param
                if "thinking" in data:
                    data.pop("thinking", None)
                # Strip `thinking` content blocks from every message
                msgs = data.get("messages", []) or []
                for m in msgs:
                    c = m.get("content")
                    if isinstance(c, list):
                        m["content"] = [b for b in c if not (
                            isinstance(b, dict) and b.get("type") == "thinking"
                        )]
            except Exception as e:
                print(f"[cline-router] thinking-strip failed: {type(e).__name__}: {e}")

            # 2026-05-11 cline-rag-2026-05-11: prepend EMSU corpus context to
            # the system prompt for LoRA turns. Hits WOPR /emtskills/api/rag_context.php
            # with the user's last message and gets top-5 most-relevant snippets
            # from emsu_preference_corpus (6,010 rows: ideas + handoffs +
            # clinerules + grievances + tickets + ticket_comments + docs/*.md).
            # Non-fatal: empty context_block means RAG missed or WOPR is down,
            # we still ship the LoRA call.
            try:
                last_user = _last_user_text(data.get("messages") or [])
                system_in = data.get("system", "") or ""
                # Anthropic-style system can be list-of-blocks; normalize to text.
                if isinstance(system_in, list):
                    sys_text = "\n".join(
                        b.get("text", "") for b in system_in
                        if isinstance(b, dict) and b.get("type") == "text"
                    )
                else:
                    sys_text = str(system_in)
                augmented, rag_meta = augment_system_prompt(sys_text, last_user)
                # Sentinel log so smoke tests can verify RAG actually fired
                # without scraping LiteLLM internal state.
                try:
                    with open("/tmp/cline_router_rag_calls.log", "a") as _slog:
                        _slog.write(
                            f"{time.strftime('%Y-%m-%d %H:%M:%S')} "
                            f"req={req_hash} "
                            f"user_first80={last_user[:80].replace(chr(10),' ')!r} "
                            f"meta={json.dumps(rag_meta)} "
                            f"augmented={'yes' if (rag_meta.get('ok') and augmented != sys_text) else 'no'}\n"
                        )
                except Exception:
                    pass
                if rag_meta.get("ok") and augmented != sys_text:
                    # Rewrite system field. If original was a list-of-blocks
                    # keep that shape with a single text block (LiteLLM handles both).
                    if isinstance(system_in, list):
                        data["system"] = [{"type": "text", "text": augmented}]
                    else:
                        data["system"] = augmented
                    self.request_state[req_hash]["rag_meta"] = rag_meta
                else:
                    self.request_state[req_hash]["rag_meta"] = rag_meta
            except Exception as e:
                # Never fail a turn over a RAG hiccup
                print(f"[cline-router] rag augment failed: {type(e).__name__}: {e}")
                self.request_state[req_hash]["rag_meta"] = {"error": str(e)}
        else:
            self.request_state[req_hash]["routed_to"] = data.get("model")

            # 2026-05-18 cache-diagnosis injection. On Anthropic-bound (hard)
            # turns ONLY, attach the beta header + diagnostics body so the
            # Console "Cache Diagnostics" panel populates. Stash a window key
            # in request_state so the post-call hook knows where to save the
            # response.id for next turn's diff anchor.
            if CACHE_DIAG_ENABLED:
                try:
                    window_key = _cache_diag_window_key(data)
                    self.request_state[req_hash]["cache_diag_window"] = window_key

                    # Add the beta header via extra_headers (LiteLLM passes
                    # this dict straight through to Anthropic).
                    existing_headers = data.get("extra_headers") or {}
                    if not isinstance(existing_headers, dict):
                        existing_headers = {}
                    # Anthropic concatenates multiple anthropic-beta values
                    # with commas; preserve any existing value (e.g. prompt-
                    # caching-2024-07-31 added by Cline itself).
                    prev_beta = existing_headers.get("anthropic-beta", "")
                    if CACHE_DIAG_BETA in prev_beta:
                        merged_beta = prev_beta
                    elif prev_beta:
                        merged_beta = prev_beta + "," + CACHE_DIAG_BETA
                    else:
                        merged_beta = CACHE_DIAG_BETA
                    existing_headers["anthropic-beta"] = merged_beta
                    data["extra_headers"] = existing_headers

                    # Look up the previous_message_id for this Cline window.
                    # First turn in a window → no prev_id → send
                    # `diagnostics: {"previous_message_id": null}` per
                    # Anthropic's opt-in spec.
                    prev_entry = CACHE_DIAG_PREV_ID.get(window_key)
                    prev_id = prev_entry.get("prev_id") if prev_entry else None
                    data["diagnostics"] = {"previous_message_id": prev_id}
                    self.request_state[req_hash]["cache_diag_prev_id_sent"] = prev_id

                    # Sentinel log so smoke tests can verify it fires.
                    try:
                        with open("/tmp/cline_router_cache_diag.log", "a") as _dlog:
                            _dlog.write(
                                f"{time.strftime('%Y-%m-%d %H:%M:%S')} "
                                f"req={req_hash} window={window_key} "
                                f"model={data.get('model')} "
                                f"prev_id={prev_id or 'NULL_FIRST_TURN'} "
                                f"beta='{merged_beta}'\n"
                            )
                    except Exception:
                        pass
                except Exception as e:
                    # Cache diagnostics must NEVER fail a real Anthropic call.
                    print(f"[cline-router] cache-diag inject failed: "
                          f"{type(e).__name__}: {e}")

            # 2026-05-14 tripwire: on `hard` turns going to Anthropic,
            # prepend a brief system instruction reminding the model to use
            # call_ollama + use_subagents where appropriate. Env-gated;
            # default OFF. See .clinerules/40 v3 + .clinerules/74 addendum.
            if TRIPWIRE_INJECT:
                try:
                    system_in = data.get("system", "") or ""
                    if isinstance(system_in, list):
                        data["system"] = [{"type": "text", "text": TRIPWIRE_SYSTEM_MSG}] + list(system_in)
                    elif isinstance(system_in, str):
                        data["system"] = TRIPWIRE_SYSTEM_MSG + "\n\n" + system_in
                    self.request_state[req_hash]["tripwire_injected"] = True
                    try:
                        with open("/tmp/cline_router_tripwire.log", "a") as _tlog:
                            _tlog.write(
                                f"{time.strftime('%Y-%m-%d %H:%M:%S')} "
                                f"req={req_hash} model={data.get('model')} "
                                f"label={label} injected=yes\n"
                            )
                    except Exception:
                        pass
                except Exception as e:
                    # Never fail a turn over the tripwire
                    print(f"[cline-router] tripwire inject failed: {type(e).__name__}: {e}")

        return data

    # ---------- Post-call success ----------

    async def async_post_call_success_hook(self, data, user_api_key_dict, response):
        req_hash = data.get("_emsu_request_hash")
        state = self.request_state.pop(req_hash, None)
        if not state:
            return response

        total_ms = int((time.time() - state["t_start"]) * 1000)
        # 2026-05-11: also count emsu-* LoRA targets as "ollama_called" since
        # they route through the same ollama backend. Previously this only
        # matched "ollama-" prefix which broke audit accounting + R1-R9 gating
        # when DEFAULT_OLLAMA_MODEL was flipped to emsu-qwen2.5-coder-7b-lora.
        routed = state.get("routed_to", "") or ""
        ollama_called = routed.startswith("ollama-") or routed.startswith("emsu-")

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
                    # 2026-05-12 fix: strip LiteLLM-internal fields (Deployment
                    # objects, litellm_logging_obj, litellm_call_id, etc.) that
                    # cause "Object of type Deployment is not JSON serializable"
                    # when dict(data) is passed back into acompletion. Only send
                    # the actual API params the model needs.
                    _FB_SAFE = frozenset({
                        "messages", "system", "max_tokens", "temperature",
                        "stream", "tools", "tool_choice",
                    })
                    fb_data = {k: data[k] for k in _FB_SAFE if k in data}
                    # 2026-05-14 fix: state["original_model"] is the alias
                    # Cline sent (e.g. "claude-sonnet-4-6:1m" or sometimes the
                    # local LoRA name when Cline's model picker was set there).
                    # litellm.acompletion() called directly bypasses the proxy
                    # router's model_list, so it needs a real provider/model
                    # string. Without a prefix it errors:
                    #   "LLM Provider NOT provided. You passed model=..."
                    # which is what was spamming the log + causing the bad-7B
                    # response to leak through to Cline unhealed. Map the alias
                    # back to a known-good Anthropic target.
                    _orig = (state.get("original_model") or "").strip()
                    if _orig.startswith(("anthropic/", "openai/", "ollama_chat/", "ollama/", "openrouter/")):
                        fb_model = _orig
                    elif _orig.startswith("claude-"):
                        # strip ":1m" / ":200k" / etc. context-tier suffix
                        _base = _orig.split(":", 1)[0]
                        fb_model = f"anthropic/{_base}"
                    else:
                        # LoRA name or unknown alias → safe Anthropic default
                        fb_model = "anthropic/claude-sonnet-4-6"
                    fb_data["model"] = fb_model
                    fb_data["num_retries"] = 3
                    fallback_resp = await litellm.acompletion(**fb_data)
                except Exception as e:
                    print(f"[cline-router] fallback call failed: {type(e).__name__}: {e}")

        # Audit log
        usage = resp_dict.get("usage", {}) or {}
        # 2026-05-12 fix: LiteLLM normalizes to OpenAI keys but Anthropic-native
        # responses sometimes preserve input_tokens/output_tokens. Accept either
        # so cost estimation doesn't stay at $0.00 for Anthropic-bound turns.
        in_tok = (usage.get("prompt_tokens") or usage.get("input_tokens") or 0)
        out_tok = (usage.get("completion_tokens") or usage.get("output_tokens") or 0)
        cost_paid = 0.0
        cost_saved = 0.0
        if ollama_called and not fallback_called:
            # We would have paid Sonnet; we paid 0
            cost_saved = estimate_cost_usd("claude-sonnet-4-6", in_tok, out_tok)
        elif fallback_called:
            cost_paid = estimate_cost_usd(state.get("original_model") or "claude-sonnet-4-6", in_tok, out_tok)
        else:
            cost_paid = estimate_cost_usd(state.get("original_model") or "claude-sonnet-4-6", in_tok, out_tok)

        # 2026-05-18 cache-diagnosis: capture Anthropic's response.id +
        # diagnostics payload. Skip on Ollama-routed turns (no Anthropic ID)
        # and on the silent-fallback path (the fallback call would already
        # have been logged by its own pre/post hook cycle if we were chained,
        # which we aren't — fallback calls bypass the hook entirely. The
        # primary call we're post-processing here IS the Anthropic call when
        # the label was `hard`).
        if CACHE_DIAG_ENABLED and not ollama_called and "cache_diag_window" in state:
            try:
                window_key = state["cache_diag_window"]
                prev_id_sent = state.get("cache_diag_prev_id_sent")

                # Anthropic-native response shape preserves top-level `id` and
                # `diagnostics`. LiteLLM may store them under `_hidden_params`
                # or alongside `choices`. Cover both.
                msg_id = (
                    resp_dict.get("id")
                    or resp_dict.get("response_id")
                    or (resp_dict.get("_hidden_params") or {}).get("response_id")
                    or ""
                )
                diagnostics = (
                    resp_dict.get("diagnostics")
                    or (resp_dict.get("_hidden_params") or {}).get("diagnostics")
                )

                # Roll the new message_id forward into CACHE_DIAG_PREV_ID
                # for this window so the NEXT turn sends it as prev_id.
                if msg_id:
                    CACHE_DIAG_PREV_ID[window_key] = {
                        "prev_id": msg_id,
                        "ts": time.time(),
                    }

                # Anthropic's usage payload on cache-aware responses includes
                # cache_read_input_tokens + cache_creation_input_tokens. Pull
                # them from wherever LiteLLM left them.
                an_usage = (
                    resp_dict.get("usage")
                    or (resp_dict.get("_hidden_params") or {}).get("usage")
                    or {}
                )
                cache_read = (
                    an_usage.get("cache_read_input_tokens")
                    or an_usage.get("prompt_tokens_details", {}).get("cached_tokens")
                    or 0
                )
                cache_creation = an_usage.get("cache_creation_input_tokens") or 0

                # Parse cache_miss_reason out of diagnostics, with the four-
                # state schema Anthropic documents (absent / null / {miss:null}
                # / {miss:<reason>}).
                miss_reason = None
                diag_json = None
                if isinstance(diagnostics, dict):
                    miss_reason = diagnostics.get("cache_miss_reason")
                    try:
                        diag_json = json.dumps(diagnostics)
                    except Exception:
                        diag_json = None

                _cache_diag_write({
                    "ts": int(time.time()),
                    "request_hash": req_hash,
                    "window_key": window_key,
                    "model": state.get("original_model"),
                    "message_id": msg_id or None,
                    "previous_message_id_sent": prev_id_sent,
                    "diagnostics_json": diag_json,
                    "cache_miss_reason": miss_reason,
                    "usage_input_tokens": in_tok,
                    "usage_cache_read": cache_read,
                    "usage_cache_creation": cache_creation,
                    "usage_output_tokens": out_tok,
                })

                # Amortized eviction so the in-memory dict stays bounded.
                _cache_diag_evict_stale()
            except Exception as e:
                print(f"[cline-router] cache-diag post-call log failed: "
                      f"{type(e).__name__}: {e}")

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
            "request_size_bytes": _safe_size(data),
            "response_size_bytes": _safe_size(resp_dict),
            "rollout_mode": ROLLOUT_MODE,
        })

        return fallback_resp if fallback_called else response

    # ---------- Streaming variant (Phase 5B+) ----------

    async def async_post_call_streaming_iterator_hook(self, user_api_key_dict, response, request_data):
        """For SSE streaming responses, we can't replay easily. Pass through
        and write a minimal audit row at stream-end. R1-R9 doesn't run on
        streams yet (TODO Phase 5B). 2026-05-11: at least log the routing
        decision so the audit DB reflects what happened.
        """
        async for chunk in response:
            yield chunk
        # Stream-end: write audit row based on pre-call state so we can see
        # routing decisions on streamed turns too.
        req_hash = request_data.get("_emsu_request_hash")
        state = self.request_state.pop(req_hash, None)
        if not state:
            return
        try:
            total_ms = int((time.time() - state["t_start"]) * 1000)
            routed = state.get("routed_to", "") or ""
            ollama_called = (routed.startswith("ollama-") or routed.startswith("emsu-"))
            # Cost note: streaming responses don't easily expose final token counts in this hook
            # signature; we record 0 and let the actual upstream provider's billing be the source
            # of truth. Cost-saved estimate is approximate (small message). This is just a routing
            # visibility row.
            _audit_write({
                "ts": int(time.time()),
                "request_hash": req_hash,
                "classifier_label": state["label"],
                "classifier_confidence": state["conf"],
                "classifier_reason": state["reason"],
                "classifier_tier": state["tier"],
                "ollama_called": int(ollama_called),
                "ollama_model": state.get("routed_to") if ollama_called else None,
                "ollama_latency_ms": total_ms,
                "ollama_input_tokens": 0,
                "ollama_output_tokens": 0,
                "fail_reason": "streaming:no_r_rules" if ollama_called else None,
                "fallback_called": 0,
                "fallback_model": None,
                "fallback_latency_ms": 0,
                "total_latency_ms": total_ms,
                "estimated_cost_saved_usd": 0,
                "estimated_cost_paid_usd": 0,
                "request_size_bytes": _safe_size(request_data),
                "response_size_bytes": 0,
                "rollout_mode": ROLLOUT_MODE,
            })
        except Exception:
            pass
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
                "ollama_called": 1 if (state.get("routed_to") or "").startswith(("ollama-", "emsu-")) else 0,
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
                "request_size_bytes": _safe_size(request_data),
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
