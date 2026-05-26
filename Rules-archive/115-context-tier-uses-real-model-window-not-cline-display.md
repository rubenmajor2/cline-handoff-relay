# 115 — Context-tier decisions use REAL model window, not Cline's UI percentage

Permanent rule. Source: 2026-05-25 Ruben directive verbatim during LiteLLM Phase 3 wrap-up:

> *"unless your context is actually over 65% do not ask or try to slow down or modify your working. Can we do a rule like this? Do you have the capability to see your actual context?... May need to be modified slightly however because the Lite LLM has deceiving context so maybe then we look at counting actual token usage instead."*

Companion to .clinerules/91 (pickup-prompt mandate) and the budget-watchdog tier mandate in 91 (GREEN/YELLOW/RED/IMMINENT).

## The bright-line rule

**Pickup-prompt / "stalled, paste in fresh window" / "let me hand off" / "slow down" / "scope-cut" behavior is GATED on actual token usage as a fraction of the REAL model context window — NOT on Cline's "X / 200K" UI display.**

The UI display is hard-coded to ~200K (legacy Claude 3.5 era). When the underlying model is bigger (Sonnet-4-6 = 1M, Opus-4 = 200K, Haiku-4-5 = 200K), the displayed percentage is wildly off for the bigger models.

### Required computation per turn

1. Read `Context Window Usage: X / Y tokens used` from `environment_details`. X is the real number you've consumed. Y is Cline's display ceiling.
2. Identify the ACTUAL model serving this turn (check the LiteLLM routing for emsu-router-auto, or whatever model Cline is on). Lookup table:
   - `claude-sonnet-4-6` → real ceiling = **1,000,000 tokens**
   - `claude-opus-4-7` / `claude-opus-4-5` → real ceiling = **200,000 tokens**
   - `claude-haiku-4-5` → real ceiling = **200,000 tokens**
   - `claude-3.5-sonnet` / older → real ceiling = **200,000 tokens**
   - Unknown / LiteLLM passthrough where model is opaque → fall back to Cline's displayed Y (be conservative)
3. **Tier = X / real_ceiling**, NOT X / Y.

### Tier table (using REAL ratio)

| Real ratio | Tier | Behavior |
|---|---|---|
| <65% | GREEN | Keep working. Do NOT suggest fresh window. Do NOT write pickup prompts. Do NOT scope-cut. Do NOT add "if you want me to continue..." hedges. |
| 65-80% | YELLOW | Before next risky/long tool call, write a durable artifact (ledger row, HANDOFF entry, or idea row). Keep working. |
| 80-90% | RED | Stop non-essential work. Write pickup-prompt-shaped HANDOFF + ledger row. Consider attempt_completion early. |
| >90% | IMMINENT | Next tool call MUST be attempt_completion. Pickup prompt is the durable artifact. |

### What this rule changes

Before: Cline reflexively wrote pickup prompts at ~80% of the 200K UI bar (=~165K tokens absolute) regardless of whether the actual model was a 1M-window model. The result was hand-offs that interrupted productive work when 840K of real headroom remained.

After: Pickup-prompt behavior keys off REAL fraction. On a 1M-window Sonnet, 165K = 16.5% = GREEN = keep working.

### Specifically forbidden when GREEN (<65% real)

- ❌ "Let me hand this off to a fresh window..."
- ❌ "Paste this pickup prompt into a fresh Cline window..."
- ❌ "I should wrap up to save context..."
- ❌ "Let me cut scope to fit in the remaining budget..."
- ❌ Any unprompted offer to "continue in another session"

If GREEN and the user asks for more work, just do the work. No hedging about context.

### Self-check before any pickup-prompt emission

Ask: 
1. *What model am I actually on right now?* (Look at the LiteLLM router config / last call log.)
2. *What's that model's real context ceiling?*
3. *What's my X (tokens used so far)?*
4. *Is X / real_ceiling ≥ 0.65?*

If no → do NOT emit pickup prompt. Keep working. The user explicitly does not want it.

### How to know which model is serving Cline

Cline itself runs via the user's configured API key, NOT the EMSU LiteLLM router. Check:
- The Cline settings panel (anthropic claude model name) is the authoritative source
- If unsure and the model is "Sonnet" or "Sonnet 4.x" → 1M ceiling
- If "Opus" or "Haiku" or unspecified → 200K ceiling, defer to displayed percentage

### Edge case: LiteLLM as Cline's backend

If a future Cline session routes through the EMSU LiteLLM router (emsu-router-auto), the model serving the turn may vary call-to-call (fallbacks, A/B routing). In that case:
- Be conservative — assume 200K ceiling unless explicitly confirmed otherwise
- Or check llm_call_log for the most recent surface=cline call to see what landed

### Cross-references

- .clinerules/91 — pickup-prompt mandate (only applies when GREEN→YELLOW transition; this rule defines when that transition fires)
- .clinerules/91 budget-watchdog mandate — keeps the GREEN/YELLOW/RED/IMMINENT vocabulary, but the THRESHOLDS now key off real ratio per this rule
- .clinerules/38 — Ruben-asks = autonomous-tier minimum (overrides this rule when user explicitly asks for hand-off)
- .clinerules/41 — post-deploy tool-not-prose

### Last updated

2026-05-25 — initial. Source: LiteLLM Phase 3 wrap-up. Cline kept offering fresh-window pickup at 165K/200K (=83% UI but 16.5% real on Sonnet-4-6). Ruben caught it: "150K out of 1M?"