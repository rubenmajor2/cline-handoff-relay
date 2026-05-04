# Chat AI Hard-Escalation Triggers — Codified

## Why this rule exists

On 2026-04-26 conv #214 on `houstonemt.com`, Hamza Holmes asked the AI for help getting onto a Fast Track section by phone. After 13 minutes of useful answers, the conversation devolved into the AI emitting the same canned line **9 times in a row**:

> "Got it, I'll get this to the right person and circle back with you here."

Hamza explicitly said:
- "Are you a bot" (msg 539)
- "Can someone call me so I can get this sorted" (msg 529)
- "What number can I call you at" (msg 540)
- "you keep asking the same and giving me different answers" (msg 532)
- "this is really not efficient" (msg 530)
- "are you not interested in helping me?" (msg 550)

The AI never escalated. A human (Summer) had to take over manually 40 minutes later. The post-mortem produced idea #796: "Chat AI must escalate to live agent after 2 canned-handoff replies OR when visitor asks for a call."

I (Cline) added that rule to `.clinerules` once before, but the canned-loop kept happening because it was **only a prompt-level rule** — the AI was free to ignore it, and the actual escalation infrastructure (`widget_real_handoff()`) only fired when the model called the `transfer_to_human` tool. The model wasn't calling the tool. So the rule was effectively a wish, not enforcement.

This rule documents the **deterministic, code-level fix** so it doesn't regress.

## What is enforced (server-side, not prompt-level)

`/var/www/emtskills/lib/widget_force_handoff.php` exists and is required by `/var/www/emtskills/api/chat_widget_api.php` on every chat request. Before the AI is called, AND after the AI replies, the conversation is scanned for four hard signals:

1. **`call_me`** — visitor asks to be called or asks for a phone number, or asks to talk to a human/real-person/agent. Patterns include "can someone call me", "call me back", "what number can I call", "I want to talk to a real person", "talk to someone".
2. **`are_you_bot`** — visitor asks "are you a bot / robot / AI / automated", or asks "are you human / real person / agent", or "is this a bot", or "am I talking to a bot".
3. **`canned_loop`** — the AI emitted the canned-handoff fingerprint (`circle back with you here`, `will get an answer back to you here`, `just flagged this for a team member`) **2 or more times** in this conversation.
4. **`frustration_streak`** — 2+ frustration markers in the last 6 visitor messages: "not efficient", "you keep asking", "different answers", "this is frustrating", "are you not interested", "still waiting", "I give up", "this is ridiculous", etc.

When ANY of these fire:
- The AI call is skipped (pre-AI gate) OR the AI's canned reply is replaced (post-AI gate).
- A trigger-specific visitor-facing message is sent (NOT the canned template — different surface so the visitor sees something changed).
- `widget_real_handoff()` is called: flips `agent_takeover=1`, inserts a `chat_portal_transfers` audit row, fires an `orchestrator_event_log` row at severity `high`, lights up the in-app notification bell for online CS + Vicky (or all of them if nobody's online), and pings Discord `#system-issues`. **No SMS, no iMessage** — that part of the existing handoff infrastructure was already correctly sandboxed.
- A `chat_force_handoff` audit row is appended to `orchestrator_event_log` for visibility.

## The self-heal layer

`/var/www/emtskills/cron/cron_chat_force_handoff_watchdog.php` runs every 10 min via www-data crontab. It scans every active site's messages table for the last 30 min for conversations where:
- `≥2` canned-handoff fingerprints were emitted, AND
- No `widget_real_handoff` and no `chat_force_handoff` event was logged for that conversation in the same window.

That's a regression of this rule. When found:
1. The watchdog **fires `widget_real_handoff()` itself** — self-heal.
2. It writes an `orchestrator_event_log` row with `event_type='chat_force_handoff_regression'` and severity `high`. RUBEN's standard event-triage cron picks these up and surfaces them as ideas/decisions for review (the same path it uses for any other `severity=high` event).

So if a new way to confuse the AI shows up in production, RUBEN sees it within 10 min and Ruben gets it on his Q card / decision queue — not "Cline manually adds another fingerprint to the list 6 weeks later because Ruben re-noticed it."

## Where this lives

| Layer | Path | What it does |
|---|---|---|
| Library | `/var/www/emtskills/lib/widget_force_handoff.php` | The trigger detector + handoff fire. Idempotent. |
| Wire-in | `/var/www/emtskills/api/chat_widget_api.php` | Pre-AI gate (line ~234) + post-AI canned check (line ~290). |
| Self-heal cron | `/var/www/emtskills/cron/cron_chat_force_handoff_watchdog.php` | Regression detector + auto-fire of widget_real_handoff. */10 * * * * www-data. |
| Visible audit | `orchestrator_event_log` event types `chat_force_handoff` (normal trigger), `chat_force_handoff_regression` (the watchdog caught a miss), `cron_heartbeat` source `cron_chat_force_handoff_watchdog`. |
| Underlying handoff | `/var/www/emtskills/lib/widget_human_handoff.php` (`widget_real_handoff`). Unchanged by this rule. |

## What I (Cline) MUST do going forward

1. **Never assume a prompt-level rule is enforcement.** If a behavior matters for product safety (chat AI doesn't loop the visitor, doesn't pretend to be human, doesn't ignore "call me"), the enforcement is in PHP code, not in the system prompt. The system prompt is advisory at best.
2. **When Ruben says "I keep having to ask for this," that's a signal to look for the missing code-level enforcement.** Re-stating the .clinerules rule is not the answer. Find where the failure path actually lives in `chat_widget_api.php` / `lib/emsu_ai_brain.php` / wherever, and add the deterministic gate there.
3. **Any new chat AI escalation pattern Ruben asks for goes BOTH places** — into the prompt AND into `lib/widget_force_handoff.php`'s fingerprint set. Do not add to one without the other.
4. **Self-heal layer is mandatory for new chat AI escalation rules.** A `cron_*_watchdog.php` cron writing to `orchestrator_event_log` with severity `high` and a `[REGRESSION]` subject prefix is the standard pattern.
5. **When updating triggers in `lib/widget_force_handoff.php`**, also update the canned-fingerprint set in `cron_chat_force_handoff_watchdog.php` so the watchdog's regression detector stays consistent with the live triggers. They can drift; don't let them.

## Specifically: The triggers that are now enforced (changes ≥ codified here)

These are the exact patterns enforced by `widget_force_handoff_check()`. To extend them, edit `/var/www/emtskills/lib/widget_force_handoff.php` and re-run the watchdog smoke test. **Do not** rely on the system prompt to enforce these — the AI is allowed to ignore the prompt; it cannot ignore PHP that runs before its reply ships.

```
T1 call_me              — "can someone call me", "call me back", "what number can I call",
                          "I want to talk to a real person", "talk to a human / real agent"
T2 are_you_bot          — "are you a bot / robot / AI / automated / chatbot",
                          "are you human / real person", "is this a bot",
                          "am I talking to a bot"
T3 canned_loop          — ≥2 occurrences of "circle back with you here",
                          "will get an answer back to you here",
                          "just flagged this for a team member" by the AI
T4 frustration_streak   — ≥2 occurrences in last 6 visitor messages of
                          "not efficient" / "you keep asking" / "different answers" /
                          "this is frustrating" / "are you not interested" / "still waiting" /
                          "I give up" / "this is ridiculous" / "this is unacceptable"
```

## Last updated

2026-04-27 21:48 PT — initial rule, deployed alongside the code in this same task. Logged in cline_task_ledger as `#hamza-houston-chat-postmortem` follow-through.

## Future-proof reminder for myself

Ruben's exact words on 2026-04-27 when he kicked this task: **"This actually needs to be rooted out and resolved, then added to self-heal / ruben resolving such self-heal if that breaks. I had already added this to cline rules, but i keep haveing to ask."**

The pattern that was breaking it was: "rule lives in the prompt → AI ignores it → I (Cline) just re-confirm the .clinerules → next chat the same thing happens." Rooted-out means the gate runs in code BEFORE the AI has a chance to ignore it, AND there's a regression watchdog that auto-fires self-heal AND auto-files an event so RUBEN can adapt the trigger set without Ruben having to ask again.

If a future task introduces a new "AI shouldn't do X" rule for the chat widget, the durable answer is:
1. Add it to `widget_force_handoff_check()` as a new trigger function.
2. Add the matching fingerprint set to `cron_chat_force_handoff_watchdog.php`.
3. Update this file with the new trigger row in the table above.
4. Smoke-test the watchdog (`sudo -u www-data php cron_chat_force_handoff_watchdog.php`) before considering it done.

That's the loop that ends the "I keep having to ask" cycle.
