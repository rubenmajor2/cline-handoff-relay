# 116 — TCP open is not service alive: HTTP-probe before declaring a fleet host healthy

Permanent rule. Workspace-scoped. Source: 2026-05-26 SMS-Mac MLX silent fail.

## The bright-line rule

**Before declaring any EMSU fleet host "healthy" (or pulling status from a TCP probe), do a real HTTP GET on the serving endpoint and require a 2xx.** A bound socket is not a working service — the SMS-Mac reverse-tunnel pattern is the canonical false-positive:

- WOPR has sshd bound on `127.0.0.1:11455` (reverse tunnel home for SMS-Mac Ollama)
- When SMS-Mac dies, sshd on WOPR stays LISTEN — TCP probes pass
- Connections move to CLOSE-WAIT / FIN-WAIT — real HTTP returns reset / timeout
- Any cron probing only "is :11455 TCP open" reports SMS-Mac healthy when it's dead

Same pattern with any minitun relay (`76.167.100.188:11456`), any WireGuard-tunneled service, any docker port-forward, any ssh -L tunnel.

## The required pattern

When checking fleet host health from PHP / shell:

- ✅ `curl -sS --max-time 5 http://<host>:<port>/<known-endpoint>` and check both `$code >= 200 && $code < 400` AND `strlen($body) > 0`
- ✅ For Ollama: `/api/tags` returns JSON with model list
- ✅ For MLX-LM: `/v1/models` returns JSON
- ✅ For HTTP services without a free endpoint: `/health` or `HEAD /`
- ❌ `fsockopen($host, $port)` alone → false-positive on stale tunnels
- ❌ `</dev/tcp/$host/$port` alone → same
- ❌ `nc -z $host $port` alone → same

## Application: SMS-Mac dual-service probe

SMS-Mac serves TWO services that fail independently:
- Ollama via `127.0.0.1:11455` (WOPR reverse-tunnel)
- MLX via `76.167.100.188:11456` (minitun relay)

`lib/fleet_inventory_heartbeat.php` (post 2026-05-26 cline patch) probes BOTH and writes `meta_json.services = {ollama: ..., mlx: ...}` so dashboards know which one died.

Cline (and any new agent) MUST:
1. Read `fleet_inventory.meta_json` for SMS-Mac before declaring it "up" for any specific service
2. If your task needs MLX specifically, check `services.mlx === 'healthy'` — `status='healthy'` alone is insufficient
3. If your task needs Ollama specifically, check `services.ollama === 'healthy'`

## Application: Artemis WireGuard

Artemis "up" cannot be inferred from "Ruben says it's powered on." Confirm via:
- `sudo wg show | grep -A2 10.100.0.5` — latest handshake must be < 60s
- `curl --max-time 5 http://10.100.0.5:11434/api/tags` — real HTTP 200
- `ping -c 2 10.100.0.5` — must answer

If any of those fail, the tunnel is NOT up regardless of physical box state.

## Self-check before any "host X is up" claim

Ask:
1. *"Did I do an HTTP GET on the real serving endpoint?"* If no, the check is incomplete.
2. *"Did I check both http_code AND body length?"* TCP open + HTTP 0 is the classic CLOSE-WAIT signature.
3. *"Am I probing the right endpoint for the service my task needs?"* Ollama-up does not imply MLX-up.

## Cross-references

- .clinerules/29 (act on confidence tier — TCP probes are not high confidence, HTTP is)
- .clinerules/92 (work at the core not bandaids — fix the probe, don't patch fleet_inventory by hand)

## Source incident

2026-05-26 ~10:50-11:26 PT.
- Ruben asked Cline to verify SMS-Mac. fleet_inventory said `degraded` (correctly stale). But TCP probe of WOPR:11455 returned OPEN (sshd bound). Real HTTP GET timed out → tunnel was dead all along.
- Same pattern: Ruben said "Artemis is back online." WG handshake was 1h19min stale. The box may have been on, but the tunnel was not up.
- Fix: `lib/fleet_inventory_heartbeat.php` extended to HTTP-probe both Ollama + MLX endpoints on SMS-Mac and write per-service status to meta_json. Filed P0 ideas for the physical recovery actions.

## Last updated

2026-05-26 — initial rule. Source: SMS-Mac dead-tunnel + Artemis WG-stale double miss.
