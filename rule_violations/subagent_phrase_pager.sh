#!/bin/bash
# subagent_phrase_pager.sh
# Out-of-band watchdog for .clinerules rule 17 (subagent dispatch).
#
# Polls the most-recent Cline task folder every 60s. If the LAST real
# (typed) user message matches the subagent-trigger regex AND the next
# assistant turn's first tool_use is NOT `use_subagents`, send an iMessage
# to Ruben.
#
# Filters out:
#   - .clinerules text echo (the rule itself contains "use subagents")
#   - tool-result echoes ([attempt_completion] Result, etc.)
#   - <environment_details> blocks
#   - System resumption / framework messages
#
# Dedupes via /tmp/subagent-pager-seen.txt
#
set +e

LOG=/tmp/subagent-pager.log
ALERTS=/tmp/subagent-pager-alerts.log
SEEN=/tmp/subagent-pager-seen.txt
# Recipient gate. Default: log-only, no iMessage send.
# To re-enable SMS, set SUBAGENT_PAGER_RECIPIENT to a phone/email in
# ~/.subagent-pager.conf (e.g. SUBAGENT_PAGER_RECIPIENT="+1XXXXXXXXXX").
# 2026-05-04: removed hardcoded +12196280702 (Jon's number) — wrong surface.
SUBAGENT_PAGER_RECIPIENT=""
[[ -f "$HOME/.subagent-pager.conf" ]] && source "$HOME/.subagent-pager.conf"
TASKS_DIR="$HOME/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks"
NOW=$(date -Iseconds)

touch "$SEEN" 2>/dev/null

# Find the latest task folder
LATEST=$(ls -1dt "$TASKS_DIR"/*/ 2>/dev/null | head -1)
if [[ -z "$LATEST" ]]; then
  echo "[$NOW] no task folders" >> "$LOG"
  exit 0
fi
TASK_ID=$(basename "$LATEST")

API_HIST="$LATEST/api_conversation_history.json"
if [[ ! -f "$API_HIST" ]]; then
  echo "[$NOW] task=$TASK_ID no api_conversation_history.json" >> "$LOG"
  exit 0
fi

# Use python to walk the messages
RESULT=$(/usr/bin/env python3 - <<'PYEOF' "$API_HIST" 2>/dev/null
import sys, json, re

api_path = sys.argv[1]
try:
    with open(api_path) as f:
        msgs = json.load(f)
except Exception as e:
    print(f"PARSE_ERROR: {e}")
    sys.exit(0)

# Find the LAST real user message (not tool result, not framework noise)
def is_real_user_message(msg):
    if msg.get("role") != "user":
        return False
    content = msg.get("content", [])
    if isinstance(content, str):
        return True
    if not isinstance(content, list):
        return False
    # Must have at least one text block (not just tool_result)
    for block in content:
        if isinstance(block, dict) and block.get("type") == "text":
            return True
    return False

def extract_user_text(msg):
    content = msg.get("content", [])
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                parts.append(block.get("text", ""))
        return "\n".join(parts)
    return ""

# Subagent trigger regex
TRIGGER_RE = re.compile(
    r'(?:use\s+sub\.?\s*agent|parallel\s+research|dispatch\s+sub\.?\s*agent|have\s+a\s+sub\.?\s*agent)',
    re.IGNORECASE
)

# Walk messages, find LAST real user message with trigger phrase
last_match_idx = None
last_match_text = None
for i, msg in enumerate(msgs):
    if not is_real_user_message(msg):
        continue
    text = extract_user_text(msg)
    # Strip <environment_details> block
    text_clean = re.sub(r'<environment_details>.*?</environment_details>', '', text, flags=re.DOTALL)
    # Strip [tool] Result: prefixes
    text_clean = re.sub(r'\[\w+\] Result:.*', '', text_clean, flags=re.DOTALL)
    # Strip out lines that look like .clinerules echo (lines starting with ## or - within rules)
    # Prefer content inside <feedback> or <task> tags
    feedback_match = re.search(r'<feedback>(.*?)</feedback>', text, re.DOTALL)
    task_match = re.search(r'<task>(.*?)</task>', text, re.DOTALL)
    user_message_match = re.search(r'<user_message>(.*?)</user_message>', text, re.DOTALL)
    
    candidate_texts = []
    if feedback_match:
        candidate_texts.append(feedback_match.group(1))
    if task_match:
        candidate_texts.append(task_match.group(1))
    if user_message_match:
        candidate_texts.append(user_message_match.group(1))
    if not candidate_texts:
        candidate_texts.append(text_clean)
    
    for ct in candidate_texts:
        if TRIGGER_RE.search(ct):
            last_match_idx = i
            last_match_text = ct[:200]
            break

if last_match_idx is None:
    print("NO_TRIGGER")
    sys.exit(0)

# Find the NEXT assistant message after this user message
next_assistant = None
for j in range(last_match_idx + 1, len(msgs)):
    if msgs[j].get("role") == "assistant":
        next_assistant = msgs[j]
        break

if next_assistant is None:
    # No assistant response yet — Cline still working on it. Don't flag.
    print("PENDING")
    sys.exit(0)

# Inspect tool_use blocks in order
content = next_assistant.get("content", [])
first_tool = None
all_tools = []
if isinstance(content, list):
    for block in content:
        if isinstance(block, dict) and block.get("type") == "tool_use":
            tool_name = block.get("name", "")
            all_tools.append(tool_name)
            if first_tool is None:
                first_tool = tool_name

if first_tool is None:
    print(f"NO_TOOL_USE|user_idx={last_match_idx}|trigger={last_match_text[:80]}")
    sys.exit(0)

if first_tool == "use_subagents":
    print(f"OK_DISPATCHED|user_idx={last_match_idx}")
    sys.exit(0)

# VIOLATION
print(f"VIOLATION|user_idx={last_match_idx}|first_tool={first_tool}|all_tools={','.join(all_tools)}|trigger={last_match_text[:80]}")
PYEOF
"$API_HIST")

# Parse result
case "$RESULT" in
  ""|NO_TRIGGER|OK_DISPATCHED*|PENDING)
    # No alert needed
    echo "[$NOW] task=$TASK_ID result=$RESULT" >> "$LOG"
    exit 0
    ;;
  PARSE_ERROR*)
    echo "[$NOW] task=$TASK_ID $RESULT" >> "$LOG"
    exit 0
    ;;
  VIOLATION*|NO_TOOL_USE*)
    # Check dedup
    DEDUP_KEY="$TASK_ID|$(echo "$RESULT" | cut -d'|' -f2)"
    if grep -qF "$DEDUP_KEY" "$SEEN" 2>/dev/null; then
      echo "[$NOW] task=$TASK_ID already paged ($DEDUP_KEY)" >> "$LOG"
      exit 0
    fi
    echo "$DEDUP_KEY" >> "$SEEN"
    
    # Build alert
    FIRST_TOOL=$(echo "$RESULT" | grep -oE 'first_tool=[^|]+' | sed 's/first_tool=//')
    [[ -z "$FIRST_TOOL" ]] && FIRST_TOOL="(none)"
    MSG="cline rule 17 missed: you said 'use subagents' but cline dispatched $FIRST_TOOL instead. task #$TASK_ID. ping cline to redo."
    
    echo "[$NOW] ALERT task=$TASK_ID first_tool=$FIRST_TOOL" >> "$LOG"
    # Always log to alerts file
    echo "[$NOW] task=$TASK_ID first_tool=$FIRST_TOOL msg=\"$MSG\"" >> "$ALERTS"

    # Only send iMessage if recipient is explicitly configured.
    # Default = log-only (silent). Set SUBAGENT_PAGER_RECIPIENT in
    # ~/.subagent-pager.conf to re-enable SMS.
    if [[ -n "$SUBAGENT_PAGER_RECIPIENT" ]]; then
      /usr/bin/osascript <<APPLEEOF 2>>"$LOG"
tell application "Messages"
    set targetService to 1st service whose service type = iMessage
    set targetBuddy to buddy "$SUBAGENT_PAGER_RECIPIENT" of targetService
    send "$MSG" to targetBuddy
end tell
APPLEEOF
      echo "[$NOW] paged $SUBAGENT_PAGER_RECIPIENT" >> "$LOG"
    else
      echo "[$NOW] log-only (SUBAGENT_PAGER_RECIPIENT unset)" >> "$LOG"
    fi
    ;;
esac

exit 0
