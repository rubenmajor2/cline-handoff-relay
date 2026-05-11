# 44 — When Anthropic 402s/5xxs mid-task, switch Cline to OpenAI gpt-5.5 instead of waiting

Permanent rule. Workspace-scoped. Source: 2026-05-11 ~12:00 PT Anthropic credit
balance went to zero mid-day. Three RubenExecutor chains died with
`anthropic_credit_exhausted` and any active Cline tasks would have hit the same
402 (Cline 3.82 has no built-in cross-provider failover). Ruben directive
verbatim 2026-05-11 12:23 PT: *"the same exact idea here in cline. This way our
tasks don't get interrupted with API errors so what you're gonna do is make a
cline rule that automatically moves the LLM over to chatgpt OpenAI 5.5 if
anthropic goes down."*

Verified 2026-05-11 against `https://api.openai.com/v1/models`: gpt-5.5
(released 2026-04-23) and gpt-5.5-pro are both live. Use **gpt-5.5** as the
primary failover target. gpt-5.4 is the secondary if gpt-5.5 is unavailable.

Server-side RUBEN executor cascade (orchestrator_config.ruben_fallback_chain):
1. openai/gpt-5.5  (primary fallback when Anthropic is down)
2. openai/gpt-5.4  (secondary if gpt-5.5 also down)
3. ollama/qwen2.5-coder:14b  (tertiary — local Artemis LLM, no token cost,
   text-only)
4. openrouter/auto  (final tier, routes via Anthropic Sonnet through OpenRouter
   in case OpenAI is also down but their OpenRouter pipe still works)

For Cline (the editor) there's no auto-failover — use the manual switch below.

## The bright-line rule

**When a Cline tool call returns an Anthropic error that matches the outage
fingerprint, immediately switch the Cline API provider to OpenAI gpt-5.5 and
reload the window. Don't wait it out, don't burn the consecutive-mistakes
budget on retries.**

## Outage fingerprint (any one of these = switch providers)

- `Your credit balance is too low to access the Anthropic API` (402, credit
  exhausted — usually a top-up gap on Ruben's billing)
- `overloaded_error` / `"type":"overloaded"` (529 sustained, not a single
  spike — see rule 16 for the single-spike retry path)
- HTTP `503`/`502` from `api.anthropic.com` sustained >2 attempts
- `Operation timed out after 90000 milliseconds` on `api.anthropic.com` AND
  a separate sanity check via `curl https://status.anthropic.com` shows red

If the error is just a single transient 529/overloaded, rule 16 / rule 99
already cover it — wait 30-60s, retry once, idle if it fails again. THIS rule
fires when the failure is sustained or 402-class.

## The actual switchover procedure (manual, ~30 seconds)

Cline 3.82 does not have built-in failover. The switch is a settings change:

1. Cmd+Shift+P → "Cline: Settings" (or click the gear icon in the Cline panel)
2. Under "API Provider", switch from `Anthropic` to `OpenAI Native`
3. API Key: use the one in `/var/www/emtskills/config/config.local.php`
   constant `OPENAI_API_KEY` (Ruben's prod key — same one EMSU uses for
   gpt-5.4 calls server-side). On the Mac it's also at
   `~/.config/openai/api_key` if Ruben has it there.
4. Model ID: **`gpt-5.5`** (or `gpt-5.4` as a fallback; both verified live
   against /v1/models on 2026-05-11)
5. Cmd+Shift+P → "Developer: Reload Window"
6. Resume the task with: `pick up task #<task_id> from where we left off`

Total wall-clock: ~30 sec. Recovers without losing the task on disk.

## When Anthropic recovers, switch back

OpenAI gpt-5.5 is fine for tool-use but Sonnet 4.6 / Opus 4.7 are still better
at the .clinerules-heavy multi-step planning EMSU work requires. When Ruben
confirms Anthropic billing is back (or `curl
https://api.anthropic.com/v1/messages -H "x-api-key: $key" -d '{...minimal...}'`
returns a 200), flip the Cline API provider back to Anthropic and reload.

## What this rule does NOT do

- Does not auto-switch. Cline can't change its own API provider mid-task
  without operator action. That's a Cline-team feature request, not something
  we can ship from a clinerules file.
- Does not cover the server-side RUBEN executor — that has its own failover
  cascade in `lib/RubenExecutor.php::maybeFailover` (fixed 2026-05-11 to use
  gpt-5.5 with correct `max_completion_tokens` param). See HANDOFF_NOTES.md
  2026-05-11 12:26 PT entry.
- Does not apply to anything except mid-task Anthropic-API errors. Don't
  switch providers because of a model-quality complaint or a single 429.

## Self-check during any task

If I'm in a Cline task and I see:

- Two consecutive Anthropic 402/credit_balance errors → STOP, surface to
  Ruben with this rule's name, suggest the switch.
- Two consecutive sustained-overload 529s → same.
- An Anthropic timeout > 90s where `curl status.anthropic.com` confirms an
  outage → same.

Do NOT retry the same Anthropic call a 3rd time hoping it'll succeed. That
trips YOLO per rule 99's "two API overloaded errors in a row = stop and idle"
clause. The switch IS the recovery action.

## Cross-references

- Rule 16 — `maxConsecutiveMistakes=10` (gives breathing room but doesn't
  fix sustained outages)
- Rule 22 — executor self-supervision loops (server-side version of this)
- Rule 99 — generic no-tool-use playbook including
  `api: overloaded/rate-limit` and `api: credit exhausted`
- HANDOFF_NOTES.md 2026-05-11 12:26 PT — server-side RUBEN failover fix
- orchestrator_ideas #3057 — wire LlmProviderHealth retry path properly
  (P1, approved)

## Last updated

2026-05-11 — initial rule. Source: Anthropic credit-balance outage at 12:02
PT killed 3 RubenExecutor chains and would have killed any active Cline
tasks. Ruben asked for this rule by name in the same chat.
