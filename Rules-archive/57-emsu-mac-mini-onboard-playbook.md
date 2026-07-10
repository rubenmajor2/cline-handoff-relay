# 57 — EMSU Mac Mini onboard playbook (one-liner reverse-tunnel pilot)

Permanent rule. Workspace-scoped. Source: 2026-05-18 cline_austin-mac-mini-pilot,
Ruben directive 23:58 PT: *"Are you gonna put this information in the MCP
somewhere or with Fleet agent documentation or what I need to make sure that
you remember this and have to set them up so it's quicker. Maybe potentially
put it in the MDM section as well?"*

This rule captures everything needed to onboard a fresh Mac mini into the
EMSU Mac-mini-slave-network in **one curl command**, with no MDM dependency.
The mini becomes reachable from Ruben's Mac via ProxyJump through WOPR.

## The one-liner

Paste on the new Mac mini's Terminal:

```
curl -fsSL emsuniversity.com/m | bash
```

That's the whole onboard. It will:
1. Prompt for the Mac's local user password ONCE (caches sudo for the run)
2. Enable Remote Login (SSH server)
3. Add Ruben's pubkey to `~/.ssh/authorized_keys`
4. Drop the shared `minitun` private key
5. Trust WOPR's host key
6. Install a launchd job that maintains a reverse SSH tunnel WOPR:<port> → mini:22
7. Set power management: **never sleep, Wake-on-LAN on, Power Nap on, network-over-sleep on**
8. POST device specs to WOPR (chip, RAM, disk, macOS, gpu_cores, brew/ollama/wg installed flags, power state)
9. Print the assigned tunnel port

## Why these power settings matter

Mac mini default sleeps after 10 min idle → reverse tunnel drops → mini becomes
unreachable until someone walks up and clicks the mouse. Bad for a 24/7
slave-network node. /m sets:

| Setting | Value | Why |
|---|---|---|
| `sleep` | 0 | Never sleep the whole machine |
| `displaysleep` | 0 | Never sleep display (avoids weird wake-glitches) |
| `disksleep` | 0 | Keep disks spinning so ollama loads stay warm |
| `womp` | 1 | Wake-on-magic-packet from network |
| `powernap` | 1 | Periodic wake to run scheduled tasks |
| `networkoversleep` | 1 | Network stays connected even during display-off |
| `tcpkeepalive` | 1 | TCP connections survive brief sleeps |
| `standby` | 0 | Disable hibernate (M-series doesn't need it; just keeps it awake) |
| `autopoweroff` | 0 | Disable autopoweroff after long idle |
| `setcomputersleep Never` | — | Belt-and-suspenders on top of `sleep 0` |
| `setwakeonnetworkaccess on` | — | Belt-and-suspenders on top of `womp 1` |
| `setrestartfreeze on` | — | Auto-restart on system freeze |
| `setrestartpowerfailure on` | — | Auto-restart after power loss |

## To SSH into a registered mini from Ruben's Mac

```
ssh -J wopr -p <PORT> <local_user>@localhost
```

Or add to `~/.ssh/config`:

```
Host austin
  HostName localhost
  Port 23465
  User austininstructor1
  ProxyJump wopr
  StrictHostKeyChecking accept-new
```

Then just: `ssh austin`

Find any mini's assigned port:

```sql
SELECT JSON_EXTRACT(payload_json, '$.tunnel_port') AS port, JSON_EXTRACT(payload_json, '$.local_user') AS user
FROM mini_pilot_devices WHERE user_label LIKE '%<name>%' ORDER BY id DESC LIMIT 1;
```

Or via the MCP: `cQ7Tdr0mcp0fetch_data` against `mini_pilot_devices`.

## Files involved (the install pipeline)

| File | Purpose |
|---|---|
| `https://emsuniversity.com/m` | The onboard one-liner script (v3) — pubkey + tunnel + power-mgmt |
| `https://emsuniversity.com/d` | Diagnostic — captures tunnel log + launchd state + posts to WOPR for inspection |
| `/var/www/emtskills/api/mini_pilot_register.php` | API endpoint /m POSTs specs to |
| `/var/www/emtskills/api/mini_pilot_diag.php` | API endpoint /d POSTs diag to |
| `admin_portal.mini_pilot_devices` | Device inventory table |
| `admin_portal.mini_pilot_diag` | Diagnostic history |
| WOPR user `minitun` | Tunnel-only account; receives the reverse SSH |

## The bright-line rules

1. **Never directly install onboard scripts via MDM** — keep /m as the
   canonical, version-controlled, auditable script. MDM can DELIVER the
   one-liner (push a config that runs `curl -fsSL emsuniversity.com/m | bash`
   on first login), but the script's body lives on WOPR.
2. **Power management is non-negotiable** — every mini onboarded must end
   with `sleep=0`. If a future onboard adds Apple silicon hibernate or new
   pmset keys, add them here AND to /m.
3. **The minitun private key shipped in /m is tunnel-only.** It's locked on
   WOPR side to `command=""` style restrictions in sshd_config — even if
   the key leaks, it can only open a reverse port, can't shell on WOPR.
4. **Ruben's personal SSH pubkey is what authorizes ProxyJump into the mini.**
   So losing the minitun key = tunnel goes down. Losing Ruben's key = lose
   access to every mini. Rotate Ruben's key carefully.
5. **Don't enable autologin to the local user account on the mini.** Per
   .clinerules/27 trust posture: the mini boots, sshd starts on its own
   (Remote Login = LaunchDaemon, not user-session), tunnel comes up. No
   physical login needed.

## When this rule does NOT apply

- Mac minis that need to be developer machines for staff (not slave-network
  nodes) — those need a normal MDM-managed user experience, not /m.
- Linux servers (Artemis, Joshua) — those have their own WireGuard mesh
  setup per .clinerules/27.
- Cloud GPU pods (Runpod) — those follow .clinerules/51 + 84.

## What MDM should do (when we set it up later)

The play with Jon's Apple Business Manager / Jamf instance once it's wired:

1. Enroll each new mini in MDM with a default config profile.
2. The profile pushes a launchd job (or first-boot script) that runs:
   ```
   curl -fsSL https://emsuniversity.com/m | bash
   ```
3. MDM also pushes the sudoers NOPASSWD config so step 7 (power mgmt) doesn't
   need a password prompt on subsequent /m re-runs.
4. MDM should NOT mirror the onboard script body — keep it on WOPR.
5. MDM provides hardware-level remote lock/wipe if a mini gets stolen.

For now (without MDM yet), Jon physically pastes the one-liner once per mini
on first boot. Takes <60 seconds per mini.

## Per-mini bookkeeping after onboard

| Step | Where |
|---|---|
| Specs landed | `mini_pilot_devices` table (auto via API) |
| Tunnel port assigned | `mini_pilot_devices.payload_json.tunnel_port` |
| Local user | `mini_pilot_devices.payload_json.local_user` |
| Power state confirmed | `mini_pilot_devices.payload_json.power_sleep/displaysleep/womp` |
| `~/.ssh/config` Host entry added | Ruben's Mac (manual one-time) |
| Fleet Agent awareness | Idea #5162 — pending implementation |

## Health-check from WOPR (no MDM needed)

```bash
# All registered minis with their tunnel ports
mysql -u adminportal -p... admin_portal -e "
  SELECT id, user_label, hostname,
         JSON_EXTRACT(payload_json, '\$.tunnel_port') AS port,
         JSON_EXTRACT(payload_json, '\$.local_user')  AS user,
         JSON_EXTRACT(payload_json, '\$.ram_gb')      AS ram,
         JSON_EXTRACT(payload_json, '\$.power_sleep') AS sleep_val,
         registered_at
  FROM mini_pilot_devices ORDER BY id DESC"

# Currently listening reverse-tunnels
sudo ss -tlnp 2>/dev/null | grep -E ':23[0-9]{3}'
```

If a mini's tunnel port doesn't appear in `ss`, the mini is sleeping or
unreachable. Re-run /m via console paste on the mini fixes it.

## Cross-references

- .clinerules/27 — WireGuard trusted-device posture (different scale of trust,
  same shape)
- .clinerules/29 — agents act on confidence tier (this rule lives here because
  the onboard one-liner is high-confidence + reversible + small blast)
- .clinerules/40 — Artemis Ollama baseline (Mac minis are the local-first
  layer that takes pressure off Artemis + Anthropic)
- .clinerules/84 — Mac local before cloud (Mac minis are the local that comes
  before Runpod for inference)
- .clinerules/95 — 30s tool wall + scp + nohup (used to test /m + /d remotely)
- orchestrator_idea #5144 — original Mac mini pilot
- orchestrator_idea #5162 — teach Fleet Agent about Mac minis (P1, approved)
- mini_pilot_devices, mini_pilot_diag — the runtime tables

## Source incident

2026-05-18 — Austin Mac mini at Jon's house. First mini onboarded via /m
in production. Bugs found and fixed same session:
- Bug 1: /m line 51 missing `mkdir -p ~/Library/LaunchAgents` (LaunchAgents
  dir doesn't exist on fresh macOS) → patched
- Bug 2: /d used python3 which triggered xcode-select install dialog on
  fresh mini → rewrote with perl JSON::PP
- Enhancement (this rule): added power-management block so the tunnel
  stays up overnight when nobody is at the building

End state: Austin = M4, 16GB, port 23465, tunnel UP, never-sleep set,
ProxyJump verified working from Ruben's Mac.

## Last updated

2026-05-19 00:03 PT — initial rule. Ruben directive verbatim:
*"Are you gonna put this information in the MCP somewhere or with Fleet
agent documentation or what I need to make sure that you remember this and
have to set them up so it's quicker. Maybe potentially put it in the MDM
section as well?"*

Lives in: ~/Documents/Cline/Rules/ (canonical, git-tracked via
cline-handoff-relay), synced hourly to Artemis ~/Documents/Cline/Rules/
so every Cline session anywhere has it.


## 2026-05-19 addendum — smart-loop pipeline (writeback + RAG enrichment + LoRA retrain)

The Mac-mini compute pool is no longer just "distributed grinding." It's the
front-end of the EMSU LLM smart-loop. Adding a mini doesn't just add throughput,
it makes the production AI smarter every week.

### The pipeline (4 stages, all automated)

Stage 1 (produce): Mini worker or Linux worker claims a job from the pool API,
executes it (curl / tesseract / ollama depending on capability), POSTs the
result back to the API.

Stage 2 (writeback): `cron_mini_pool_writeback.php` runs every 5 min, reads
rows from `emsu_compute_jobs` WHERE `status='done'` AND `writeback_processed_at IS NULL`,
and routes each result by workload:

- `cross_judge_backfill` -> `orchestrator_llm_shadow_log.cross_judge_grade`
  + `cross_judge_reason` + `cross_judge_at`, AND seeds `emsu_preference_corpus`
  with the winning text under `source_kind='cross_judge_preferred'`.
- `communication_quality_scan` -> new table `email_quality_scores`. If
  `total < 6/10`, the email body also gets seeded into
  `emsu_preference_corpus` as `source_kind='negative_example'` so the next
  LoRA retrain learns to avoid that style.
- `pdf_ocr` -> new table `pdf_ocr_text` (with source_kind enum:
  grievance / vaccination / cert / student_doc / other), AND seeds extracted
  text into `emsu_preference_corpus` as `source_kind='student_document'`
  so RAG can retrieve it.
- `link_probe` -> new table `link_health` (url_hash unique, ok_count,
  fail_count, flagged_at). If a broken link appears in `email_outbound_log`
  body in the last 30 days, the row gets `flagged_at=NOW()` and an
  `orchestrator_event_log` row is filed at severity=warning.

After writeback, each job's `writeback_processed_at` is stamped so the next
run skips it. Idempotent — re-running is safe.

Stage 3 (RAG enrichment): the existing OpenAI embedding cron picks up new
`emsu_preference_corpus` rows where `embedded_at IS NULL`, computes
embeddings, and stores them in `embedding_blob`. RAG retrieval gets richer
automatically — zero new code needed for stage 3.

Stage 4 (weekly LoRA retrain): idea #5229 (P1, approved). Sunday Artemis cron
queries the last-7d corpus rows, runs a LoRA training pass on Artemis B70
GPUs, smoke-tests the new adapter, and on pass deploys via `ollama create
emsu-qwen2.5-coder:7b-lora-YYYY-MM-DD`. Updates `orchestrator_llm_routes`
to point production at the new adapter. Monday morning email to Ruben with
the week-over-week win-rate delta.

### What this gives the production AI

- Every cross-judge result = one more preferred-completion training pair
- Every low-quality email = one more "avoid this style" negative example
- Every OCR'd grievance / vax form = one more RAG-retrievable document
- Every broken link in outbound email = one more flag for Vicky review

Corpus grows roughly 1000-5000 rows/week per active mini. With 4 minis live
that's 4K-20K rows/week — meaningful weekly LoRA improvement.

### Schema reference

| Table | Purpose |
|---|---|
| `admin_portal.emsu_compute_jobs` | Job queue (workload, payload_json, status, result_json, writeback_processed_at — added 2026-05-19) |
| `admin_portal.emsu_compute_workloads` | Workload registry + capability flags (needs_ollama / needs_tesseract / needs_whisper) |
| `admin_portal.email_quality_scores` | Target for communication_quality_scan |
| `admin_portal.pdf_ocr_text` | Target for pdf_ocr |
| `admin_portal.link_health` | Target for link_probe (with flagged_at for ticket review) |
| `admin_portal.emsu_preference_corpus` | RAG + LoRA training corpus (writeback uses meta_tagged_by='mini_pool_writeback') |

### Cron stack (www-data crontab)

```
*/5 * * * * /usr/bin/php /var/www/emtskills/cron/cron_mini_pool_refill.php > /dev/null 2>&1
*/5 * * * * /usr/bin/php /var/www/emtskills/cron/cron_mini_pool_writeback.php >> /var/log/cron_mini_pool_writeback.log 2>&1
```

Refill scans the EMSU stack for new jobs; writeback drains completed jobs
into the smart-loop tables.

### Dashboard

https://emsuniversity.com/emtskills/routes/lora_fleet.php?tab=minis now shows
(2026-05-19 patch by cline_pool_widget_2026_05_19):

- Live queue depth, in-flight count, done-24h, written-back-24h, live-workers (last 10 min)
- Per-workload table: queued / claimed / done-24h / written-back-24h / failed / done-total
- Active workers table: worker name, jobs/24h, throughput (jobs/hr), last-seen, live/idle status

That's the visibility layer for the smart-loop. Refresh the page anytime to
see what the pool just produced.

### When does this rule fire for next Cline?

- **Adding a new mini**: still `curl -fsSL emsuniversity.com/m | bash` per the
  main rule. The /m installer wires the worker via launchd. Nothing else to do.
- **Adding a new workload class**: INSERT row into `emsu_compute_workloads`
  with needs_ollama / needs_tesseract / needs_whisper flags; the worker auto-
  detects caps and only claims jobs it can handle. Then add a writeback handler
  in `cron_mini_pool_writeback.php` to route results to the right smart-loop table.
- **Adding a Linux worker** (Joshua / Houston / future): see idea #5230 for
  the SSH key bootstrap that unblocks the apt-install + systemd-unit playbook.
- **Tuning LoRA retrain**: see idea #5229.

### Cross-references (smart-loop)

- orchestrator_idea #5178 — original compute pool architecture (P0, approved)
- orchestrator_idea #5229 — weekly LoRA retrain pipeline (P1, approved)
- orchestrator_idea #5230 — Joshua / Houston SSH key bootstrap (P1, approved)
