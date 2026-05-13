# 61 — Grievance Disposition Email Mechanics: response_draft is the send field

Permanent rule. Workspace-scoped. Source: 2026-05-12 grievance queue session — 7 grievances approved and DB
fields populated correctly, but 0 emails sent. Root cause: `disposition_summary` was populated instead of
`response_draft`. `gvSendApprovalEmail()` reads `response_draft`. No error is thrown when `disposition_summary`
is written but `response_draft` is empty — the row looks done but no email goes.

## The bright-line rule

**When approving a grievance and writing the student-facing disposition text, the target field is
`grievances.response_draft`. Not `disposition_summary`. Not `response_to_student` (that gets set by
the send function after delivery).**

Field map:
| Field | What it's for | Who writes it |
|---|---|---|
| `response_draft` | Student-facing email body (HTML) — **the send source** | Cline / AI, before send |
| `disposition_summary` | Internal admin summary of the disposition decision | Cline / AI, for staff UI |
| `staff_instructions` | Vicky's specific action items | Cline / AI, for staff UI |
| `response_to_student` | Confirmed sent email body — set AFTER delivery | `gvSendApprovalEmail()` / send script |
| `response_sent_at` | Timestamp of confirmed delivery | `gvSendApprovalEmail()` / send script |

## How to verify before claiming completion

After any DB UPDATE on a grievance disposition, run this check:
```sql
SELECT id, grievance_number,
  response_draft IS NOT NULL AS has_draft,
  LENGTH(response_draft) AS draft_len,
  disposition_summary IS NOT NULL AS has_summary,
  response_sent_at
FROM grievances WHERE grievance_number = '[GRV-NUMBER]';
```
- `has_draft = 1` AND `draft_len > 200` → ready to send
- `response_sent_at IS NOT NULL` → already sent (idempotent guard in `gvSendApprovalEmail()`)

## The kill switch: gv_auto_approve_full_cycle_enabled

`gvSendApprovalEmail()` in `lib/ai_grievance_agent.php` checks
`orchestrator_config.gv_auto_approve_full_cycle_enabled`. When OFF (the default), the function
is a no-op and returns false. **For manual approvals, do NOT rely on `gvSendApprovalEmail()`** unless
the kill switch is confirmed ON.

Instead, for manual disposition sends, use a standalone PHP script that calls `sendEmail()` directly
with `grievance@emsuniversity.com` as from, `info@emsuniversity.com` as BCC. Template lives at
`/tmp/grv_send_approvals.php` from the 2026-05-12 session — copy and adapt.

After the send script runs:
1. `response_draft` is already set (script writes it before sending)
2. `response_to_student` is set by the script after confirmed delivery
3. `response_sent_at` + `response_sent_by` are set
4. An internal `grievance_comments` row is inserted with send confirmation

## Student email resolution

5 of 7 students in the 2026-05-12 batch had NULL `student_email` in the grievances table. The send
script handles this by querying `Students.email` directly — but as a pre-flight, always resolve before
writing `response_draft`:

```sql
SELECT g.id, g.student_email, s.email AS students_email
FROM grievances g
LEFT JOIN Students s ON s.id = g.student_id
WHERE g.grievance_number = '[GRV-NUMBER]';
```

If both are NULL: search Students by name + class_section. If still not found: Vicky must provide before
the email can go out. Never send to a NULL or guessed address.

## Cross-references

- .clinerules/60 — grievance stipulation logic (the policy side)
- `lib/ai_grievance_agent.php::gvSendApprovalEmail()` — the standard send function (kill-switch gated)
- `lib/mailer.php::sendEmail()` — the underlying send (not gated, always live)
- `/tmp/grv_send_approvals.php` — the 2026-05-12 batch send template (copy/adapt for future batches)

## Last updated

2026-05-13 — initial rule. Source: 2026-05-12 grievance queue session where wrong field was populated
and 0 emails went out on 7 approved grievances. PHP CLI send script subsequently confirmed 7/7 delivered.
