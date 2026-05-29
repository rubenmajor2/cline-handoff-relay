# 130 — "Copycat" is a named bug. The word is a trigger → run THIS playbook immediately.

## Why this rule exists

2026-05-28: Ruben said "copycat" in the very first message of a task and again mid-task. Cline did not act on the word as a named-bug trigger for the first TWO rounds — it treated "copycat" as a generic adjective and kept investigating the surface symptom (executor throughput) instead of the specific failure class Ruben was naming. Ruben: *"I said copycat before and you didn't get it the first or second round. Why?"*

The answer: "copycat" is a SPECIFIC named bug in the EMSU codebase (it's in `cron_ruben_implement.php` comments as `THE COPYCAT`, in KAIZEN recipe #128, and in the `safe_deploy_clobber_incidents` table). But there was no clinerule mapping the word to its playbook, so the agent didn't recognize it as a precise diagnostic pointer. This rule fixes that.

## What "copycat" means (the named bug)

**The RUBEN implementation engine (`cron_ruben_implement.php` + `cron_ruben_autonomous.php`) repeatedly rewrites the SAME production file(s)** — leaving forged `.bak-ruben-impl-*` backups, mutating files 8-13x/day, reverting prior human fixes, and adding colliding/duplicate code (e.g. duplicate function declarations across `routes/_view_*.php` that fatal `reports.php`). First major incident 2026-05-14 (173 files clobbered over 2 weeks). Resurfaced 2026-05-28.

Symptoms Ruben describes in plain language → all mean "copycat":
- "reports.php is flooded with garbage / no header / no content cards"
- "the executor keeps overwriting/clobbering files"
- "my fix got reverted again"
- "pages are breaking after deploys"
- "too many baks" / "files keep changing"

## The trigger rule

**If Ruben says "copycat" (or any symptom above), the FIRST moves are this playbook — do NOT treat it as a generic word:**

1. **Check the gate state both ways:**
   - `ls -la /tmp/ruben_implement_routes_blocked` (sentinel)
   - `mysql ... SELECT JSON_UNQUOTE(JSON_EXTRACT(config_json,'$.ruben_implement_routes_gate')) FROM orchestrator_config WHERE id=1` (DB flag)
2. **Count recent clobbers:** `find /var/www/emtskills -name '*.bak-ruben-impl-*' -mmin -120 | sed 's/.bak.*//' | sort | uniq -c | sort -rn | head` — any file with count ≥3 in 2h IS the copycat actively running.
3. **Check the churn ledger:** `SELECT target_path, COUNT(*) FROM ruben_impl_file_churn_ledger WHERE deployed_at > NOW()-INTERVAL 24 HOUR GROUP BY target_path HAVING COUNT(*)>=3`
4. **For reports.php specifically (the #1 copycat victim):**
   - `php -l routes/reports.php` AND curl it: `curl -s https://emsuniversity.com/emtskills/routes/reports.php | grep -ciE 'Fatal|Cannot redeclare|Parse error'`
   - The two classic breakages: (a) unconditional `ob_start()` near line ~20 whose `ob_end_clean()` discards all card HTML → blank/no-header page; (b) a copycat-added `routes/_view_*.php` declaring a function name that COLLIDES with another view → `Cannot redeclare` fatal → HTTP 500.
   - Restore from the newest verified-good backup (look for `reports.php.bak-*-cline-*`, NOT `.bak-ruben-impl-*` which are copycat-made).
5. **Check `safe_deploy_clobber_incidents` + KAIZEN:** `SELECT * FROM safe_deploy_clobber_incidents ORDER BY created_at DESC LIMIT 5` and search KAIZEN for recipe #128.

## The core-fix mandate (rule 92 applies)

Don't just restore the file (bandaid). Each time copycat fires, ALSO verify/extend the guards in `cron_ruben_implement.php`:
- Per-file churn cap (`ruben_impl_file_churn_ledger`, default 3/24h) — consider cap=1 for aggregator pages
- Aggregator-health guard — after deploying any `routes/_view_*.php`, curl `reports.php` and roll back the view if it 500s
- Function-name uniqueness — copycat loves to emit duplicate `handleConfigUpdate()`-style helpers across views

## How Ruben can tell me faster (his question, answered)

Ruben asked how to flag this better. Best signals, in order:
1. Just say **"copycat"** — now that this rule exists, that word alone triggers the playbook above. (It should have the first time; that was the bug.)
2. If you want to be extra clear: **"copycat hit reports.php"** or **"the executor is clobbering files again."**
3. Name the file if you know it: **"copycat broke reports.php"** → go straight to step 4.

The fix for the miss wasn't your wording — it was that the agent had no rule binding the word to the playbook. This rule is that binding.

## Last updated

2026-05-28 — created after Cline missed "copycat" as a named-bug trigger twice in one task. Source: Ruben directive "I said copycat before and you didn't get it the first or second round. Why?"
