#!/bin/bash
# cline_lora_watcher.sh — Mac-side watcher daemon for #opus-train-ollama-replace-sonnet-2026-05-10.
#
# Polls every 5 min:
#   1. WOPR  → /opt/emsu-lora/train_qwen14b.log for `=== END TRAIN ===`. If found and not yet deployed, runs deploy_adapter_to_ollama.sh.
#   2. Artemis ipex install (when both v1 and v2 logs show end-tags). When ipex_llm imports clean AND /opt/emsu-lora-artemis/datasets/emsu-train.jsonl exists AND no train PID yet, launches Artemis training.
#   3. Re-shadow stage: when emsu-qwen:14b-lora appears in `ollama list`, runs the backtest script with --model emsu-qwen:14b-lora --n=200. If agreement ≥95%, flips ruben_executor_provider + ollama_default_model_for_classify.
#
# Logs to /tmp/cline-lora-watcher.log. Heartbeat to /tmp/cline-lora-watcher.heartbeat.
# Lock at /tmp/cline-lora-watcher.lock so two copies don't race.

LOG=/tmp/cline-lora-watcher.log
HB=/tmp/cline-lora-watcher.heartbeat
PIDFILE=/tmp/cline-lora-watcher.pid
STATE=/tmp/cline-lora-watcher.state

# pidfile-based lock (macOS-friendly)
if [ -f "$PIDFILE" ]; then
  OLD=$(cat "$PIDFILE" 2>/dev/null)
  if [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null; then
    echo "[$(date -Iseconds)] another watcher running pid=$OLD, exit" >> "$LOG"
    exit 0
  fi
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

[ -f "$STATE" ] || touch "$STATE"
get_state() { grep "^$1=" "$STATE" 2>/dev/null | tail -1 | cut -d= -f2; }
set_state() { sed -i.bak "/^$1=/d" "$STATE" 2>/dev/null; echo "$1=$2" >> "$STATE"; }

while true; do
  date -Iseconds > "$HB"
  echo "[$(date -Iseconds)] tick" >> "$LOG"

  # ---- Track 1: WOPR train → deploy ----
  WOPR_TRAIN_DONE=$(ssh -o ConnectTimeout=10 -o BatchMode=yes wopr 'tail -200 /opt/emsu-lora/train_qwen14b.log 2>/dev/null | grep -c "=== END TRAIN ==="' 2>/dev/null || echo 0)
  if [ "${WOPR_TRAIN_DONE:-0}" -ge 1 ] && [ "$(get_state wopr_deploy_done)" != "1" ]; then
    echo "[$(date -Iseconds)] WOPR train END detected. Running deploy_adapter_to_ollama.sh..." >> "$LOG"
    ssh -o ConnectTimeout=10 wopr 'nohup bash /opt/emsu-lora/deploy_adapter_to_ollama.sh </dev/null >/dev/null 2>&1 & disown' >> "$LOG" 2>&1
    set_state wopr_deploy_done 1
  fi

  # Check if deploy created emsu-qwen:7b-lora in ollama (downsized from 14b to fit 16GB VRAM)
  LORA_AVAILABLE=$(ssh -o ConnectTimeout=10 -o BatchMode=yes wopr 'ollama list 2>/dev/null | grep -cE "emsu-qwen:(7b|14b)-lora"' 2>/dev/null || echo 0)
  if [ "${LORA_AVAILABLE:-0}" -ge 1 ] && [ "$(get_state reshadow_done)" != "1" ]; then
    echo "[$(date -Iseconds)] emsu-qwen:14b-lora available; launching re-shadow N=200" >> "$LOG"
    LORA_NAME=$(ssh -o ConnectTimeout=10 -o BatchMode=yes wopr 'ollama list 2>/dev/null | grep -oE "emsu-qwen:(7b|14b)-lora" | head -1')
    ssh -o ConnectTimeout=10 wopr "cd /var/www/emtskills && nohup php scripts/backtest_ab_grader_ollama_vs_haiku.php --n=200 --model=$LORA_NAME </dev/null > /tmp/cline-reshadow.log 2>&1 & disown"
    set_state lora_model_name "$LORA_NAME"
    set_state reshadow_launched 1
  fi

  # Check re-shadow result + flip if ≥95%
  if [ "$(get_state reshadow_launched)" = "1" ] && [ "$(get_state flipped)" != "1" ]; then
    AGREEMENT=$(ssh -o ConnectTimeout=10 -o BatchMode=yes wopr 'tail -50 /tmp/cline-reshadow.log 2>/dev/null | grep -oE "agreement[^=]*=\s*[0-9.]+%" | tail -1' 2>/dev/null)
    if [ -n "$AGREEMENT" ]; then
      PCT=$(echo "$AGREEMENT" | grep -oE "[0-9.]+" | head -1)
      if [ -n "$PCT" ] && [ "$(echo "$PCT >= 95.0" | bc -l 2>/dev/null)" = "1" ]; then
        echo "[$(date -Iseconds)] re-shadow PASSED at $PCT% — flipping provider=ollama_lora" >> "$LOG"
        LORA_NAME=$(get_state lora_model_name)
        ssh -o ConnectTimeout=10 wopr "mysql -u adminportal -p'iV84o80^y' admin_portal -e \"UPDATE orchestrator_config SET config_json = JSON_SET(config_json,'\\\$.ruben_executor_provider','ollama_lora','\\\$.ollama_default_model_for_classify','$LORA_NAME') WHERE id=1\"" >> "$LOG" 2>&1
        set_state flipped 1
        set_state flipped_at "$(date -Iseconds)"
        set_state flipped_pct "$PCT"
      elif [ -n "$PCT" ]; then
        echo "[$(date -Iseconds)] re-shadow FAILED at $PCT% < 95% — not flipping; investigate" >> "$LOG"
        set_state reshadow_done 1
        set_state reshadow_failed_pct "$PCT"
      fi
    fi
  fi

  # ---- Track 2: Artemis ipex → train ----
  ARTEMIS_IPEX_OK=$(ssh -o ConnectTimeout=10 -o BatchMode=yes artemis 'source /opt/emsu-lora-artemis/venv/bin/activate 2>/dev/null && python -c "import ipex_llm; import torch; print(\"OK\")" 2>/dev/null | grep -c OK' 2>/dev/null || echo 0)
  ARTEMIS_DATA_OK=$(ssh -o ConnectTimeout=10 -o BatchMode=yes artemis '[ -s /opt/emsu-lora-artemis/datasets/emsu-train.jsonl ] && echo OK' 2>/dev/null | grep -c OK)
  ARTEMIS_TRAIN_RUNNING=$(ssh -o ConnectTimeout=10 -o BatchMode=yes artemis 'pgrep -f train_qwen32b_ipex.py | wc -l' 2>/dev/null || echo 0)

  if [ "${ARTEMIS_IPEX_OK:-0}" -ge 1 ] && [ "${ARTEMIS_DATA_OK:-0}" -ge 1 ] && [ "${ARTEMIS_TRAIN_RUNNING:-0}" = "0" ] && [ "$(get_state artemis_train_started)" != "1" ]; then
    echo "[$(date -Iseconds)] Artemis ipex+data ready — launching B70 training" >> "$LOG"
    ssh -o ConnectTimeout=10 artemis 'nohup bash /opt/emsu-lora-artemis/launch_artemis_train.sh </dev/null >/dev/null 2>&1 & disown' >> "$LOG" 2>&1
    set_state artemis_train_started 1
    set_state artemis_train_started_at "$(date -Iseconds)"
  fi

  # If everything terminal-state, exit clean
  if [ "$(get_state flipped)" = "1" ] || [ "$(get_state reshadow_done)" = "1" ]; then
    echo "[$(date -Iseconds)] terminal state reached — exiting watcher" >> "$LOG"
    exit 0
  fi

  sleep 300
done
