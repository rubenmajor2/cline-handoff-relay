# 262 — Consult bug library + community before recycling debugging approaches

Source: 2026-07-09 Ruben directive: "seems like you are recycling bad ideas or failed ideas / things that did not work before. You need to consult and look at the bug library as well as the community for answers."

## The bright-line rule

**Before retrying a debugging approach that failed in a prior session OR retrying the same fix a 3rd time in the current session, you MUST:**
1. Query the bug library (`frankenstein_router_incidents`) for the error/symptom
2. Search the community (GitHub issues, Stack Overflow, vendor docs) for the exact error string

If you skip both and just retry, you are recycling failed approaches. That is a violation.

## The 2-strike tripwire

| Strike | What happened | Required next move |
|---|---|---|
| 1 | First attempt at a fix fails | OK, try a different approach |
| 2 | Second attempt at SAME class of fix fails | **STOP.** Query bug library + search community BEFORE any 3rd attempt |
| 3+ | Retrying same approach without consulting external sources | **VIOLATION.** You are in a loop. |

A "same class of fix" = same tool, same config surface, same error pattern. Example: changing `NCCL_IB_HCA` format 3 times without searching NCCL issues is a violation.

## How to query the bug library

```sql
-- Via emsu-operations ssh_command + mysql:
SELECT id, problem_key, LEFT(symptom_observed,200), LEFT(resolution,300), status
FROM frankenstein_router_incidents
WHERE problem_key LIKE '%KEYWORD%'
   OR symptom_observed LIKE '%ERROR_STRING%'
ORDER BY id DESC LIMIT 10\G
```

Always check if a prior session already diagnosed and resolved (or partially resolved) the issue. The bug library is institutional memory — use it.

## How to search the community

### GitHub issues (via github MCP)
```
search_issues(q: "exact error string repo:vendor/project")
```
Example: `search_issues(q: "NET/IB No device found repo:NVIDIA/nccl")` found issue #451 which was the exact root cause.

### Vendor docs (via fetch tool)
```
fetch(url: "https://docs.nvidia.com/deeplearning/nccl/...", max_length: 8000)
```

### Stack Overflow / forums (via fetch tool)
```
fetch(url: "https://stackoverflow.com/search?q=exact+error+string")
```

Note: GitHub.com pages are blocked by robots.txt for the fetch tool. Use the `github` MCP `search_issues` tool instead — it uses the API which is not blocked.

## When this rule fires

- **Debugging loops**: same error 2+ times → consult bug library + community
- **"I've seen this before"**: if the error feels familiar, it's probably in the bug library — check it
- **Prior session references**: if a pickup prompt mentions prior ideas/bugs, read them BEFORE retrying
- **New error class**: first occurrence of a novel error → search community proactively (don't wait for strike 2)

## What does NOT count as "consulting"

- Re-reading your own log output (that's just re-examining the same data)
- Asking Ruben "what do you think?" (that's escalation, not research)
- Guessing at a different config value without understanding WHY the prior one failed

## Self-check before any 3rd debugging attempt

1. *Have I queried the bug library for this error?* If no → do it now.
2. *Have I searched GitHub issues / Stack Overflow for the exact error string?* If no → do it now.
3. *Am I about to retry the same approach with a minor tweak?* If yes → STOP. The community likely has the answer.

## Cross-references

- Rule 156: bug library check before fix (this rule extends it with community search)
- Rule 29: agents act on confidence tier (consulting sources increases confidence)
- Rule 99: YOLO prevention (recycling failed approaches wastes consecutive-mistakes budget)

## Source incident

2026-07-09 — GLM-5.2 CX7 RoCE task #16771. Agent spent 45+ minutes recycling NCCL IB debugging approaches (changing NCCL_IB_HCA format, LD_PRELOAD, routing configs) without consulting the bug library or GitHub issues. Ruben: "seems like you are recycling bad ideas or failed ideas / things that did not work before. You need to consult and look at the bug library as well as the community for answers." Once the agent searched GitHub issues (#451 exact match), the root cause was found in 2 minutes.

## Last updated

2026-07-09 — initial.