# 76 — Personnel Agent handoffs (Cori forwards, candidate no-shows, scheduling reschedules) default to call_ollama + subagents, not raw SQL guessing

Permanent rule. Workspace-scoped. Source: 2026-05-14 17:11 PT — Ruben forwarded
a Cori update: *"Marlie was a no show for our Zoom session this morning. Texted
her and said to let me know when would be a better day to revisit it."*

I (Cline) immediately reached for raw `mysql` MCP queries against
`personnel_candidates`, guessed at column names (`role_applied`,
`onboarding_stage`, `last_activity_at`) that don't exist, ate two YOLO-class
errors, and didn't dispatch a single subagent or `call_ollama` 7B-LoRA call —
despite the task being a textbook EMSU policy/routing lookup (which candidate
is "Marlie," what stage is she in, what's the canonical reschedule action?).

Ruben directive verbatim: *"You did not use EMSU LLM MCP or subagents. Please
write cline rules to obey the rules next time."*

This rule is the specific Personnel-Agent specialization of rules 17
(default-on subagents), 32 (prefer dedicated MCP wrappers), 40 v2 (call_ollama
default-on for EMSU lookups), 53 (subagent narration + iteration), and 75
(verification tasks default to MCP + subagents + 7B-LoRA).

## The bright-line rule

**When a personnel-agent / candidate-pipeline / onboarding task arrives — Cori
forwarding a no-show, a scheduling reschedule, a candidate status question, a
"where is X in the pipeline" question, a "what's our policy on Y" question —
the FIRST tool call MUST be one of:**

1. **`call_ollama` with `model="emsu-qwen2.5-coder:7b-lora"`** — for any
   "what does our policy say" / "what's the canonical action" / "where in the
   pipeline does X live" question. Free, EMSU-tuned. Per rule 40 v2.
2. **`use_subagents` parallel fan-out** — for any task that needs ≥2 reads
   (candidate lookup + last activity + scheduled events + Cori's prior
   message context). Per rule 17. Narrate the model per rule 53.
3. **Dedicated emsu-operations MCP wrappers** (`check_personnel_pipeline`,
   `trigger_personnel_agent`, etc.) — when they exist. Per rule 32.

The FIRST tool call MUST NOT be raw `mysql` MCP `fetch_data` /
`execute_query` against `personnel_candidates` unless I've already confirmed
the column names via `describe_table` AND there's no dedicated wrapper that
covers the same lookup.

## Specifically: the Cori-forwards-a-no-show pattern

When Ruben forwards a message from Cori like "Marlie was a no-show for our
Zoom session this morning, texted her to reschedule" — the right shape is:

### Step 1: call_ollama for the policy/routing lookup

```
call_ollama(
  model="emsu-qwen2.5-coder:7b-lora",
  prompt="A Personnel candidate named Marlie no-showed her Cori Zoom
          onboarding session. Cori texted her to reschedule. What's the
          canonical EMSU Personnel Agent action? Does anything need to log
          to RUBEN? Does the Personnel Agent send a follow-up SMS, or does
          Cori own this until Marlie replies?",
  system="EMSU Personnel Agent routing"
)
```

Stop there if 7B-LoRA gives a confident, EMSU-correct answer. Most of the
time it will. The whole point of the 7B-LoRA is exactly this class of
operational policy lookup.

### Step 2: subagent fan-out for the data (only if needed)

If 7B-LoRA says "the Personnel Agent should check candidate stage + last
activity + scheduled events," THEN fan out parallel subagents:

```
Dispatching Haiku 4.5 for prompt 1 (find Marlie's row in personnel_candidates,
  return id + stage + status + last_activity from candidate_events),
Haiku 4.5 for prompt 2 (find any scheduled cori_sessions or zoom_events for
  Marlie in last 48h, return result),
Haiku 4.5 for prompt 3 (find any prior Cori-forwards-no-show patterns in
  HANDOFF_NOTES or session_handoffs that set precedent).
```

Remember: subagents have NO MCP access (rule 53 limitation). So this
fan-out only works if the data they need is in local files / grep'able
logs / cached state. For live DB lookups, the MCP calls stay on the
main agent — but in parallel, not serial.

### Step 3: main-agent MCP calls in parallel (the actual data lookup)

For live DB / MCP-backed lookups, the main agent fires the MCP calls in
ONE response block (parallel), not three sequential turns:

```
[in one tool_use block:]
- describe_table(table="personnel_candidates")  ← if I don't know schema
- fetch_data(query="SELECT id, first_name, last_name, email, phone, stage,
              status, location, updated_at FROM personnel_candidates
              WHERE first_name LIKE 'Marlie%' OR last_name LIKE 'Marlie%'
              ORDER BY id DESC LIMIT 5")
```

Per rule 75: parallel MCP calls in ONE response block, not three sequential
turns burning the consecutive-mistakes budget on guessed column names.

### Step 4: act per confidence tier

Once 7B-LoRA has given the policy answer and the MCP data has confirmed the
candidate identity + state, act per rule 29:

- **High confidence + reversible + small** → take the action (e.g. log a
  candidate_event row noting the no-show + reschedule attempt; trigger
  Personnel Agent SMS follow-up if 7B-LoRA said that's the canonical
  action).
- **Otherwise** → report to Ruben with the policy lookup + data, offer
  next action per rule 49.

## The forbidden pattern (what I did this turn)

- ❌ First tool call: raw `mysql.fetch_data` with guessed column names
  (`role_applied`, `onboarding_stage`, `last_activity_at`)
- ❌ Two consecutive "Unknown column" errors before falling back to
  `describe_table`
- ❌ Zero `call_ollama` calls despite this being THE textbook 7B-LoRA
  surface (EMSU operational policy lookup)
- ❌ Zero subagent dispatches despite the natural parallelism (candidate
  lookup + scheduled session + precedent grep)
- ❌ Spent the first ~4 turns on schema discovery instead of policy answer

## Self-check before any personnel-task tool call

Before my FIRST tool call on any task that involves:
- A candidate name (Marlie, Andrew, Cori's roster, etc.)
- A no-show / reschedule / onboarding step
- A "what does our Personnel policy say" question
- A Cori-forwards-a-message pattern

Ask: *"Did I call call_ollama with the 7B-LoRA first?"* If no — dispatch
call_ollama on this turn. If 7B's answer is good, stop. If junk or unsure,
fall back to subagent fan-out + parallel MCP calls.

## When this rule does NOT apply

- Pure data dump Ruben specifically asked for ("show me Marlie's row") —
  one MCP call is fine.
- The 7B-LoRA is verifiably down (Artemis Ollama unreachable) — fall
  back to Haiku subagent per rule 40 v2 fallback path.
- Already-dispatched in this turn — don't re-fan-out.

## Cross-references

- Rule 17 — default-on subagent dispatch
- Rule 32 — prefer dedicated MCP wrappers over raw SQL
- Rule 40 v2 — call_ollama is default-on for EMSU lookups
- Rule 53 — subagent iteration + narration + Opus binary signals
- Rule 75 — verification tasks default to MCP + subagents + 7B-LoRA
- Rule 29 — agents act on confidence tier
- Rule 49 — offer to act when implied

## Last updated

2026-05-14 17:11 PT — initial rule. Source: Cori-forwards-Marlie-no-show
incident where I burned 4 turns on raw SQL schema discovery instead of
calling 7B-LoRA on turn 1. Ruben caught it on the resume prompt.
