# 135 — "Student Lifecycle Service" (SLS): the canonical name for the student lifecycle + payment brain

Source: 2026-06-02 Ruben directive. He asked what to call the consolidated student-lifecycle-including-payment capability, since "Student Lifecycle MCP" is wrong (it is not an MCP server). He correctly doubted that merely saying a name would make every agent + Cline recognize it forever. This rule is the durable Cline-side definition so any future Cline window resolves the name on every task.

## The canonical name + one-line definition

**SLS = Student Lifecycle Service.** One PHP brain that answers every student lifecycle + payment question. Agents reach it through their tool registry; Cline reaches it through the emsu-operations MCP. Same brain, two doors. **It is NOT a standalone MCP server.**

If anyone (Ruben, a handoff, a ticket) says "SLS," "Student Lifecycle Service," "the lifecycle service," or "Student Lifecycle MCP," they all mean this one thing.

## What it actually is (the parts)

| Layer | Concrete thing | Who reads it |
|---|---|---|
| The brain | `lib/StudentLifecycleState.php` (lifecycle gates, idea #9086) + `lib/StudentLifecyclePaymentService.php` (payment consolidation, idea #9312, in progress) | nothing directly — it's the logic |
| Agent door | tools registered in `lib/CanonicalToolRegistry.php` (`get_student_lifecycle_state`, `get_canonical_repair`, payment tools per #9311) | the 5 CS agents (Email/SMS/Chat/Voice/Ticket) + RUBEN via ticket agent |
| Cline door | `emsu-operations` MCP tools (`get_student_lifecycle_state`, `get_canonical_repair`, etc.) | Cline (me) |

There is no `Student Lifecycle` MCP server in `cline_mcp_settings.json`. The MCP server is `emsu-operations`. SLS is the *capability* exposed through it.

## Why "say SLS and they'll all know" is only HALF true

- **Cline knows it** because this rule (135) is loaded into the system prompt every task. That is the durable surface for Cline.
- **The PHP agents do NOT read .clinerules or idea rows.** They only know what their runtime tool registry + system prompt tell them. So an agent "knows" SLS only if the SLS tools are registered in `CanonicalToolRegistry.php` with descriptions naming it. The NAME lives for agents in the tool descriptions, not in any doc.
- **An approved orchestrator idea is a to-do, not memory.** Filing #9312 does not teach anyone the name.

So the name sticks only where it is physically written into a read-at-runtime surface: this rule (Cline), the tool descriptions (agents), and the lib docblock (future devs/Cline reading source).

## The durable surfaces that must carry the name (checklist)

When building SLS (#9312/#9311), the name must be written into ALL of these or it will NOT be universally recognized:

1. **This rule (135)** — Cline. ✅ (you are reading it)
2. **`lib/StudentLifecyclePaymentService.php` docblock** — opens with "Student Lifecycle Service (SLS)" + the one-line definition.
3. **Every CanonicalToolRegistry tool description** for lifecycle/payment tools — prefix with "Student Lifecycle Service (SLS):" so the agent sees the name at call time.
4. **`routes/student_status_reference.php`** (the authoritative human doc) — add an "SLS" pointer section so staff/Jon recognize it.
5. **HANDOFF_NOTES.md** — reference "SLS" by name in the relevant entries.

## Self-check

If a future window is told "use the SLS" / "check the Student Lifecycle Service" and is unsure: it is the `get_student_lifecycle_state` + `get_canonical_repair` (+ payment) tools on the `emsu-operations` MCP, backed by `lib/StudentLifecycleState.php` / `lib/StudentLifecyclePaymentService.php`. Call those. Do not go looking for an MCP server named "Student Lifecycle."

## Cross-references

- idea #9086 — StudentLifecycleState.php lifecycle gate engine
- idea #9312 — StudentLifecyclePaymentService.php payment consolidation (the facade)
- idea #9311 — register the deep payment tools for agents
- idea #9320 — Academic Integrity Guard (mandatory on every unsuspend path)
- .clinerules/110 — lib is the single source of truth
- .clinerules/92 — work at the core (one brain, not ten scattered files)

## Last updated

2026-06-02 — initial. Source: Ruben asked what to name the capability and (correctly) doubted that naming alone makes it universally known. The answer: the name must be physically written into each read-at-runtime surface (this rule for Cline, tool descriptions for agents, lib docblock for source readers). Naming an idea does not propagate knowledge.
