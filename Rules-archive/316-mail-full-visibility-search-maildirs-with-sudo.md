# 316 — Never claim an email does not exist until you have searched the Maildirs with sudo

Source incident: 2026-08-10. Ruben asked whether DSHS had acknowledged the TPIA
requests. The agent queried `admin_portal.email_inbound_log`, found 101 DSHS
messages and zero acknowledgements, and reported "the Department has never once
written back about a records request." That was **false**. DSHS had sent **seven**
acknowledgements with assigned ORR numbers, all sitting in `rmajor@`'s Maildir on
WOPR. Ruben produced a screenshot proving it. The agent had also reported the send
dates as "unknown" when all nine were in `.Sent/cur` with exact timestamps.

Ruben: "Why can't you see these? Fix why you can't see them... I have seen you be
wishy washy about emails before."

## Root cause

`/var/qmail/mailnames/<domain>/<user>/Maildir` is mode **0750 popuser:popuser**.
Every non-sudo `grep`/`ls`/`find` against it returns **empty with exit 0** — it
looks identical to "no such email exists." The agent never saw a permission error,
so it never suspected one.

Compounding it: `admin_portal.email_inbound_log` ingests **`info@emsuniversity.com`
only**. Positive control on 2026-08-10: 123,682 rows, **zero** with `rmajor` in
`to_email`. Any mail sent from or received at an individual mailbox is structurally
invisible to that table.

## The rule

**Before writing any sentence of the form "no email exists," "they never
responded," "there is no record of X being sent," or "the DB shows no
acknowledgement," you MUST run the mail search tool against the Maildirs.**

```
ssh_command: sudo /usr/local/bin/emsu_mail_search.sh \
  --pattern '<address or subject fragment>' \
  [--mailbox rmajor] [--folder all|inbox|sent] [--headers] [--limit 50] [--cold]
```

`--folder all` covers `cur`, `new`, `.Sent`, and `.Archive`. `--cold` extends the
search to `/data/cold_storage`, `/data/cold-archives`, `/data/cold_misc`, and
`/backup`. Omit `--mailbox` to sweep **all ~271 mailboxes** on the domain.

### Three-source rule for any mail-existence claim

A negative claim is only valid after all three come back empty:

1. `email_inbound_log` / `email_outbound_log` — **info@ only**, never sufficient alone
2. `emsu_mail_search.sh --folder all` — the individual Maildirs, requires sudo
3. `emsu_mail_search.sh --cold` — archived and backup stores

If you searched only source 1, the honest sentence is "no record in the info@ log,
which does not cover individual mailboxes," not "no record exists."

## Positive control (rule 299) is mandatory

Before trusting a zero result, prove the instrument can see anything at all. Search
for a term you KNOW is present in that mailbox. Zero hits on the control means the
search is broken or permission-blocked, not that the target is absent.

Concretely: a `grep` on a Maildir that returns 0 hits **and** 0 errors, without
sudo, is a **permissions artifact**, not evidence.

## Why the agent got fooled

`grep -rl` on an unreadable directory prints nothing and exits 0. There is no
"permission denied" on stderr when the *parent* directory blocks traversal. The
absence of an error message was read as the absence of data. Silence from a
blocked instrument is not a finding.

## Cross-references

- Rule 299 — negative evidence is not proof; positive-control the instrument
- Rule 297 — classify before alarming; scope the question before quantifying
- Rule 263 — verify-before-claim
- Rule 315 — search the record FIRST (same family: the answer was already written down)

## Deployed artifact

`/usr/local/bin/emsu_mail_search.sh` on WOPR, mode 755, deployed 2026-08-10.
Handles pattern search, mailbox scoping, folder scoping, header extraction,
`--since` date filtering, result limits, and cold-storage inclusion.

## Last updated

2026-08-10 — initial. Source: seven DSHS TPIA acknowledgements reported as
nonexistent because the Maildirs were never searched with sudo.