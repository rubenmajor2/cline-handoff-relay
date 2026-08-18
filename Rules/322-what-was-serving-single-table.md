# Rule 322 — "What Was Serving" = ONE Table of UNDERLYING LLMs

**Severity: HARD FLOOR (user-mandated format)**
**Created: 2026-08-18 (Ruben directive: "This is what I ALWAYS want whenever I ask you for what was serving. Make that a cline rule.")**
**Amended: 2026-08-18 (Ruben correction: "I do NOT care to see in the table how many turns for frankenstein-llm or frankenstein-tools. I want to see the underlying LLM (i.e. GLM 5.2 Local, 120Bs, 235B Julia, GLM Cloud, etc.).")**

## Core principle

When Ruben asks what was serving, the answer is ONE table where each ROW is an UNDERLYING PHYSICAL LLM, not a router handle, adapter name, or pool alias. `frankenstein-llm`, `frankenstein-tools`, and `emsu-executor-auto` are ROUTING NAMES — they are explicitly FORBIDDEN as table rows. Resolve them through to the real model that computed the tokens.

## Mandatory format

```
| underlying LLM | endpoint(s) | turns / reqs (window) | out tokens | tok/s | $ cost | note |
```

- **underlying LLM** = the physical model that produced the tokens. Examples of CORRECT rows: `GLM-5.2 Local 744B`, `gpt-oss-120B`, `Julia-235B (Qwen3-235B-A22B)`, `Cicero-235B`, `DeepSeek-v4-pro`, `GLM Cloud (zai/glm-5.3)`, `qwen2.5-coder:14b`, `minicpm-v`. Examples of WRONG rows (routing names): `frankenstein-llm`, `frankenstein-tools`, `emsu-executor-auto`, `frankenstein-glm52-local`, `glm-5.2-smart`.
- **endpoint(s)** = the actual serving socket(s): `:8210` (GLM ring), `:8000` Artemis, `:8000` BigMac, `:11513` Julia, `api.deepseek.com`, `api.z.ai`, `:11434` WOPR ollama, `:11455` vision.
- **turns / reqs** = turn count from `llm_call_log`, or upstream request count from the adapter log. Label which source and window.
- **out tokens / tok/s / $ cost** = as in llm_call_log where available; `—` where missing (never drop the column).

## Resolution rules (how to map routing names → physical LLM)

1. **Adapter pool (:11510 frankenstein-tools).** `frankenstein-tools`, `frankenstein-llm` (local pool), and `emsu-executor-auto` all land on the :11510 adapter, whose pool is: Artemis `gpt-oss-120b` (:8000), BigMac `gpt-oss-120b` (:8000), and the GLM-5.2 Local ring (:8210). Break the pool counts down BY UPSTREAM using `/var/log/emsu-adapter-upstream.log` (grep `"upstream"`), and report each physical model as its own row. If a per-turn join is genuinely impossible, combine them as `gpt-oss-120B (pool: Artemis+BigMac)` and `GLM-5.2 Local` with the upstream split noted in the note cell — NEVER as `frankenstein-tools`.
2. **Direct GLM ring handles** (`glm-5.2-local`, `frankenstein-glm52-local`, `glm52-only`, `glm-5.2-max`, `frankenstein-deep`, `glm-5.2-smart`, `glm-5.2-obedient`) all collapse to ONE row: `GLM-5.2 Local 744B (PP=6 Hex ring, :8210)`.
3. **Direct 120B handles** (`gpt-oss-120b`, `artemis-gpt-oss-120b`, `bigmac-120b`, `julia-120b`) collapse to `gpt-oss-120B` with the endpoint disambiguating which box.
4. **DeepSeek** = `deepseek-v4-pro` (free cloud) — a real row, NOT GLM, NOT local, $0.00.
5. **GLM Cloud** = the paid Zhipu/Z.ai handle (`glm-5.2` cloud entry, now wired to zai/glm-5.3 after 2026-08-18). Distinct row from GLM-5.2 Local. Label cost `paid`.
6. **Every registered physical model gets a row even if turns=0** in the window, with note = `DOWN (probe: ...)` or `0 in window`. A serving fleet member that is missing from the table is a rule violation — this is how "where is Julia 235B / it should be serving" got caught.

## Serving-status discipline

- A "DOWN" verdict MUST be earned by MULTIPLE probes this session AND a check of the router audit / routing record — see rule 315. Never recite "LIVE" from a stale registry note: the registry said "LIVE 2026-08-16" for Julia-235B when the :11513 tunnel was flapping on 2026-08-18.
- **TUNNEL vs MODEL distinction (learned 2026-08-18):** an endpoint like `127.0.0.1:11513` is a REVERSE TUNNEL to a remote box, not the box itself. A connection-refused probe means the TUNNEL is down at that instant — it does NOT mean the model is dead. If the router route serves (e.g. `litellm:julia-235b` returns quickly, or the router audit shows `picked: julia-235b` with no substitution) while a direct tunnel probe refuses, the verdict is **TUNNEL FLAPPING (intermittent)**, never "model DOWN". Re-probe over >10 minutes and inspect the tunnel/autossh/WG unit before declaring anything.
- **One probe is never a verdict.** Julia-235B example: refused at 12:48 and 13:00 PT but served Ruben's `litellm:julia-235b` test at 12:58 PT (router audit: `req: julia-235b → picked: julia-235b`, explicit L4, no substitution). A single refused probe, reported across a table as DOWN, is a false positive that contradicts the user's own live test.
- **Zero adapter-pool picks ≠ model down.** `julia-235b`, `cicero-235b`, etc. are DIRECT LiteLLM lanes, NOT members of the :11510 adapter pool. Their absence from the adapter upstream log is expected and meaningless. Evidence must come from the router audit log and their own config/api_base.

## Source incident

2026-08-18, two failures in one session:
1. Answer split the fleet into two tables (frankenstein-tools vs frankenstein-llm) plus paragraphs, and left DeepSeek without a cost label — read as paid GLM.
2. After the first correction to "one table", the table still used routing names (`frankenstein-llm`, `frankenstein-tools`) as rows instead of the underlying physical LLMs. Ruben: "I want to see the underlying LLM (GLM 5.2 Local, 120Bs, 235B Julia, GLM Cloud, etc.)."
3. Third failure: Julia-235B was marked DOWN in the table from a single refused tunnel probe at 12:48 PT, but Ruben's own live test at 12:58 PT via `litellm:julia-235b` served quickly and the router audit recorded `req: julia-235b → picked: julia-235b` (no substitution). The verdict was TUNNEL FLAPPING, not model DOWN. This is the source of the "TUNNEL vs MODEL" + "one probe is never a verdict" discipline above.
