# 122 — WPForms `{query_var key="X"}` smart tags require explicit `query_vars` registration. Don't ever delete `emsu-query-vars-register.php`.

Workspace-scoped. Archived rule. Lookup via `clinerules_lookup(rule_id="122")` or `clinerules_search(query="wpforms query_vars hidden field empty")`. Companion to .clinerules/121 (the source-incident doc).

## The bright-line rule

**`emsu-query-vars-register.php` MUST be present in `wp-content/mu-plugins/` on every EMSU WordPress vhost.** It registers the public query vars (`section`, `track`, `start_date`, `tuition`, `registration_fee`, `course_end_date`, `clock_hours`, `course_change_fee`, `financing_fee`, `total_payment`, `first_name`, `middle_initial`, `last_name`, `email`, `phone`, `address1`, `address2`, `city`, `address_state`, `zip`, `heard_about`, `ssn`, `if_other_nonemt`, `catalog_date`, `signature_date`, `state`, `location`, `course`, `class`) that WPForms 1.9.x's `{query_var key="..."}` smart tag resolves against `get_query_var()`.

Without this mu-plugin: every hidden field on form 3325 / 3292 (EA + CA EA) silently renders with an empty `value` attribute, even when the URL contains the query string. Student submits, webhook can't route them, watchdog can't backfill, 24+ students get stranded in a 2-week window.

## Why this exists

Pre-WPForms 1.9.x, `{query_var key="X"}` had an internal fallback that read `$_GET[X]` directly. Starting in 1.9.x, the smart tag strictly calls `get_query_var()` — which WordPress returns empty for unregistered query vars. That's by design (security — random URL params don't auto-leak into rewrite rules), but it broke EMSU's EA pipeline overnight.

The "shortcode handler" we kept looking for (in active theme `functions.php`, `mu-plugins/`, etc) **does not exist as custom code**. The pre-fill mechanism is stock WPForms reading from `get_query_var()`. The custom EMSU code was always the query-vars registration — and it was apparently never written (or was written in a place that got deleted in a prior cleanup). Result: from WPForms install date until 2026-05-13 plugin auto-update, the smart tag's old `$_GET` fallback masked the missing registration. The update removed the fallback.

## The plugin

`/var/www/vhosts/<vhost>/httpdocs/wp-content/mu-plugins/emsu-query-vars-register.php`. 2.5KB. Single `add_filter('query_vars', ...)` registration of the EMSU param list. Idempotent (uses `in_array` guard). Deployed 2026-05-28 06:18 PT to 41 vhosts. Owner = vhost-specific (matches mu-plugins/ directory owner).

If you ever see `wp-content/mu-plugins/emsu-query-vars-register.php` missing on a vhost, redeploy from `/tmp/emsu-query-vars-register.php` (canonical copy lives there) or grab a sibling vhost's copy.

## Smoke test (per-vhost)

```bash
curl -sL -A "Mozilla/5.0 Chrome/124" \
  "https://<vhost>/enrollment-agreement/?state=Texas&first_name=Smoke&email=smoke@test.invalid&section=26913FT&track=Fast+Track&tuition=1645.00" \
  | grep -oE 'name="wpforms\[fields\]\[(106|67|71)\]"[^>]*'
```

Expect: `name="wpforms[fields][106]" value="26913FT"` etc. If `value=""`, the mu-plugin is missing or another plugin is filtering out our registration. **Note:** the public landing on emsuniversity.com is guarded by `emsu-form-access-guard` — it requires both `first_name` AND `email` params just to reach the form. Smoke-test URLs MUST include both.

## Where the EA URL gets BUILT (and must include section)

| Source | File | Notes |
|---|---|---|
| Email Agent EA-resend tool | `/var/www/emtskills/lib/email_agent/build_ea_url_tool.php` | uses `EA_URL_BASE` constant + `http_build_query` |
| Read-only regen helper | `/var/www/emtskills/lib/ea_url_builder.php` | pulls Students row + builds full URL inc section |
| Agent-tools EA URL helper | `/var/www/emtskills/lib/agent_tools/ea_url_builder.php` | same shape |

All three already include `section` in the query string. The historical break wasn't in URL generation, it was in URL READING (the missing query_vars registration).

## When this rule fires

- Any future "students say they submitted EA but we can't find them" wave
- Any `wpforms_entries` row with empty field 106 + non-empty field 49 (signature) — even one is a 5-alarm signal
- Any complaint about "hidden field empty" / "Section blank in PDF" / "Date of EMT Course missing"
- Any WPForms plugin update on emsuniversity.com or any sister site — RE-RUN the smoke test above on at least 3 vhosts (one CA, one TX, one AZ)
- Any time someone proposes "let's do a mu-plugins cleanup" — do not delete `emsu-query-vars-register.php`

## Defense-in-depth shipped 2026-05-28

1. **Form Access Guard** — already blocks bare /enrollment-agreement/ without first_name+email. Idea #7855 (P1, approved) will tighten it to require section too once we've verified all legitimate inbound flows include it.
2. **Webhook section derivation** — `webhooks/ea_completion.php` line ~328 now derives missing class_section from `Course_Schedules` (location + class_method + start_date proximity ±7 days), then from prior Students row, before bailing. Logs `[ea_webhook] DERIVED class_section=...` on success.
3. **Replay primitive** — `cron/cron_ea_stranded_replay.php` `--auto-discover --lookback=168` runs every 15min via emsuserver crontab. Idempotent.
4. **Watchdog** — `cron/cron_ea_watchdog.php` runs every 15min, auto-invokes the replay primitive when orphans appear.
5. **Auto-update kill** — all 25+ WP sites have WPForms in `auto_update_plugins` removed + `AUTOMATIC_UPDATER_DISABLED` true in wp-config. Per .clinerules/121.

## Cross-refs

- `.clinerules/121` — source incident + canonical pipeline doc (full RCA + runbook)
- `.clinerules/92` — work at the core, not bandaids (this rule IS the core fix)
- `.clinerules/41` — post-deploy call the tool (do not narrate "deploying mu-plugin," just deploy it)
- Orchestrator ideas: #7817 (SHIPPED — the mu-plugin + webhook patch), #7811 (Reconciler rewrite, approved), #7812 (silent-loss class, approved), #7814 (event-sourced EA intake, approved), #7853 (audit fields 67/68/69/70-74 backfill, approved P0), #7854 (Moodle group membership backfill, approved P0), #7855 (Form Access Guard tightening, approved P1)
- Bible doc (auth-gated, MasterAdmin/ITAdmin): https://emsuniversity.com/emtskills/routes/student_status_reference.php

## Last updated

2026-05-28 06:48 PT — initial. Source: cohort-stranding sprint, 24 stranded students, root cause finally identified as missing `query_vars` registration (NOT a custom shortcode handler as we had been chasing all night). Ruben directive: *"these are all so very urgent issues. Please let's act now."* Fix shipped to 41 vhosts in one deploy. Smoke test confirmed live render.
