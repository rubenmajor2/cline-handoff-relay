# Cline Artemis — Incus Container URLs (idea #1738 deployed)

Per-workspace incus containers. Each isolated, 8 GB RAM cap. A runaway one cannot take down its siblings.

## URLs (all HTTP 200, login required)

| # | URL | Container | Internal IP | Login Password |
|---|---|---|---|---|
| 1 | https://emsuniversity.com/emtskills/cline-tempe-1/ | cline-1 | 10.0.100.13 | `3abc3fb636f3c63eec505446` |
| 2 | https://emsuniversity.com/emtskills/cline-tempe-2/ | cline-2 | 10.0.100.203 | `797008e3a8b3266a1b68e144` |
| 3 | https://emsuniversity.com/emtskills/cline-tempe-3/ | cline-3 | 10.0.100.242 | `ebc10c67796b73f1bdaaf22b` |
| 4 | https://emsuniversity.com/emtskills/cline-tempe-4/ | cline-4 | 10.0.100.199 | `492997a32699c37dffa4a28a` |
| 5 | https://emsuniversity.com/emtskills/cline-tempe-5/ | cline-5 | 10.0.100.162 | `38e608935b69c272912d77ac` |
| 6 | https://emsuniversity.com/emtskills/cline-tempe-6/ | cline-6 | 10.0.100.183 | `64b99a5431ce4a5442750771` |
| 7 | https://emsuniversity.com/emtskills/cline-tempe-7/ | cline-7 | 10.0.100.76 | `1cd01f463caaa2c48e39e3a1` |
| 8 | https://emsuniversity.com/emtskills/cline-tempe-8/ | cline-8 | 10.0.100.182 | `06f0056d9a179f9822dcb467` |
| 9 | https://emsuniversity.com/emtskills/cline-tempe-9/ | cline-9 | 10.0.100.64 | `275cbb809a0903026c7fa09f` |

## Old URL (still works, will be retired in Phase 5)

- https://emsuniversity.com/emtskills/cline-tempe/ → main code-server@emsuserver.service on Artemis (NOT a container)

## What each container has

- code-server v4.118.0 + Cline extension
- 55 .clinerules (bind-mounted from `/home/emsuserver/Documents/Cline/Rules/`)
- 414 shared cline tasks (bind-mounted from `/home/emsuserver/.local/share/cline-tasks-shared/`)
- Same Anthropic API key (pushed by Phase 2 script)
- `claude-opus-4-7:1m` configured

## SSH (for direct inspection / debugging)

The Mac `~/.ssh/config` already has `cline-1..9` host entries with `ProxyJump artemis`:

```bash
ssh cline-3   # SSH directly into the cline-3 container as root
```

Bind mounts inside containers are at:
- `/home/emsuserver/Documents/Cline/Rules/` (rules)
- `/home/emsuserver/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/tasks/` (tasks)

## Architecture details

- Containers run on Artemis incus bridge `10.0.100.0/24`
- Public access: WOPR nginx → Artemis WG IP `10.100.0.5:8081-8089` → DNAT to container `:8080`
- DNAT rules persisted in `/etc/iptables/rules.v4.cline-incus` + restored on boot via `cline-incus-iptables.service`
- Per-container systemd: `code-server@emsuserver.service` (runs as `emsuserver` UID 1001)

## Phase status (idea #1738)

- [x] Phase 1 POC (5/9 00:39 PT)
- [x] Phase 2 fan-out + Phase 2-fixup (5/10 00:04 PT) — code-server now running in all 9 as emsuserver
- [x] Phase 3 cutover (5/10 00:05 PT) — DNAT + nginx route for cline-tempe-9, all 9 URLs verified HTTP 200
- [x] Phase 4 cleanup (5/10 00:48 PT) — per-container passwords rotated, watchdog audit complete, all watchdogs KEPT for now
- [ ] Phase 5 cutover (deferred 1-2 weeks) — stop code-server@emsuserver.service, retire redundant watchdogs

## Last updated

2026-05-10 00:48 PT — Phase 4 cleanup complete, idea #1738 status=deployed.
