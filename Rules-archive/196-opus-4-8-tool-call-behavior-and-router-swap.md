# 121 — Opus 4.8 under-calls tools by design. The router swaps it down on recovery, not a prose rule.

Archive rule. Workspace-scoped. Source: 2026-05-30 Ruben directive — "Opus 4.8 is still somewhat unstable, research how to stop the YOLOs with it."

## The finding (why this is a model issue, not a discipline issue)

Anthropic's own Opus 4.8 documentation states the model "favors reasoning over tool calls" and makes "fewer tool calls by default" than 4.7. The 4.8 changelog explicitly lists "fewer cases of skipping a tool call that the task required" as a fix they attempted — meaning tool-skipping is a known 4.8 behavior class, not a user error. Local trip data agrees: in the last 14 days, 49% of YOLO trips were pure no-tool-use prose with NO preceding tool error. That is the model choosing to answer in prose on a turn that needed a tool.

This matters because rules 41 and 99 already cover prose-discipline exhaustively. Writing a third prose rule does not change a model's default tool-call propensity. The lever that does is at the routing layer.

## What the router actually does (the core fix, per rule 92)

`/etc/litellm/router_hook.py` carries a YOLO recovery swap: when the inbound message stack contains Cline's `[ERROR] You did not use a tool` recovery prompt AND the picked model is `claude-opus-4-8`, the router rewrites that single call to `claude-opus-4-7`. 4-7 trips the prose trap roughly 2.8x less often (idea #8365). The swap is per-call, reversible, and only touches the recovery turn — Cline's own picker stays on 4-8.

Bug found + fixed 2026-05-30: that swap originally lived ONLY in the `if original != "emsu-router-auto"` explicit-pick branch. All real Cline/agent traffic arrives as `emsu-router-auto`, so the swap fired exactly once ever — dead code for the traffic that actually YOLOs. The fix mirrored the swap onto the auto path (search `yolo_recovery_swap_auto` in router_hook.py).

## The `effort` param is NOT accepted on the raw Messages API (canary-verified 2026-05-30)

Anthropic's marketing describes an `effort` knob for Opus 4.8, but that is a Claude Code / CLI surface concept. A live canary against our passthrough (`/anthropic/v1/messages`, model `claude-opus-4-8`) returned HTTP 400: `"effort: Extra inputs are not permitted"`. A top-level `effort` param would 400 every Cline call — do NOT inject it. Caught by canary before deploy (rule 29 blast-radius gate); a blind inject would have broken all ~1281 daily opus-4-8 calls. The only accepted knob on the raw API is `thinking` (canary HTTP 200), which the router already manages via `_strip_unsupported_thinking`. And the audit shows the auto path already re-routes the short no-tool-use recovery turn to claude-sonnet (tool-reliable) 432/433 times — recovery is already healthy, no further param change needed unless first-turn 4-8 prose trips climb.

## What NOT to do

- Do NOT write another prose-discipline cline rule. Rules 41 + 99 own that. The lint G1 gate will block a near-duplicate anyway.
- Do NOT lower `maxConsecutiveMistakes` thinking it helps. The authoritative value is 99 (`cline_settings.json`); if the live VS Code state DB drifts below it, raise it back. A low threshold makes 4-8's natural under-calling fatal faster.
- Do NOT inject a top-level `effort` param — it is rejected (HTTP 400) on the Messages API. If a proactive knob is ever needed it is `thinking`, already managed by the router.

## Self-check when "Opus is YOLOing again" comes up

1. Is the live `maxConsecutiveMistakes` still 99? Check the VS Code state.vscdb key; it drifts.
2. Is `yolo_recovery_swap_auto` present in router_hook.py and is the container running the bind-mounted host file? `grep yolo_recovery_swap_auto /etc/litellm/router_hook.py`.
3. Are first-turn 4-8 prose trips still climbing in yolo_trips.sqlite? The auto path already heals recovery turns to Sonnet (432/433), so confirm the issue is first-turn before touching the router. Do NOT inject `effort` (400s); `thinking` is the only accepted knob and is already managed.

## Cross-references

- .clinerules/41 — post-deploy/no-tool-use prose trap (the symptom rules)
- .clinerules/99 — auto-generated YOLO playbook (data-driven, do not hand-edit)
- .clinerules/92 — work at the core, not bandaids (this rule IS the core fix)
- .clinerules/118 — litellm restart via safe wrapper (used to ship the router patch)
- .clinerules/29 — agents act on confidence tier (router swap is a green-tier reversible action)

## Last updated

2026-05-30 — initial. Source: Ruben asked to research Opus 4.8 instability + stop the YOLOs. Found the recovery swap was dead for emsu-router-auto traffic, mirrored it onto the auto path. Canary-verified that `effort` is rejected (400) on the Messages API and that the auto path already heals recovery turns to Sonnet 432/433 — so the system was already largely self-healing; the swap is correctly-gated insurance.
