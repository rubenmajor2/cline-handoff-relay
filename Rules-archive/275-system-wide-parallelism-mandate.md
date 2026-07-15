# 275 — System-wide parallelism mandate: ALL AI agents, tools, and data operations must use parallel streams

Permanent rule. Workspace-scoped. Source: Ruben directive 2026-07-14 — "All of the AI agents can benefit from these new tarpipe and parallelism principles. This is a revolutionary idea."

## The rule

**Every AI agent, tool, and data operation in the EMSU system MUST be evaluated for parallelism opportunities.** If work can be split into independent chunks, it MUST be run in parallel. This is not optional — it is a systemic design principle.

## Complete inventory of AI agents that MUST benefit from parallelism

### Customer-Facing Agents (CFA) — per rule 272
1. **Email AI** (cron_ai_ticket_agent) — 128 concurrent email processing
2. **Chat Widget AI** (livechat webhook) — 128 concurrent chat sessions
3. **SMS AI** — 128 concurrent SMS responses
4. **Voice AI (Vapi)** — parallel call processing (Vapi handles this, but our backend must not bottleneck)
5. **Ticket Auto-Reply** — 128 concurrent ticket responses
6. **AI Grader** (cron_ai_grading.php) — 128 concurrent exam submissions
7. **ANY FUTURE AI AGENT** — must be designed for 128 concurrent from day 1

### Internal Agents
8. **RUBEN Orchestrator** — parallel event processing, parallel decision triage
9. **Executor** — 3 ideas spec-generated simultaneously (idea #17717)
10. **Personnel AI Agent** (Opus 4.6) — parallel candidate processing
11. **Externship Scheduling Agent** — parallel agency outreach
12. **Cline** — already supports parallel MCP tool calls (leverage this more)

### CS Agent Tools (Argus/Alltastic/etc.)
13. **Student 360 lookups** — batch 128 student lookups simultaneously instead of 8
14. **Payment verification** — parallel verify_payment_state across multiple students
15. **Moodle enrollment checks** — batch check_moodle_enrollment for entire class rosters
16. **Ticket search** — parallel search across multiple keywords/students
17. **Grievance scanning** — batch scan all open grievances simultaneously
18. **Compliance checks** — parallel check across all accreditation bodies
19. **Externship queue processing** — batch process pending externship requests
20. **ANY TOOL used by CS agents** — must support batch/parallel mode

### Data Operations
21. **File transfer** — tar pipe (110MB/s) or distributed rsync (rule 274)
22. **Backup/restore** — tar pipe for initial, rsync --partial for incremental
23. **Log aggregation** — parallel tar pipe from all fleet nodes
24. **Database exports** — parallel pg_dump for large tables
25. **Moodle grade import** — tar pipe for bulk grade data
26. **QB sync** — parallel batch processing
27. **Adapter distribution** — distributed rsync to all Hexarchy nodes simultaneously

### Training Pipeline
28. **Data distribution** — tar pipe (4.4x faster than rsync)
29. **Checkpoint save** — parallel write to multiple nodes
30. **Weight pull** — xargs -P8 rsync before gate/judge steps (fast-train hardfloor)
31. **Interleaved training** — start training on shard 1 while shard 2 syncs

## How to apply parallelism to ANY new AI agent or tool

**The 3-question parallelism test (run before building ANY new agent/tool):**
1. Can this work be split into independent chunks? (If yes → parallelize)
2. Can multiple instances run simultaneously without conflict? (If yes → parallelize)
3. Is there a bottleneck that prevents parallelism? (If yes → fix the bottleneck, then parallelize)

**If YES to 1 and 2 → the agent/tool MUST be designed for 128 concurrent from day 1.**

## Ruben's Mac speed improvement

Parallelism principles can speed up Ruben's Mac:
- **Parallel MCP tool calls** — Cline already supports this. Fire 5 student lookups simultaneously instead of 5 sequential calls.
- **Parallel subagent dispatch** — rule 00. Multiple subagents reason in parallel.
- **Parallel executor offload** — rule 267. File multiple ideas simultaneously, executor processes in parallel.
- **Parallel LLM streams** — with max-num-seqs 128, the Mac can fire 128 concurrent requests to GLM-5.2 without queuing.

## The revolutionary insight

This is not just about file transfer or LLM throughput. It is a **systemic design principle** that applies to EVERYTHING:

- File transfer → tar pipe (4.4x)
- LLM inference → max-num-seqs 128 (4.3x)
- Agent dispatch → parallel CFA (16x)
- Tool calls → parallel MCP (5x+)
- Training → parallel data distribution (4.4x)
- Executor → parallel idea processing (3x)
- Backups → tar pipe (4.4x)

**The cumulative effect: 4-16x speedup across the ENTIRE system.**

## Cross-references

- Rule 272 — CFA definition (all customer-facing AI agents)
- Rule 274 — Parallel distributed file transfer (tar pipe, multi-node rsync, xargs -P)
- Rule 00 — Force subagent use (parallel subagent dispatch)
- Rule 267 — Orchestrator/executor offload (parallel idea processing)
- Rule 146 — Frankenstein LLM routes everything (parallel LLM streams via continuous batching)

## Source

2026-07-14 — Ruben directive: "All of the AI agents can benefit from these new tarpipe and parallelism principles. Think about it. I bet you the drafting of ideas can also benefit from it as well as how the executor and orchestrator work. This is a revolutionary idea."

## Last updated

2026-07-14 — initial. Complete AI agent inventory + 3-question parallelism test + systemic mandate.