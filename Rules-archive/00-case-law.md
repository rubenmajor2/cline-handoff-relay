# 00 — Case law & source incidents (force-subagent-use)

Archived from the hardfloor rule `00-READ-FIRST-17-force-subagent-use-on-research-and-multi-step-builds.md` on 2026-07-11 to bring the hardfloor file under the 12KB G7 cap. Full current gate logic lives in the hardfloor file; this is historical justification only.

## Source incidents

- **2026-05-03** v1: Artemis pty-host saturation — went inline 3× instead of dispatching.
- **2026-05-14** v2 (default-on, 5 exceptions): Opus first-task did evaluations inline, zero subagent calls, zero 7B-LoRA. Ruben: *"we need to make some other adjustments to the client rules to force opus to do as we ask."*
- **2026-05-15** tripwire: counters at 639/7d, 2500/30d. Ruben: *"what can we do."* Tripwires fire on measurable event; defaults rationalize away.
- **2026-05-19** mid-task variant: tasks 1779253360281, 1779252924920, 1779252183079 all died from plan-line-without-tool or "Doing X now"-narration-without-tool. Consolidated rewrite this date.
- **2026-06-20** FETCH-THEN-PASTE addendum: a Frankenstein-Doctor RCA found 8+ subagents (escalating 3→54→14→8→13/day, 06-17 to 06-21) stuck in retry loops. Signature: 3 convs (conv_93737c28b8bf26e1, conv_9b94c52e4a7979d4, conv_69d5ae6660bde1f1) dispatched at the EXACT same timestamp (a `use_subagents` fan-out) with go-fetch prompts — "Use emsu-operations MCP read_server_file...", "Use web search to find...". Each subagent hit "Tool 'use_mcp_tool' is not available in this context," then improvised a doomed raw `ssh root@`/`curl google.com` and looped. The subagents had ZERO MCP data — they were told to fetch it themselves, which they cannot. Ruben asked "subagents still have access to MCP info even though they're not looking at the MCP directly?" — yes, IF the parent fetches it and pastes it in (fetch-then-paste). Added the correct pattern + the banned-dispatch-keyword self-check. Bug library #746, idea #13575.
- **2026-06-20 DEFAULT FLIP:** Ruben directive — subagents are now opt-IN. Default first move = inline MCP tools. Only dispatch `use_subagents` when Ruben explicitly says "research with subagents" / "use subagents" / "dispatch" / "fan out". When dispatched, subagent turns route through deepseek-v4-pro (server-side enforced in router_hook.py) to keep the local 120B pool free for the main interactive window (rule 146).
- **2026-06-21 DEFAULT FLIP BACK:** Ruben directive — subagents are default-ON again. Two reasons: (1) deepseek-v4-pro prefix caching achieved -120x cost reduction today, making subagent dispatch effectively free. (2) The doorman + 10s timeouts deployed today removed the previous bottleneck (dead-rung probe latency), so the local 120B pool is no longer saturated by non-tool fallthrough. Subagents route through deepseek-v4-pro (server-side enforced) to keep the local pool free for interactive main windows.
- **2026-07-11** trim: Rule 00 hit 13,479 bytes, exceeding the 12KB G7 hard cap. This file was split out to restore compliance (idea #17166).

## Cross-ref

Full current gate: `~/Documents/Cline/Rules/00-READ-FIRST-17-force-subagent-use-on-research-and-multi-step-builds.md`
