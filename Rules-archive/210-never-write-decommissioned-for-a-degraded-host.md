# 136 — Never write "decommissioned" or "permanently offline" for a host that fleet-state shows as degraded

Source: 2026-06-04 Cline completion incorrectly described Artemis as "decommissioned" when fleet-state canonical status is "degraded" and recovery docs + ideas are actively tracking revival.

## The bright-line rule

Before writing any infrastructure status to HANDOFF_NOTES, a pickup prompt, a ticket, or ops chat — check fleet-state MCP canonical status. The **status field is authoritative**. The role field may be stale.

| fleet-state status | Correct language | Forbidden language |
|---|---|---|
| `healthy` | "online", "serving", "active" | — |
| `degraded` | "unreachable", "in failover", "temporarily offline", "WireGuard down" | "decommissioned", "offline", "gone", "permanently down" |
| `down` | "offline", "down" | "decommissioned" unless role ALSO says decommissioned + no revival idea exists |
| `unknown` | "unknown status" | any definitive claim |

**A host is decommissioned ONLY when:**
1. `role` = explicitly decommissioned AND
2. No active revival idea (#) in the fleet notes AND
3. `status` = "down" AND
4. No recent heartbeat within the last 30 days

If any of those 4 conditions is false, the host is in **temporary failover**, not decommissioned.

## The Artemis case (source incident)

Artemis fleet-state:
- `role`: "decommissioned_gpu" (stale — set 2026-05-25 B5, Artemis came back 2026-05-27)
- `status`: "degraded" (correct)
- `last_heartbeat`: null (WireGuard down since 2026-06-03 reboot)
- Notes: active revival idea #6837 + #7759, recovery doc at ~/Desktop/ARTEMIS_MASTER_RECOVERY_AND_70B.md
- Condition 2 fails (revival ideas exist) → NOT decommissioned. FAILOVER.

Cline wrote "Artemis is decommissioned" in a completion. This misinformed other agents about infrastructure state and required an explicit correction HANDOFF entry.

## The check (run BEFORE writing any infrastructure status statement)

```
fleet_inventory() → check host_key's status field
```

If status = "degraded" AND notes contain an idea # or recovery doc → use "in failover" or "temporarily offline", never "decommissioned".

## Role-field staleness warning

The `role` field in fleet_inventory is set manually and can lag reality. The `status` field and `notes` are more current. When `role` and `status` conflict (e.g. role=decommissioned_gpu but notes say "verified online 2026-05-28"), trust the notes + status, not the role.

## Cross-references

- fleet-state MCP `fleet_inventory` tool — canonical host status
- fleet-state MCP `fleet_act mark_host_status` — how to update status
- Artemis recovery doc: /Users/rubenmajor/Desktop/ARTEMIS_MASTER_RECOVERY_AND_70B.md
- Ideas #6837, #7759 — Artemis revival tracking

## Last updated

2026-06-04 — initial. Source: Cline completion wrote "Artemis decommissioned" (wrong). Fleet-state showed degraded + active revival ideas = failover, not decommissioned. Correction written to HANDOFF_NOTES.