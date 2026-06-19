# Bug‑Library entry – 2026‑06‑19
## Symptom
- Observation: `/tmp/emsu_router_audit.log` shows a burst of **FAILOVER** entries (371) while normal **OK** entries are only 77 for the same backend.  
- No `CORRECTIVE_RETRY` entries (count = 0) were recorded, indicating the loop is on the **FAILOVER** path (i.e. request‑to‑tool‑rank → 500 → 400 → 502) rather than a malformed‑args path.

## Diagnosis
- The pattern matches the “FAILOVER” loop class (Rule 158 Step 6 – revive attempts → euthanize).  
- The loop originates from a TTFB/400 saturation in the FAILOVER routing ladder, **not** from a malformed‑args (raw‑120B) path.

## Resolution (to be applied by ADAPT2)
1. Confirm the loop is on the FAILOVER ladder by a live header probe (stream + tools) – see Rule 140.  
2. If confirmed, **ADAPT2** should patch the FAILOVER path (e.g., adjust rank, health probe timeout, or capability guard) rather than the malformed‑args path.  
3. Record the incident in `frankenstein_router_incidents` (via the `bug_library_record` MCP tool when the Doctor runs).  
4. Add a reference to this entry from Rule 158 (so future Doctors know the correct target).

## Status
- **Recorded** – pending further action by ADAPT2.