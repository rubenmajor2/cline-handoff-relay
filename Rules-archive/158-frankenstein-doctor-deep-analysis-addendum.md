# 158 addendum — Deep Analysis Protocol (mandatory during babysitting, replaces superficial heartbeats)

Source: 2026-06-18 Round 4 stress test. Ruben: "No you just did a superficial glossover. You didn't actually look... those are bandaids... we have a deeper issue that requires analysis... iterating for 2 hours is a long time."

## The failure mode this addendum fixes

During Round 4, the Doctor spent 60+ minutes doing superficial "alive/dead" heartbeat checks ("3 alive, fleet GREEN, C:200 A:200") while 4 windows ground through a 26.4% error turn rate, taking 2 hours to complete tasks Claude would finish in 15-30 min. The Doctor didn't catch the real issue (model tool-calling quality) until Ruben explicitly said "you didn't actually look."

**Superficial checks = counting how many windows are alive. Deep analysis = understanding WHY they're slow and WHAT's causing errors.**

## The mandatory deep analysis protocol (replaces heartbeat checks during babysitting)

When babysitting frankenstein-llm windows, the Doctor MUST run this analysis every 15 minutes, not "3 alive, fleet GREEN" heartbeats.

### The analysis query (run via ssh_command every 15 min)

```python
import json; from datetime import datetime
lines = open('/tmp/emsu_router_audit.log').readlines()[-5000:]
turns = {}
for l in lines:
    try:
        d = json.loads(l.strip())
        if d.get('req')=='frankenstein-llm' and d.get('conversation_id') and \
           d.get('user_preview','') not in ('gw-watchdog-probe','canary') and \
           d.get('total_chars',0) > 1000:
            cid = d['conversation_id']
            t = datetime.strptime(d['t'], '%Y-%m-%dT%H:%M:%SZ')
            picked = d['picked']
            preview = d.get('user_preview','')[:50]
            if cid not in turns: turns[cid] = []
            turns[cid].append({'t': t, 'picked': picked, 'preview': preview})
    except: pass

for cid, tlist in sorted(turns.items(), key=lambda x: -len(x[1]))[:5]:
    tlist.sort(key=lambda x: x['t'])
    gaps = [(tlist[i]['t'] - tlist[i-1]['t']).total_seconds() for i in range(1, len(tlist))]
    error_turns = sum(1 for t in tlist if any(kw in t['preview'].lower() 
        for kw in ['did not use a tool', 'error', 'failed', 'invalid']))
    avg_gap = sum(gaps)/len(gaps) if gaps else 0
    total_time = (tlist[-1]['t'] - tlist[0]['t']).total_seconds()/60 if len(tlist)>1 else 0
    backends = {}
    for t in tlist:
        backends[t['picked']] = backends.get(t['picked'],0)+1
    error_pct = (error_turns/len(tlist)*100) if tlist else 0
    print(f'{cid[:16]}... {len(tlist)} turns, {total_time:.0f}min, avg gap {avg_gap:.0f}s, '
          f'errors {error_turns}/{len(tlist)} ({error_pct:.0f}%), primary={max(backends, key=backends.get)}')

total = error = 0
for cid, tlist in turns.items():
    total += len(tlist)
    for t in tlist:
        if any(kw in t['preview'].lower() for kw in ['did not use a tool','error','failed','invalid']):
            error += 1
print(f'\nOverall: {total} turns, {error} errors ({error/total*100:.1f}%)')
```

## What the deep analysis must answer (every 15 min)

1. **Turn error rate**: What % of turns are wasted (no-tool-use prose, tool failures, "Invalid API Response")? Healthy: <5%. Concerning: 10-20%. Broken: >20%.
2. **Average turn gap per conversation**: How many seconds between consecutive turns? Healthy: 30-60s. Slow: 60-120s. Stalled: >120s.
3. **Per-conversation breakdown**: Which specific conversations are slow? What errors are they hitting? What backend are they on?
4. **Root cause classification**: Is the slowness from (a) model quality (no-tool-use prose), (b) fleet saturation (admission_control), (c) context overflow (ctx_overflow_reroute), (d) backend errors (502/timeout), or (e) something else?
5. **Is the fix a bandaid or a core fix?**: Restarting a service = bandaid. Fixing the model's tool-calling compliance = core fix. Per rule 92.

## What counts as "superficial" (banned as primary monitoring during babysitting)

These checks are insufficient as the ONLY monitoring:
- "3 alive, fleet GREEN" -- doesn't tell you error rate or WHY windows are slow
- "C:200 A:200 T:200" -- service-alive checks miss model-quality issues
- "22 convos active" -- counting conversations doesn't reveal per-turn failures
- "load 6.41" -- server load doesn't explain 2-hour completion times

These are fine as SUPPLEMENTARY data but NOT as the primary monitoring output. The primary output must be the deep analysis above.

## When to escalate beyond fleet fixes (the "deeper issue" signal)

If the deep analysis shows:
- Error rate >20% AND the errors are "no tool use" (model prose without tool block) AND the fleet is healthy (services alive, no 502s, no saturation) -- the issue is MODEL QUALITY, not fleet health. Bandaid fleet fixes won't help. File a P1 idea for model tool-calling improvement (LoRA training, system prompt injection, error-turn fast-recovery).
- Average turn gap >90s AND the gaps are mostly generation time (not error retries) -- the issue is GENERATION SPEED. The 120B is inherently slower than Claude. Not fixable by fleet tuning. Report honestly to Ruben.
- Context growing past 200K+ tokens -- the issue is CONTEXT MANAGEMENT. Windows need to compress earlier. Not a fleet issue.

## The Doctor's honest report obligation

When Ruben asks "what's going on with these windows," the Doctor MUST:
1. Run the deep analysis script
2. Report the per-conversation error rate, avg turn gap, and root cause
3. Classify whether the issue is fleet-fixable or model-quality or context-management
4. If model-quality: say so honestly ("the 120B is producing prose instead of tool calls on 26% of turns -- this is a model quality issue, not a fleet issue, and the core fix is LoRA training on tool-call tasks")
5. NEVER hide behind "fleet GREEN" when windows are taking 2 hours

## Source incident

2026-06-18 Round 4 stress test. Doctor spent 60+ minutes doing superficial heartbeats while 4 windows ground through 26.4% error rate (101/383 turns). Ruben: "No you just did a superficial glossover. You didn't actually look." Deep analysis revealed: gpt-oss-120b produces "no tool use" prose 14-29% of the time, each error turn wastes 47-126s on retry. Core fix: idea #13199 (P1, approved).

## Cross-references

- Rule 158 (main body) -- this addendum extends the babysitting protocol
- Rule 92 -- work at the core, not bandaids (model quality > fleet restarts)
- Rule 29 -- act on confidence (honest reporting obligation)
- Idea #13199 -- core fix for 26% error turn rate
- Idea #13196 -- proactive window freeze fix (P1, approved)
- Idea #13191 -- LiteLLM max_tokens fallback bug (P2, approved)
