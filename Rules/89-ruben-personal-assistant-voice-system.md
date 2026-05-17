# 89 — RUBEN Personal Assistant (TNG voice line) — reference card

Permanent rule. Workspace-scoped. Source: 2026-05-17 cline_ruben-pa-health-check
where Cline burned ~$50 making 5 wrong analytical passes before figuring out
what RUBEN Personal Assistant actually is. This rule prevents the same
confusion next time.

## What RUBEN Personal Assistant IS

**A Star Trek TNG themed voice line that Ruben calls to operate the EMSU
stack hands-free.** Not the CS phone system. Not the canary monitor. Not
the chat AI. A dedicated voice assistant with a TNG "Computer" persona,
LCARS progress sounds, authorization codes, and access to the same MCP
tools Cline uses.

## Hard facts

| Item | Value |
|---|---|
| **Inbound destination number** (the number Ruben dials) | **+17602807886** |
| Greeting opener | "Rui computer online. Awaiting authorization." or "Welcome back, captain. All systems nominal." |
| Theme | Star Trek TNG bridge protocol — Computer / Captain / authorization codes (e.g. "major 1-1-alpha") / auto-destruct sequence as humor |
| Model | claude-sonnet-4-6 |
| Tool mode | strict (must call tool, not just narrate) |
| Max call duration | 1800 sec (30 min) |
| Silence timeout | 600 sec (10 min) |
| Concurrent background tasks | 3 |
| Proactive update cadence | every 25 sec during silence |
| Session memory depth | 5 prior calls |
| Progress words during silence | Analyzing, Scanning, Computing, Accessing, Querying, Compiling, Retrieving, Running diagnostics |

## Which number Ruben calls FROM

| Ruben source phone | Routes to |
|---|---|
| **+17605250530** | TNG "Computer" persona at +17602807886 ✓ |
| **+12196280702** | Jon's VADER "Lord Thompson / Imperial" persona — **NOT TNG** |

Two different inbound numbers + two different source-phone routes = two
different personas. Do NOT assume one persona for both.

## Jon's separate PA

Jon has his own personal assistant with a **VADER / Imperial** theme.
Opener: *"My lord Thompson, your humble servant waits. The empire stands
ready at your command. What is thy bidding, my master?"* Calls Robo Ruben
"Admiral Major" and uses Imperial Star Wars register. **This is NOT
Ruben's PA.** If you see "Lord Thompson" in a transcript, that's Jon's,
not the TNG line.

## Where the data lives

| Table | Purpose |
|---|---|
| `ruben_voice_calls` | Every call. `caller_phone` is SOURCE not destination. `ai_analysis_json` has post-call resolution analysis |
| `ruben_voice_settings` | Model/temp/timeout config |
| `ruben_voice_profiles` | Voice impersonation data — Vicky (700 samples), Jon (700), Cori (520) — used for drafting messages in their style |
| `ruben_tng_canary_config` | Per-line canary monitor config (row 1 = TNG line at +17602807886, enabled=1) |
| `ruben_tng_canary_runs` | Canary test history (often empty if no synthetic tests have run) |

## Where the data DOES NOT live (common confusion points)

- `vapi_assistants` → CS Katie + EMSU public phone, **not RUBEN PA**
- `vapi_persona_config` / `vapi_persona_variants` / `voice_persona_lock` → CS Bella/Katie/Eric/Ronald variants for CS, **not RUBEN PA**
- VAPI dashboard → likely holds the ANI-to-assistant mapping but **not visible from MySQL**

## Health-check workflow (next time, do THIS first)

```sql
-- Step 1: Is the TNG persona firing recently for Ruben's source number?
SELECT id, caller_phone, caller_name, duration_seconds,
       LEFT(transcript, 200) AS opener, created_at
  FROM ruben_voice_calls
 WHERE transcript LIKE '%Computer%'
    OR transcript LIKE '%Captain%'
    OR transcript LIKE '%authorization%'
 ORDER BY created_at DESC
 LIMIT 10;

-- Step 2: Recent call activity from Ruben's TNG source number
SELECT id, caller_phone, caller_name, duration_seconds,
       LEFT(transcript, 200) AS opener, termination_reason, created_at
  FROM ruben_voice_calls
 WHERE caller_phone = '+17605250530'
 ORDER BY created_at DESC
 LIMIT 10;

-- Step 3: Check for zero-duration calls (connection issues)
SELECT COUNT(*) AS dead_calls_24h
  FROM ruben_voice_calls
 WHERE caller_phone = '+17605250530'
   AND duration_seconds = 0
   AND created_at > NOW() - INTERVAL 24 HOUR;

-- Step 4: Tool execution check — read ai_analysis_json on recent calls
SELECT id, LEFT(ai_analysis_json, 800) AS analysis
  FROM ruben_voice_calls
 WHERE caller_phone = '+17605250530'
   AND created_at > NOW() - INTERVAL 7 DAY
 ORDER BY created_at DESC
 LIMIT 5;
```

The fingerprint of TNG working: opener contains "Computer" / "Captain" /
"authorization." The fingerprint of TNG broken: greeted with "Lord
Thompson" / "Empire" (that's VADER routing crossed over).

## What can fail and the signature

| Failure | Signature in `ruben_voice_calls` |
|---|---|
| Vapi connectivity blip | Run of `duration_seconds=0` calls (e.g. 17 zero-dur in an hour on 5/7) |
| Persona routing crossed | Greeted with "Lord Thompson" when calling from +17605250530 |
| Persona disabled | No recent calls + canary_config row enabled=0 |
| Tool execution gap | `ai_analysis_json` shows "AI verbalized but did not execute tool" |
| Cron health degraded | `cron_voice_agent_health` heartbeat count <100/24h |

## Known good baseline

As of 2026-05-17 11:32 PT — Ruben called +17602807886 from +17605250530,
got "Rui computer online. Awaiting authorization." Call 9717. Confirmed
TNG persona healthy and reachable.

## Improvement candidates (filed for Ruben review, not auto-actioned)

1. **Tool-execution gap on background actions** — multiple calls (9714,
   9715, 9716 on Jon's VADER, same model) show AI narrating actions
   without firing tools. Mitigation: prompt patch + per-call analysis
   shows AI's own honesty is intact, just needs an enforcement layer.
2. **cron_voice_agent_health degraded** — 8 heartbeats in 24h vs
   expected ~288. Worth a separate investigation.
3. **RUBEN orchestrator paused in shadow mode** — 1823 backlog items,
   535 open tickets. PA can ask to unpause but worth verifying tool
   fires.
4. **No recent canary runs** — `ruben_tng_canary_runs` empty. If we
   want unattended health verification, the canary cron should be
   running periodically.

## What I (Cline) MUST do going forward

1. **When Ruben says "RUBEN PA" / "TNG line" / "my voice line"** — first
   tool call is the health-check SQL above, NOT vapi_assistants and NOT
   ruben_tng_canary_config alone.
2. **When investigating a phone-related issue, ask which number FIRST.**
   Source phone vs destination phone is the most common axis I get wrong.
3. **Do not file ideas / send chats / trigger anything autonomously** on
   PA infrastructure without explicit Ruben Y.

## Cross-references

- .clinerules/32 — prefer dedicated MCP wrappers over raw SQL (applies
  here: there IS no dedicated wrapper for RUBEN PA yet — using raw SQL
  is correct, but use the right tables)
- .clinerules/75 — verification tasks default to MCP + subagents + 7B
- .clinerules/53 — subagent narration + Opus signals (PA debugging is
  cross-system synthesis, Opus signal #1)

## Last updated

2026-05-17 — initial. Source incident: cline_ruben-pa-health-check-2026-05-17,
where Cline made 5 wrong analytical passes confusing CS Katie, ruben_tng_canary_config,
and Jon's VADER for Ruben's TNG line. Live-verified working 11:32 PT.
