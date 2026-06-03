# 130 — CS-facing agent name map: which file is LIVE, which are dead ghosts, and where to edit

Source: 2026-06-02 Ruben — "What are the agent names so I know I'm not editing the wrong one? I thought you removed Live Chat and it was just sitting there being updated the whole time." Two 5-subagent traces confirmed the live paths. This rule kills the confusion permanently.

## The 5 CS-facing agents — the ONE live file each

| Agent (say this name) | LIVE entry point (real traffic) | Reply composer | Prompt source | Tools source |
|---|---|---|---|---|
| **Email AI** | cron/cron_email_responder.php (every 5 min) | lib/EmailAIResponder.php (`new EmailAIResponder()`) | own base + CanonicalAgentPolicy clauses (see bypass note) | CanonicalToolRegistry::toolsFor('email') |
| **Chat AI** (in-house widget) | api/chat_widget_api.php → in-process require lib/emsu_ai_brain.php → runEmsuAiBrain() → uses api/livechat/webhook.php's buildSystemPrompt/getToolDefinitions/executeTool/sanitizeResponse | lib/emsu_ai_brain.php + webhook.php helpers | webhook.php buildSystemPrompt + CanonicalAgentPolicy::block('chat') | webhook.php getToolDefinitions = CanonicalToolRegistry::toolsFor('chat') |
| **SMS AI** | cron/cron_sms_auto_reply.php | lib/SMSAIResponder.php | CanonicalAgentPolicy::block('sms') | CanonicalToolRegistry::toolsFor('sms') |
| **Voice AI** (Vapi) | Vapi platform → api/vapi* / dispatch | Vapi assistant + lib/ai_ticket_agent.php follow-up calls | DIVERGENT: own prompt + possibly Vapi-dashboard prompt our code may not reach | hand-maintained $voiceTools (drifts) / vapiSchemas |
| **Ticket AI** | lib/ai_ticket_agent.php | ai_ticket_agent.php | CanonicalAgentPolicy::block('ticket') | partial |

## DEAD GHOSTS — never edit these expecting live effect

- **The "LiveChat" confusion, resolved:** api/livechat/webhook.php has a `LIVECHAT_KILLSWITCH` that DROPS real LiveChat.com vendor webhook traffic (that vendor IS dead, nuked 2026-04-21). BUT the file is STILL ALIVE because lib/emsu_ai_brain.php require's it for its helper functions (buildSystemPrompt, getToolDefinitions, executeTool, sanitizeResponse). So: the LiveChat *vendor integration* is dead; the *file* is the live in-house chat brain. Editing webhook.php's buildSystemPrompt/getToolDefinitions DOES affect live chat. The vendor-webhook handler code at the top (BOT_ID, sendBotMessage, transferToAgent) is dead and could be deleted, but the helper functions below are load-bearing. Don't delete the file.
- **Any lib/EmailAIResponder.php.bak-*, *.tmp_rg_patch, ai_email_agent.php** — not on the live email path.
- **chat_widget_api.php callAI() direct-Anthropic fallback stanza** — only runs when the brain bridge returns null; most chat guards we added there DO NOT run on normal traffic (this is the two-headed-hydra; idea #9222 collapses it).

## Where to edit by intent (the cheat sheet)

- **"Update ALL CS-facing agents to do/stop X"** (behavior/policy) → edit **lib/CanonicalAgentPolicy.php** `block()` (+ add a banned phrase to **lib/AIReasoningLeakScanner.php** patterns() for a hard post-send block). Consumed by chat, sms, ticket, voice-followup. ⚠️ Email currently appends the clauses individually (bypass) — verify the change lands there too until email is migrated to call block() directly.
- **"Give all agents a new tool"** → edit **lib/CanonicalToolRegistry.php** (schemas/handlerMap). All channels inherit via toolsFor(channel).
- **"Block a phrase everywhere"** → **lib/AIReasoningLeakScanner.php** patterns() — runs pre-send on email/sms/chat/ticket.
- **"Change just ONE agent"** → that agent's live file above. Chat-only behavior lives in webhook.php buildSystemPrompt / chat_widget_api widgetGuardrailPrompt.

## The 3 single-source-of-truth files (make "update all agents" real)

1. lib/CanonicalAgentPolicy.php — shared prompt policy
2. lib/CanonicalToolRegistry.php — shared tools
3. lib/AIReasoningLeakScanner.php — shared pre-send guard

Known bypasses to fix (idea #9222 + migration): Email appends policy clauses individually instead of calling block(); Voice keeps its own prompt/tools. Until those migrate, "update all agents" needs a check that email + voice picked up the change.

## Agent-core files are hand-owned (do not let the implementer touch them)

cron_ruben_implement.php has AGENT_CORE_HARD_DENYLIST blocking the auto-implementer from these 13: api/chat_widget_api.php, api/livechat/webhook.php, lib/emsu_ai_brain.php, AIReasoningLeakScanner.php, widget_force_handoff.php, widget_human_handoff.php, chat_widget_tools.php, CanonicalToolRegistry.php, CanonicalAgentPolicy.php, EmailAIResponder.php, SMSAIResponder.php, ai_ticket_agent.php, ai_response_guard.php. Edits go via emsu-safe-deploy by a human/Cline only.

## Last updated
2026-06-02 — initial. Source: Ruben confusion about agent names + the LiveChat ghost. Idea #9222 (collapse chat to one brain). Cross-refs .clinerules/92.
