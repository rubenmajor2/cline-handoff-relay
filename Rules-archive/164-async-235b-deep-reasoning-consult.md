# 164 — Async deep-reasoning consult: fire-and-forget the 235B (or 405B teacher) in the background, never block the interactive window

Source: 2026-06-16 Ruben directive — "make a cline rule: call the 235 for analysis but do it safely so it does not 000, and queue the task so it runs in the background while other work is being done, like a nohup. I don't really know when I'd use it TBH, would appreciate your opinion."

## My honest opinion first (when to actually use this)

The 235B (cicero, Qwen3-235B-A22B-**Thinking**, MLX on CICERO M5 :11520) is a SLOW deep reasoner: chains run **4-200s**, ~24-31 tok/s, `max_parallel_requests=1`. That slowness is exactly why it must NEVER be in the interactive Cline path (a 200s think would freeze your window) — and also why a **synchronous** call to it is almost always the wrong move during live work.

So the honest answer to "when would I use it": **rarely, and only for a question where a deeper/second-opinion answer is worth waiting minutes for, that you do NOT need before your next action.** Concretely:
- A hard architectural/design tradeoff you want a stronger model to sanity-check while you keep building.
- A "grade these N options / which approach is least risky" judgment where the 120B's answer is good-enough-now but you'd like the 235B's deeper take logged for later.
- A gnarly bug whose root cause you're unsure of — fire the 235B at it, keep debugging yourself, read its analysis when it lands.

If you need the answer to proceed RIGHT NOW, don't use this — use the fast 120B/Sonnet inline. The whole point of this pattern is **decoupling**: the consult runs in the background, you keep working, the result shows up when it's ready. If you find yourself never reaching for it, that's fine and expected — it's a power tool for the occasional hard call, not a daily habit.

## Does a clinerule "have cline rules attached"? (the practical mechanism)

A clinerule is just instructions to ME (Cline) — it has no runtime of its own. So "the rule calls the 235" really means: **when you say a trigger phrase, I (the active Cline window) dispatch the consult as a detached background job and immediately return to your work.** The async/nohup behavior lives in the SHELL command I run, not in the rule. The rule's job is to make me do it the SAFE way every time. Practically there are two layers:
1. **This rule** = the recipe + safety gates I follow.
2. **A tiny shell mechanism** (below) = the actual fire-and-forget + queue + result file.

## The trigger

If Ruben says any of: "consult the 235", "ask the 235", "background the 235 on this", "deep-reason this", "235 second opinion", "teacher-check this" → run the async consult below. NEVER call the 235B synchronously in an interactive window.

## The safe async recipe (how I run it — never blocks, never 000s your window)

The 235B "000" risk is NOT the 235B crashing — it's that a SYNCHRONOUS curl to a 200s think makes the CALLER hang/timeout (the litellm request_timeout is 300s; the SSH/tool wall is ~30s; a blocking call trips the tool wall = looks like a stall). The fix is to never wait on it. Pattern:

```
# Fire the 235B consult DETACHED on WOPR; write result to a known file. Returns instantly.
JOB=/tmp/cicero_consult_$(date +%s).json
PROMPT='<the question, self-contained>'
nohup bash -c '
  MK=$(grep -oP "LITELLM_MASTER_KEY=\K.*" /etc/litellm/env | head -1)
  curl -s --max-time 600 http://127.0.0.1:4000/v1/chat/completions \
    -H "Authorization: Bearer $MK" -H "Content-Type: application/json" \
    -d "{\"model\":\"cicero-235b\",\"messages\":[{\"role\":\"user\",\"content\":\"'"$PROMPT"'\"}],\"max_tokens\":1500}" \
    > '"$JOB"' 2>&1
' >/dev/null 2>&1 &
echo "consult queued -> $JOB (read it later; do NOT wait)"
```

Run this via the emsu-operations `ssh_command` (it returns in <1s because the `&` detaches the curl). Then **immediately go back to the user's actual task.** Later (next turn, or when Ruben asks "what did the 235 say"), read `$JOB` — if it's non-empty the consult is done; if empty it's still thinking.

### Safety gates (every async consult)
1. **Detached only** — the curl MUST end with `&` and the ssh_command MUST return immediately. NEVER a foreground curl to cicero-235b from an interactive window (that's the hang/"000" the user fears).
2. **One at a time** — 235B is `max_parallel_requests=1`. Use a flock (`flock -n /tmp/cicero_consult.lock`) so a second consult queues instead of colliding. If locked, tell Ruben "235 is busy on the prior consult, this one queues."
3. **Self-contained prompt** — the 235B has no conversation context. Inline everything it needs.
4. **Result file, not a wait** — always write to `/tmp/cicero_consult_<ts>.json` and read it on a LATER turn. The rule-41 "don't narrate, call the tool" discipline still applies: after firing, the next thing is real work, not "waiting for the 235."
5. **Never in the interactive routing** — this is an explicit, manual, Ruben-triggered consult. It does NOT go in the frankenstein-llm fallback chain (rule 146/148 — 235B is tier L4b batch only).

## Keep-warm (Ruben: "wasn't the whole idea to keep these warm so they're always usable? Is anything bad about it?")

Yes — keeping the fleet warm is the design, and **no, there is nothing bad about keeping the 235B warm.** A warm box means the consult's first token is fast (the model stays resident; verified 0.19s reachable). The only costs are (a) idle power/heat on the CICERO M5 and (b) the box can't sleep — both irrelevant for an always-on serving node. There is no downside that hurts correctness or other models (the 235B is on its own box, not competing for the 120Bs' VRAM). Keep it warm.

Current state (2026-06-16): the per-box keepwarm crons (`emsu-fleet-keepwarm-serving`) are being consolidated under idea **#12184 (Kaizen Talent-Manager: dynamic warm-set manager + measured-health routing)** — some standalone keepwarm crons were disabled (`.disabled-wsm-12184`) in favor of that central manager. So keep-warm isn't being abandoned, it's being centralized. The 235B is warm now. If a future window finds the 235B cold (slow first token), the fix is to ensure #12184's warm-set includes cicero-235b, OR re-enable the targeted keepwarm — NOT to remove keep-warm.

## Cold-start note (the 120B first-load spike, related)

The ~1-min first-load spike Ruben saw on a fresh frankenstein-llm window is the cold-KV prefill of a new ~100K-token conversation (NOT the 235B, which is off the interactive path). Keeping boxes warm helps the MODEL stay resident but does NOT pre-cache a NEW conversation's prefix. The cure for that specific spike is **prefix pre-warming the stable system+rules prefix** per box so turn-1 is a cache hit — a separate optional follow-up, not part of this rule.

## Self-check before any 235B/405B-teacher call

1. *Am I about to call cicero-235b (or frankenstein-405b) synchronously from an interactive window?* → STOP. Detach it (`nohup ... &`), return instantly, read the result file later.
2. *Does Ruben need this answer to take his next action?* → If yes, this is the wrong tool; use the fast 120B/Sonnet inline. Async consult is for "nice to have, worth waiting for."
3. *Is another consult already running?* → flock; queue it; tell Ruben it's queued.

## Cross-references

- Rule 146/148 — 235B is tier L4b batch / 405B is a teacher; neither belongs in the interactive frankenstein-llm path
- Rule 41 — after firing the async job, the next move is real work or attempt_completion, not narrating "waiting for the 235"
- Rule 95 — Cline 30s tool wall + detached-job pattern (this is the same nohup discipline applied to a slow model)
- Rule 158 — Frankenstein Doctor (this is a fleet-capability the Doctor can offer)
- idea #12184 — Kaizen Talent-Manager warm-set manager (owns keep-warm centrally)
- 405B docs: Desktop 405B_CHECKPOINT.md + 405B_WINDOW_4_teacher_explained.md (405B is a batch distillation teacher, same async-consult discipline applies, even more so — it's slower)

## Source incident

2026-06-16 — Ruben asked for a rule to consult the 235B safely in the background (nohup-style queue) so it never blocks/000s the interactive window, and asked my opinion on when it's useful + whether a clinerule can "call" a model. Answer: the rule makes ME run the consult as a detached job; useful for occasional deep second-opinions you don't need immediately; keep-warm is good and has no downside.

## Last updated

2026-06-16 — initial.