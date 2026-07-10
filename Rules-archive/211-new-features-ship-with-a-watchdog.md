# 137 — New features (especially AI send/act gates) ship with a watchdog/self-heal, not just the feature

Source: 2026-06-03 Ruben directive. After Cline fixed the SMS AI replying to natural-language opt-outs ("stop communicating with me"), Ruben said: *"Can you make a watchdog/self-heal for that. Cline rule on new features like this too."* The opt-out gate had silently failed for months because nothing watched it. The feature shipped once and rotted.

## The bright-line rule

**When you build or fix a feature that GATES an autonomous action — anything that decides whether the system sends, replies, charges, suppresses, enrolls, or skips — you also ship a watchdog/self-heal in the SAME session. The gate alone is not done. The gate + the thing that catches the gate regressing is done.**

A "gate" is any conditional that protects a person or money: opt-out suppression, refund caps, do-not-contact, dedup,A "gate" is any conditional that protects a person or money: opt-out suppression, refund caps, do-nottlA "gate" is any conditional that protects a person or money: opt-out suppression, refund caps, do-not-con, aA "gate" is any conditional that protects a person or money: opt-out suppression, refund caps, do-not-contact, dedup,A "gate" is any conditional that protects a person or money: opt-out suppression, refund caps, do-nottlA "gate" is any conditional that protects a person or money: opt-out suppression, refund caps, do-not-con, aA "gate" is any condd AI replies, re-run the opt-out detector on what the recipient last said, and flag any reply that went to someone who asked to stop. The gate and the watchdog must not share the failure mode.
2. **Self-heal the instance.** When it catches one, fix that case automatically (flag the number do-not-contact, void the bad charge, re-suppress). Per rule 92, the watchdog acts, it doesn't just log.
3. **Alert a human that the gate regressed.** discord_notify / ops chat + an orchestrator_event_log row (severity warning/critical). A self-heal that hides the regression is worse than none — the point is to learn the gate broke.

## Required shape (EMSU conventions)

- Cron file `cron/cron_<feature>_watchdog.php`, owned www-data, lint-clean.
- Kill switch in `telephony_config` / relevant config table (auto-create, default on).
- Idempotent + overlap-safe (cron windows overlap; self-heal must be safe to run twice).
- Log to `/var/log/emsu-<feature>-watchdog.log` (create it www-data-owned, or the cron.d `>>` redirect fails with permission denied — verify by running the EXACT cron.d line per rule 29, not a bare `php script.php`).
- Register in `/etc/cron.d/emsu-<feature>-watchdog`.
- Audit row in `orchestrator_event_log` (severity enum is `info|warning|error|critical` — NOT 'high'; verify the schema per rule 17 before INSERT).

## What does NOT need a watchdog

- Pure read-only / reporting features (no ac- Pure read-only / reporting features (no ac- Pure read-only / reporting features (no ac- Pure read-only / reporting features (no ac- Pure read-only / reporting features (no ac- Pure read-only / reporting features (no ac- Pure reae b- Pure read-only / reporting febefore - Pure read-only / reporting features (no ac- PuI build/fix a conditional that protects a person or money?* If yes → continue.
2. *Is there already a watchdog wa2. *Is there already a watchdog wa2. *Is there already a watchdog wa2. *Is there alreom O2. *Is there already a watchdog wa2. *Is there already a watchdog wa2. *Is there already a watchdog wa2. *Is there alreom O2. *Is there already a watchdog wa2. *Is there already a watchdog wa2. *Is there already a wat t2. *Is there already a watchdog wa2. *Is there alree waiting to happen, which is exactly the class Ruben is tired of finding by hand.

## Cross-references

- .clinerules/92 — work at the core (the watchdog self-heals, doesn't just narra- .clinerules/92 — work at the core (the watchdog self-heals, doesn't just narra- .clinerules/92 — work at the core (the watchdog self-heals, doesn't just narra- .clinerules/92 — work at the core (the watchdog self-heals, doesn't just narra- .clinerules/92 — work at the core (the watchdog self-heals, doesn't just narra- .clinerules/92 — work at the core (the watchdog self-heals, doesn't just narra- .clinerules/92 — workx and nothing watched the output. Fix: wired HostileReplyDetector into the send path AND shipped `cron_sms_optout_regression_watchdog.php` (detect-from-output + self-heal do-not-contact + discord alert), registered every 15 min. Ruben: "Cline rule on new features like this too."

## Last updated

2026-06-03 — initial.
