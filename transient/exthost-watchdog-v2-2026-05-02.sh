#!/usr/bin/env bash
# Cline ext-host runaway watchdog (Artemis) — v2 with kill-tier escalation
#
# 2026-05-02 21:10 PT update — added SIGTERM/SIGKILL escalation tier per
# #cline-tempe-signin-unreachable-2026-05-02 root-cause investigation.
# Symptom that triggered this: 6 ext-hosts had been reniced +15 at ~19:22 PT
# in the panic+storm post-mortem but stayed at 14-15GB RSS for 90+ minutes,
# starving code-server's own /login until Ruben hit
# /emtskills/routes/cline_tempe_signin.php at 20:47 PT and got "unreachable".
# Renice alone can't recover from sustained-bloat: V8 won't OOM under 16GB,
# cgroup won't kill under 100GB, and a 35%-CPU process at nice +15 is still
# enough load to starve siblings on a 16-vCPU box.
#
# DESIGN PRINCIPLES (from Mac postmortem 2026-04-18 + Artemis 2026-05-02):
# 1. Multiple AND'd signals — single-snapshot evidence is not death.
#    Require 2 consecutive cycles >threshold before reniceing.
# 2. Per-PID cooldown — never renice the same PID twice in <10 min.
# 3. Rate sanity — never act on more than N PIDs/hour.
# 4. Heartbeat file every run so RUBEN can detect if watchdog itself dies.
# 5. **NEW**: Kill tier. If a PID stays bloated 10+ min AFTER renice (i.e.
#    renice didn't recover it), SIGTERM. If still alive 30s later, SIGKILL.
#    Per-PID kill cooldown 30 min. Rate-capped at 3 kills/hour.
#    Reload-required PIDs get logged so the operator knows which Cline
#    windows to refresh. Task data on disk is never touched.
# 6. Strict ext-host filter — pgrep -f 'bootstrap-fork --type=extensionHost'
#    only. We never touch the code-server parent or pty fork.
#
# Companion to .clinerules/96-cline-window-discipline.md and 97-extension-host-oom.md
# Pattern registered in admin_portal.orchestrator_learned_patterns:
#   exthost-watchdog-runaway-renice-2026-05-02
#   exthost-watchdog-killtier-2026-05-02

set -uo pipefail

STATE_DIR=/var/tmp/cline-watchdog-state
HEARTBEAT=/var/tmp/cline-watchdog-heartbeat
LOG=/var/log/cline-watchdog.log
KILL_LOG=/var/log/cline-watchdog-kills.log

CPU_THRESHOLD_PCT=70             # sustained pcpu (lifetime avg)
RSS_THRESHOLD_KB=12582912        # 12 GB; cap is 16, leaves room
RENICE_COOLDOWN_SEC=600          # 10 min per-PID renice cooldown
KILL_GRACE_SEC=600               # how long after renice before we're allowed to kill (10 min)
KILL_COOLDOWN_SEC=1800           # per-PID 30 min — should never re-fire on same PID
SIGTERM_TO_SIGKILL_SEC=30        # how long to wait for graceful exit
MIN_AGE_SEC=60                   # ignore <60s old (still activating)
MAX_RENICES_PER_HOUR=6           # rate cap on renice
MAX_KILLS_PER_HOUR=3             # rate cap on kill — anything more is a systemic fire

mkdir -p "$STATE_DIR" 2>/dev/null
mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
touch "$LOG" 2>/dev/null || LOG=/tmp/cline-watchdog.log
touch "$KILL_LOG" 2>/dev/null || KILL_LOG=/tmp/cline-watchdog-kills.log

ts() { date -Iseconds; }
now_epoch() { date +%s; }

# Convert ps etime (e.g. "01:23" or "1-02:03:45") to seconds. Defensive.
etime_to_seconds() {
  local et="$1"
  local days=0 h=0 m=0 s=0
  if [[ "$et" == *-* ]]; then
    days=${et%%-*}
    et=${et#*-}
  fi
  IFS=: read -r p1 p2 p3 <<<"$et"
  if [[ -n "${p3:-}" ]]; then
    h=$p1; m=$p2; s=$p3
  elif [[ -n "${p2:-}" ]]; then
    m=$p1; s=$p2
  else
    s=$p1
  fi
  echo $(( days*86400 + 10#$h*3600 + 10#$m*60 + 10#$s ))
}

# Count entries with TAG in last hour from $LOG (rate-cap signal)
count_last_hour() {
  local tag="$1"
  local cutoff
  cutoff=$(date -d '1 hour ago' '+%Y-%m-%dT%H:%M:%S' 2>/dev/null) || cutoff=""
  [[ -z "$cutoff" ]] && { echo 0; return; }
  awk -v c="$cutoff" -v t="$tag" '$1 >= c && $0 ~ t' "$LOG" 2>/dev/null | wc -l | tr -d ' '
}

NOW=$(now_epoch)
RECENT_RENICES=$(count_last_hour 'RENICE')
RECENT_KILLS=$(count_last_hour 'KILL ')

# Resolve which task_id is bound to a given ext-host PID, if we can. Used
# only for the operator-facing "which window to reload" hint in KILL_LOG.
# Best-effort — don't fail the whole run if it can't figure it out.
task_hint_for_pid() {
  local pid="$1"
  local cmdline
  cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
  # ext-host has --vscode-task or workspace path embedded; surface what we can
  # Just dump the first 200 chars — operator can grep.
  echo "${cmdline:0:200}"
}

# Walk all ext-host PIDs
mapfile -t pids < <(pgrep -f 'bootstrap-fork --type=extensionHost' 2>/dev/null)

reniced=0
killed=0
debounced=0
cooldown=0
ratecapped=0
seen=0

for pid in "${pids[@]}"; do
  [[ -d /proc/$pid ]] || continue
  seen=$((seen+1))

  read pcpu rss state etime <<<"$(ps -o pcpu=,rss=,stat=,etime= -p "$pid" 2>/dev/null)"
  [[ -z "${pcpu:-}" ]] && continue

  pcpu_int=${pcpu%%.*}
  pcpu_int=${pcpu_int:-0}

  age_sec=$(etime_to_seconds "$etime")
  (( age_sec < MIN_AGE_SEC )) && continue

  trigger=""
  if (( pcpu_int >= CPU_THRESHOLD_PCT )); then
    trigger="cpu=${pcpu}%"
  fi
  if (( rss >= RSS_THRESHOLD_KB )); then
    rss_gb=$(( rss / 1024 / 1024 ))
    trigger="${trigger:+$trigger,}rss=${rss_gb}GB"
  fi

  if [[ -z "$trigger" ]]; then
    rm -f "$STATE_DIR/strike.$pid" 2>/dev/null
    continue
  fi

  STRIKE_FILE="$STATE_DIR/strike.$pid"
  RENICE_FILE="$STATE_DIR/cooldown.$pid"
  RENICED_AT_FILE="$STATE_DIR/reniced_at.$pid"
  KILL_FILE="$STATE_DIR/kill.$pid"

  # ============================================================
  # KILL TIER — runs FIRST (before debounce/renice path) so that
  # a PID we already reniced and that is STILL bloated escalates,
  # rather than being permanently held in renice-cooldown.
  # ============================================================
  if [[ -f "$RENICED_AT_FILE" ]]; then
    reniced_at=$(cat "$RENICED_AT_FILE" 2>/dev/null || echo 0)
    age_since_renice=$(( NOW - reniced_at ))

    if (( age_since_renice >= KILL_GRACE_SEC )); then
      # Per-PID kill cooldown
      if [[ -f "$KILL_FILE" ]]; then
        last_kill=$(cat "$KILL_FILE" 2>/dev/null || echo 0)
        if (( NOW - last_kill < KILL_COOLDOWN_SEC )); then
          cooldown=$((cooldown+1))
          continue
        fi
      fi

      # Rate cap on kills
      if (( RECENT_KILLS >= MAX_KILLS_PER_HOUR )); then
        echo "$(ts) RATE_CAP_KILL pid=$pid trigger=$trigger recent_kills_1h=$RECENT_KILLS — log only, NOT killing" >> "$LOG"
        ratecapped=$((ratecapped+1))
        continue
      fi

      # ESCALATE — SIGTERM, wait, SIGKILL if needed.
      hint=$(task_hint_for_pid "$pid")
      echo "$(ts) KILL pid=$pid trigger=$trigger age_since_renice=${age_since_renice}s — SIGTERM, then SIGKILL after ${SIGTERM_TO_SIGKILL_SEC}s" >> "$LOG"
      echo "$(ts) pid=$pid trigger=$trigger cmdline=$hint" >> "$KILL_LOG"

      if kill -TERM "$pid" 2>/dev/null; then
        # Don't busy-wait the whole grace; just sleep briefly. The next cron
        # tick (60s later) will SIGKILL if it survived.
        sleep "$SIGTERM_TO_SIGKILL_SEC"
        if [[ -d /proc/$pid ]]; then
          kill -KILL "$pid" 2>/dev/null && \
            echo "$(ts) KILL pid=$pid escalated SIGTERM→SIGKILL (didn't exit in ${SIGTERM_TO_SIGKILL_SEC}s)" >> "$LOG"
        else
          echo "$(ts) KILL pid=$pid exited cleanly on SIGTERM" >> "$LOG"
        fi
      fi

      echo "$NOW" > "$KILL_FILE"
      rm -f "$STRIKE_FILE" "$RENICED_AT_FILE" 2>/dev/null
      killed=$((killed+1))
      RECENT_KILLS=$((RECENT_KILLS+1))
      continue
    fi
  fi

  # ============================================================
  # RENICE TIER (existing logic, unchanged in spirit)
  # ============================================================

  # SIGNAL 1 (debounce): require 2 consecutive cycles.
  if [[ ! -f "$STRIKE_FILE" ]]; then
    echo "$NOW $trigger" > "$STRIKE_FILE"
    debounced=$((debounced+1))
    continue
  fi

  # SIGNAL 2 (cooldown): per-PID. No renice within last RENICE_COOLDOWN_SEC.
  if [[ -f "$RENICE_FILE" ]]; then
    last=$(cat "$RENICE_FILE" 2>/dev/null || echo 0)
    if (( NOW - last < RENICE_COOLDOWN_SEC )); then
      cooldown=$((cooldown+1))
      continue
    fi
  fi

  # SIGNAL 3 (rate cap): system-wide.
  if (( RECENT_RENICES >= MAX_RENICES_PER_HOUR )); then
    echo "$(ts) RATE_CAP pid=$pid trigger=$trigger recent_renices_1h=$RECENT_RENICES — log only, no action" >> "$LOG"
    ratecapped=$((ratecapped+1))
    continue
  fi

  cur_nice=$(awk '{print $19}' /proc/$pid/stat 2>/dev/null || echo 0)
  if (( cur_nice < 15 )); then
    if renice -n 15 -p "$pid" >/dev/null 2>&1; then
      echo "$(ts) RENICE pid=$pid trigger=$trigger nice:$cur_nice->15 etime=$etime state=$state" >> "$LOG"
      echo "$NOW" > "$RENICE_FILE"
      echo "$NOW" > "$RENICED_AT_FILE"
      reniced=$((reniced+1))
      RECENT_RENICES=$((RECENT_RENICES+1))
    fi
  else
    # Already niced. Stamp reniced_at_file if missing so kill-tier eligible
    # after grace period. (Handles bootstrap case: existing reniced PIDs
    # from before this version of the script.)
    if [[ ! -f "$RENICED_AT_FILE" ]]; then
      echo "$NOW" > "$RENICED_AT_FILE"
    fi
  fi
  rm -f "$STRIKE_FILE" 2>/dev/null
done

# Garbage-collect state files for dead PIDs
for f in "$STATE_DIR"/strike.* "$STATE_DIR"/cooldown.* "$STATE_DIR"/reniced_at.* "$STATE_DIR"/kill.*; do
  [[ -f "$f" ]] || continue
  pid="${f##*.}"
  [[ -d /proc/$pid ]] || rm -f "$f" 2>/dev/null
done

# Heartbeat
{
  echo "ts=$(ts)"
  echo "ext_hosts_seen=$seen"
  echo "reniced_this_run=$reniced"
  echo "killed_this_run=$killed"
  echo "debounced_strikes=$debounced"
  echo "in_cooldown=$cooldown"
  echo "rate_capped=$ratecapped"
  echo "renices_last_hour=$RECENT_RENICES"
  echo "kills_last_hour=$RECENT_KILLS"
  echo "log=$LOG"
  echo "kill_log=$KILL_LOG"
  echo "state_dir=$STATE_DIR"
} > "$HEARTBEAT"

exit 0
