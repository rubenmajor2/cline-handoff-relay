#!/usr/bin/env python3
"""
cline_budget_watchdog.py — track per-task context budget and warn before condense

Per orchestrator_idea #5354 (Layer 1, P1, approved). Companion to Phase 3 (#5351).

Watches the LATEST Cline task's ui_messages.json. Computes per-turn token usage
from the last `api_req_started` entry and tags it GREEN/YELLOW/RED/IMMINENT.
Writes status to /tmp/cline_budget_status.json and rotates a log at
~/Library/Logs/cline_budget.log.

Triggers macOS notification first time a task crosses 800K (RED) and again at
900K (IMMINENT). Notification text steers the agent (you) to durable-artifact
the current state before condense fires.

Runs as launchd agent (com.emsu.cline-budget-watchdog) every 60s.
Reversal: launchctl unload ~/Library/LaunchAgents/com.emsu.cline-budget-watchdog.plist
"""
import json
import os
import glob
import time
import subprocess
import sys
from typing import Optional

HOME = os.path.expanduser("~")
TASKS_DIR = os.path.join(HOME, "Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks")
STATUS_FILE = "/tmp/cline_budget_status.json"
LOG_FILE = os.path.join(HOME, "Library/Logs/cline_budget.log")
NOTIFIED_FILE = "/tmp/cline_budget_notified.json"  # tracks which tasks already got RED/IMMINENT notice

# Thresholds (input + cache_read + cache_write tokens summed for latest req)
# 2026-05-30 cline (idea #8370): RED lowered 800K→700K so compress fires with
# more headroom before context growth blows past the 1M Anthropic hard cap
# (the "prompt is too long: N tokens > 1000000 maximum" 400 class).
GREEN_MAX   = 500_000
YELLOW_MAX  = 700_000
RED_MAX     = 900_000
# > RED_MAX = IMMINENT

# ── Mechanical compress signal (idea #22282, 2026-08-04) ──────────────────────
# Per rule 119, thresholds are FRACTIONS of the model's real context window W,
# not fixed counts. The watchdog computes W from a config file so a 200K model
# and a 1M model get different, correct thresholds without any LLM involvement.
# When context cross the CHECK (0.55W) or COMPRESS (0.75W) boundary, the
# watchdog writes a SIGNAL FILE the model must mechanically read pre-turn.
# The model NEVER decides "should I compress?" — the file decides.
SIGNAL_DIR = "/tmp"
WATCHDOG_CFG = os.path.join(HOME, ".config", "emsu", "budget_watchdog.json")
# Defaults: 200K model window (most common on this fleet). Override in cfg.
DEFAULT_MODEL_WINDOW = 200_000
CHECK_FRAC   = 0.55
COMPRESS_FRAC = 0.75
# Cooldown: never rewrite the same signal level more than once per N seconds.
SIGNAL_COOLDOWN = 300  # 5 min

def load_cfg(default_model_window=DEFAULT_MODEL_WINDOW) -> dict:
    cfg = {"model_window": default_model_window}
    try:
        if os.path.exists(WATCHDOG_CFG):
            with open(WATCHDOG_CFG) as f:
                cfg.update(json.load(f))
    except Exception as e:
        log(f"err loading cfg {WATCHDOG_CFG}: {e}")
    return cfg

import re as _re

# Regex matching Cline's environment_details line:
#   "Context Window Usage: 340,193 / 1,000,000 tokens used (34%)"
# Y (the second number) is the model's reported window ceiling.
_CTX_RE = _re.compile(r"Context Window Usage:\s*[\d,]+\.?\d*\s*/\s*([\d,]+\.?\d*\s*[KkMm]?)\s*tokens?", _re.I)

# Standard fleet windows (Cline/Anthropic/router tiers). Used for escalation
# when detected Y is unavailable: if current ctx exceeds a window's capacity,
# the real window must be the next tier up.
# Per rule 297 (verified against doorman LADDER 2026-08-05):
#   32K  — local Ollama 7B/14B/32B, GLM-5.2-LOCAL (744B params, 32K ctx)
#   128K — phi-4-mini, DeepSeek-V3-MESS, kimi-k3
#   200K — Claude Sonnet/Opus-4.8/Fable-5, Gemini 2.5 Pro
#   1M   — 120B class (Cesar/Cato/Artemis DeepSeek); 405B tier removed (stale, Ruben 2026-08-05)
KNOWN_WINDOWS = (1_000_000, 200_000, 128_000, 32_000)

def pick_window(estimated_cap: int) -> int:
    """Return the smallest KNOWN_WINDOWS >= estimated_cap, else max."""
    for w in sorted(KNOWN_WINDOWS):
        if w >= estimated_cap:
            return w
    return max(KNOWN_WINDOWS)

def detect_window_from_task(task_dir: str) -> Optional[int]:
    """Best-effort detect the model's context window W from the task's own
    environment_details. Y in 'X / Y tokens used' is the window the router
    reports for THIS task. Fall back to cfg on failure.
    """
    for fname in ("ui_messages.json", "api_conversation_history.json"):
        p = os.path.join(task_dir, fname)
        if not os.path.exists(p):
            continue
        try:
            with open(p, "r", encoding="utf-8", errors="replace") as f:
                data = json.load(f)
        except Exception:
            continue
        # walk every message's text fields looking for the latest occurrence
        best = None
        def walk(o):
            nonlocal best
            if isinstance(o, dict):
                for v in o.values():
                    walk(v)
            elif isinstance(o, list):
                for v in o:
                    walk(v)
            elif isinstance(o, str):
                m = _CTX_RE.search(o)
                if m:
                    try:
                        raw = m.group(1).replace(",", "").strip().upper()
                        if raw.endswith("K"):
                            w = int(float(raw.replace("K", "")) * 1000)
                        elif raw.endswith("M"):
                            w = int(float(raw.replace("M", "")) * 1_000_000)
                        else:
                            w = int(float(raw))
                        if w >= 16_000:
                            best = w
                    except Exception:
                        pass
        try:
            walk(data)
        except Exception:
            continue
        if best:
            return best
    return None

def write_compress_signal(task_id: str, action: str, ctx: int, w: int, reason: str) -> bool:
    """Write /tmp/cline_compress_signal_TASK<id>.json (or global fallback).
    Returns True if written, False if cooldown-suppressed.
    """
    signal_file = f"/tmp/cline_compress_signal_TASK{task_id}.json"
    existing = {}
    try:
        if os.path.exists(signal_file):
            with open(signal_file) as f:
                existing = json.load(f)
    except Exception:
        pass
    now = time.time()
    last_ts = existing.get("written_at_epoch", 0)
    if existing.get("action") == action and existing.get("task_id") == task_id:
        if now - last_ts < SIGNAL_COOLDOWN:
            return False  # same level already signaled recently
    payload = {
        "task_id": task_id,
        "action": action,                 # "check" | "compress"
        "context_size": ctx,
        "model_window": w,
        "check_threshold": int(round(CHECK_FRAC * w)),
        "compress_threshold": int(round(COMPRESS_FRAC * w)),
        "reason": reason,
        "written_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "written_at_epoch": now,
        "from": "cline_budget_watchdog",
        "instruction": (
            f"MECHANICAL action required. If action=compress call "
            f"cline_compress_session IMMEDIATELY with a rule-91 pickup prompt. "
            f"If action=check call should_compress_now once. Do not deliberate."
        ),
    }
    with open(signal_file, "w") as f:
        json.dump(payload, f, indent=2)
    log(f"SIGNAL {action} task={task_id} ctx={ctx} W={w}")
    return True

def log(msg: str) -> None:
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a") as f:
            f.write(f"[{time.strftime('%Y-%m-%dT%H:%M:%S%z')}] {msg}\n")
    except Exception:
        pass

def get_latest_task() -> Optional[str]:
    try:
        dirs = sorted(glob.glob(TASKS_DIR + "/*"), key=os.path.getmtime, reverse=True)
        return dirs[0] if dirs else None
    except Exception as e:
        log(f"err listing tasks: {e}")
        return None

def get_latest_req_tokens(task_dir: str) -> Optional[dict]:
    ui = os.path.join(task_dir, "ui_messages.json")
    if not os.path.exists(ui):
        return None
    try:
        with open(ui) as f:
            data = json.load(f)
    except Exception as e:
        log(f"err reading {ui}: {e}")
        return None

    latest = None
    for m in data:
        if m.get("type") == "say" and m.get("say") == "api_req_started":
            try:
                d = json.loads(m.get("text", "{}"))
                latest = d
            except Exception:
                pass
    if not latest:
        return None

    in_tok    = latest.get("tokensIn", 0) or 0
    out_tok   = latest.get("tokensOut", 0) or 0
    cache_r   = latest.get("cacheReads", 0) or 0
    cache_w   = latest.get("cacheWrites", 0) or 0
    cost      = latest.get("cost", 0.0) or 0.0
    # The "in-context" budget that risks condense is roughly cache_reads + new tokens
    # cache_writes happen on the new content path, so they count too
    context_size = in_tok + cache_r + cache_w
    return {
        "tokensIn": in_tok,
        "tokensOut": out_tok,
        "cacheReads": cache_r,
        "cacheWrites": cache_w,
        "cost": cost,
        "context_size": context_size,
    }

def classify(ctx: int) -> str:
    if ctx < GREEN_MAX:  return "GREEN"
    if ctx < YELLOW_MAX: return "YELLOW"
    if ctx < RED_MAX:    return "RED"
    return "IMMINENT"

def load_notified() -> dict:
    try:
        with open(NOTIFIED_FILE) as f:
            return json.load(f)
    except Exception:
        return {}

def save_notified(d: dict) -> None:
    try:
        with open(NOTIFIED_FILE, "w") as f:
            json.dump(d, f)
    except Exception:
        pass

def macos_notify(title: str, msg: str) -> None:
    try:
        # Use AppleScript display notification; quiet failure if Mac headless or display unavailable
        subprocess.run([
            "osascript", "-e",
            f'display notification "{msg}" with title "{title}" sound name "Submarine"'
        ], timeout=5, check=False)
    except Exception as e:
        log(f"notify err: {e}")

def main():
    task_dir = get_latest_task()
    if not task_dir:
        return
    task_id = os.path.basename(task_dir)
    tokens = get_latest_req_tokens(task_dir)
    if not tokens:
        return

    tier = classify(tokens["context_size"])
    status = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "task_id": task_id,
        "tier": tier,
        "context_size": tokens["context_size"],
        "in": tokens["tokensIn"],
        "cache_r": tokens["cacheReads"],
        "cache_w": tokens["cacheWrites"],
        "cost": round(tokens["cost"], 4),
        "thresholds": {"GREEN": GREEN_MAX, "YELLOW": YELLOW_MAX, "RED": RED_MAX},
    }
    with open(STATUS_FILE, "w") as f:
        json.dump(status, f, indent=2)
    # P1 — idea #7377: also write per-task file so concurrent tasks don't clobber each other
    per_task_file = f"/tmp/cline_budget_status_TASK{task_id}.json"
    with open(per_task_file, "w") as f:
        json.dump(status, f, indent=2)

    # ── Mechanical compress signal (idea #22282) ───────────────────────────────
    # W-based thresholds per rule 119. Same numbers rule 119 derives, computed
    # HERE so the model never has to reason about them.
    ctx = tokens["context_size"]
    cfg = load_cfg()
    # Auto-detect W from task's own environment_details (idea #22282 bugfix 2026-08-04).
    # Hardcoded W=128K was correct for 128K windows but wrong for 200K/1M windows,
    # causing premature compress signals (e.g. 340K context triggering compress at 96K).
    detected = detect_window_from_task(task_dir)
    if detected and detected >= 16_000:
        W = detected
    else:
        W = int(cfg.get("model_window", DEFAULT_MODEL_WINDOW))
    # Self-correction: if context_size > COMPRESS threshold for current W,
    # W is demonstrably WRONG (you can't use 340K tokens on a 128K window).
    # Escalate to the next known tier.
    if ctx > COMPRESS_FRAC * W:
        corrected = pick_window(int(ctx / COMPRESS_FRAC))  # find smallest W that fits
        if corrected > W:
            log(f"W_ESCALATE {W}->{corrected} (ctx={ctx} > 0.75x{W}={int(COMPRESS_FRAC*W)})")
            W = corrected
    check_at = int(round(CHECK_FRAC * W))
    compress_at = int(round(COMPRESS_FRAC * W))
    if ctx >= compress_at:
        write_compress_signal(task_id, "compress", ctx, W,
                              f"context {ctx:,} >= compress threshold {compress_at:,} (0.75×W={W:,})")
    elif ctx >= check_at:
        write_compress_signal(task_id, "check", ctx, W,
                              f"context {ctx:,} >= check threshold {check_at:,} (0.55×W={W:,})")
    else:
        # Below CHECK: remove any stale signal for this task so the model
        # isn't told to compress when context already dropped (e.g. after
        # a fresh-window pickup or a manual compress).
        stale = f"/tmp/cline_compress_signal_TASK{task_id}.json"
        try:
            if os.path.exists(stale):
                os.remove(stale)
                log(f"SIGNAL clear task={task_id} ctx={ctx} < check {check_at}")
        except Exception as e:
            log(f"err clearing signal {stale}: {e}")

    # Notification logic: only fire once per task per tier (RED, IMMINENT)
    if tier in ("RED", "IMMINENT"):
        notified = load_notified()
        key = f"{task_id}:{tier}"
        if key not in notified:
            if tier == "RED":
                title = "Cline budget RED (>700K)"
                msg   = "Write current state to HANDOFF/ledger/idea before next risky tool. Condense risk approaching."
            else:
                title = "Cline budget IMMINENT (>900K)"
                msg   = "Auto-condense imminent. Save state NOW. Use attempt_completion + pickup prompt to spawn fresh window."
            macos_notify(title, msg)
            notified[key] = status["ts"]
            # Prune entries older than 24h to keep file tiny
            cutoff = time.time() - 86400
            notified = {k: v for k, v in notified.items() if isinstance(v, str)}
            save_notified(notified)
            log(f"NOTIFIED {tier} task={task_id} ctx={tokens['context_size']}")
        else:
            log(f"tier={tier} task={task_id} ctx={tokens['context_size']} (already notified)")
    else:
        log(f"tier={tier} task={task_id} ctx={tokens['context_size']}")

if __name__ == "__main__":
    main()
