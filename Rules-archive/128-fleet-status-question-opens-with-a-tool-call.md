# 128 — Fleet/ops status & opinion questions OPEN with a tool call, never with prose

Permanent rule. Workspace-scoped. Companion to .clinerules/41 (post-deploy prose trap), .clinerules/99 (no-tool-use is the #1 YOLO class), .clinerules/00 (subagent/first-tool-call tripwire), .clinerules/117 (fleet inventory lookup before host probe).

## The bright-line rule

**When Ruben opens a Cline window with a Fleet Agent / fleet / LLM-routing / RUBEN-executor / ops STATUS or OPINION question, the FIRST assistant turn MUST contain a tool_use block.** Not a prose answer. Not "let me check." Not a paragraph of what you think is going on. A tool call.

These questions FEEL like conversation, so the model answers conversationally with prose — then gets `[ERROR] You did not use a tool`, re-narrates, and trips YOLO. This is the exact shape of 100% of the logged "consoling the Fleet Agent" trips.

## Why this rule exists (the data)

Scan of `~/Documents/Cline/yolo_learner/yolo_trips.sqlite` on 2026-05-28: every single trip whose `last_user_msg_start` mentions fleet/console/load-balancing is `cat_1 = no-tool-use: model typed prose instead of calling a tool`, followed by one or two more `no-tool-use` strikes. None are timeouts, API overloads, or tool failures. The model knew the answer-shape (status report) but typed it as prose instead of gathering it via a tool first.

The live `maxConsecutiveMistakes` is 10 (verified in state.vscdb), NOT 3 — the "(3)" in the YOLO banner is Cline's default message string, not the active limit. So raising the threshold is NOT the fix and was explicitly ruled out. The fix is: stop emitting the prose-only first turn.

### Canonical trip openers (all real, all tripped)

- "How is this going? Can you make sure that we're pushing ahead? How is the fleet agent doing?"
- "I think that Fleet Agent needs to do a better job at load balancing. Are we really heavy on..."
- "Give a status on Fleet management progress, the 70B, MacMini LLMs, the LoRA..."
- "need to see workload distribution percentages and capacity of the machine vs..."
- "Ruben Exector running slow. I know it can do much more. Can you lift the gates a bit..."

Every one of these is answerable ONLY by reading live state. The correct first move is a tool, every time.

## The first-tool map for fleet/ops questions

| Ruben asks about... | First tool call (do this, don't narrate) |
|---|---|
| "how is the fleet doing / load balancing / capacity / workload %" | `fleet_now` (then `fleet_inventory` if hosts unclear) |
| "fleet hosts / which machine / 70B / MacMini / Artemis / B200" | `fleet_inventory` |
| "LLM spend / cost / which model is serving / routing" | `fleet_now` (spend-by-model + spend-by-surface are in it) |
| "RUBEN executor slow / gates / lift the gates / running ahead" | `orchestrator_status` (then `get_config` for gate values) |
| "is RUBEN doing X / decisions / ideas / events" | `check_ruben_state` or `orchestrator_status` |
| "errors / is anything broken / watchdog" | `error_watchdog` |
| "LoRA / training pods / RunPod" | `fleet_now` (active pods + runpod events are in it) |

If you genuinely don't know which tool, the first call is still a tool — `fleet_now` or `fleet_inventory` — not a sentence.

## What a correct first turn looks like

One short framing sentence is OK ONLY if the tool block is in the SAME turn:

> `Pulling the live fleet snapshot.` + `fleet_now` tool block

Or just the tool block alone. Both are fine. What is NOT fine:

- ❌ "Let me take a look at how the fleet is doing." (no tool) → trip
- ❌ "Right now the fleet is mostly running on Anthropic because..." (prose answer from memory, no tool) → trip
- ❌ "Good question — here's my read on the load balancing:" (opinion prose, no tool) → trip
- ❌ A multi-paragraph assessment of fleet health with no tool block anywhere in the turn → trip

## The opinion-question trap specifically

"I think the Fleet Agent needs to do a better job at load balancing" is an OPINION prompt. The reflex is to agree/disagree in prose. Don't. Ruben's opinion is a hypothesis to VERIFY against live data. First turn = the tool that fetches the data that confirms or refutes his read. Then you answer with numbers, not vibes (per .clinerules/112-executor-eta — query the data, not the vibe).

## Self-check before the first turn of any fleet/ops window

1. *Does Ruben's message ask about fleet / routing / executor / LLM cost / host capacity / "how is X doing"?* → first turn MUST be a tool call from the map above.
2. *Am I about to type an assessment, a "let me check," or an opinion as prose with no tool block in this turn?* → STOP. Emit the tool instead.
3. *Did I get `[ERROR] You did not use a tool`?* → the next turn is a tool or `attempt_completion`, never more prose (per .clinerules/41 free-strike recovery).

## Cross-references

- .clinerules/41 — the colon-trailed / "Now I'll X" prose trap (this rule is the fleet-question entry-point specialization)
- .clinerules/99 — no-tool-use is 224% over-represented; the #1 YOLO class
- .clinerules/117 — lookup fleet inventory before host probe
- .clinerules/112 — query the data, not the vibe
- .clinerules/00 — first-tool-call tripwire (every turn with a tool opens with the tool)

## Source incident

2026-05-28 — Ruben: *"WE have a lot of Yolos occurring when I console Fleet Agent."* Investigation of yolo_trips.sqlite showed every fleet-console trip is a `no-tool-use` prose-first opener triggered by a conversational status/opinion question. maxConsecutiveMistakes confirmed at 10 (not the threshold), so the fix is the prose-first first-turn habit, not the limit. This rule closes that entry pattern.

## Last updated

2026-05-28 — initial.
