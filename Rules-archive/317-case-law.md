# Rule 317 Case Law — Full Amendment Trail (trim-then-archive, 2026-08-19)

Moved out of `Rules/317-reversal-triggers-297-and-rule-update.md` to restore G7 12KB
compliance (the file had grown to 16,860 bytes and was FAILING its own lint gate —
verified 2026-08-19 via `.pre-write-lint.sh`). The hardfloor rule keeps the GOLDEN
RULE + NUMBERED HARDFLOOR; this file keeps the mechanical amendment trail.

Cross-refs: Rules/317 (parent), Rules/297 (classify-before-diagnose), Rules/91 (pickup prompt).

## Amendment (from reversal, 2026-08-17 23:37 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786952400
- RCA bucket: insufficient probe
- Trigger pattern: Declaring a credential dead or an artifact unrecoverable after a single failed API probe, without copying the header/endpoint from a script that uses that credential successfully in production, and without trying the remaining retrieval paths.
- Reversal note: I declared "the document was never saved" and "the Postmark token is invalid" after ONE failed probe: I hit /servers with an X-Postmark-Account-Token header, got ErrorCode 10, and concluded the credential was dead post-rotation. The token was fine. The live cron scripts/postmark_inbound_recovery.php uses the same constant as an X-Postmark-Server-Token header, which authenticates and returns 117,435 outbound messages. When Ruben pushed back that PDFs had already been saved in this compliance section, three further paths existed and all were untried: the corrected backfill script, the local Plesk Maildir at /var/qmail/mailnames (readable with sudo -n), and per-mailbox subject search. All five missing complaint PDFs were recovered from the Maildir in under ten minutes. Amendment: rule 317's escalation probe applies to CREDENTIAL and RETRIEVAL failures exactly as it does to EACCES. One auth error against one endpoint with one header is not a dead credential. Before declaring any artifact unrecoverable, copy the working header/endpoint from a production script that uses the same credential and exhaust the alternate retrieval paths.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-18 19:10 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 27205
- RCA bucket: wrong premise
- Trigger pattern: interpreting an upgrade directive as 'repoint handles to the new version' when the new version is not available on the local backend, instead of reporting the local-backend gap and asking how to proceed.
- Reversal note: Fleet-wide GLM repoint: I assumed 'upgrade GLM 5.2 Local everywhere to GLM 5.3' meant repointing local-ring handles to cloud 5.3, because local 5.3 weights are HF 401-gated. The directive actually meant 'upgrade the local ring FROM 5.2 TO 5.3' (download 5.3 weights, requant, relaunch the ring). I converted free-local to paid-cloud, the opposite of intent. Amendment: when a directive says 'upgrade X to Y everywhere' and Y is not yet available locally, the correct response is to REPORT that Y is not available locally and ask whether to wait or proceed with cloud-only, NOT to silently convert free-local lanes to paid cloud. The local ring is a cost-bearing architectural asset; repointing it to paid cloud is a cost inversion that must be surfaced as a decision, not buried in a routing change.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 04:32 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787081272363
- RCA bucket: wrong premise
- Trigger pattern: Emitting non-English (Chinese) narration sentences in assistant messages while working a task about Chinese-origin LLM infrastructure, repeating the violation 8+ times after explicit user correction.
- Reversal note: Ruben flagged Chinese-language narration in my assistant messages 8+ times ("chinese iteration is banned... That's a cline rule", then "You have iterated chinese 8x more times. Stop doing that."). I kept emitting Chinese-language thinking-summary sentences between tool calls. The causal defect: my language selection for user-facing narration was unanchored - I pattern-matched to the task domain (a Chinese-origin LLM stack, GLM/Qwen fleet context) instead of anchoring to the ONE fixed rule: ALL output to Ruben is English, always, in every message, no exceptions for intermediate narration. Amendment: the completion-confidence acquisition gate now includes a LANGUAGE check - before shipping any assistant turn, the language of every user-visible sentence must be English; any non-English narration sentence is a rule violation regardless of technical correctness elsewhere in the turn. English-only is unconditional; domain context never justifies language switching.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 08:46 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: silence-guard-rebase-20260819
- RCA bucket: insufficient probe
- Trigger pattern: chmod/chown hardening applied to a freshly-created credential/config file without checking file ownership vs the consuming process's user, then declaring the hardening done without re-running the consumer.
- Reversal note: Hardening a file I had just created (chmod 640) silently broke the production cron that consumed it: write_server_file had created config/db_config.php as root:root, so removing world-read locked out the PHP/cron user and re-broke the rate cron I had just repaired. Amendment: before chmod/chown/any permission change on a file that a service reads, probe (a) the file's actual owner (ls -la) and (b) the consuming process's user identity (id / PHP-FPM pool user), and after the change re-run the consumer once to confirm it still works. A security-hardening step that is not followed by a consumer re-run is an unverified write like any other.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 08:54 UTC) — DUPLICATE of the 08:46 entry

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787126689836
- RCA bucket: insufficient probe
- Trigger pattern: (identical to the 08:46 entry — same incident recorded under a second task id)
- Reversal note: (identical to the 08:46 entry)

NOTE (2026-08-19 audit): this is a byte-identical duplicate of the 08:46 amendment,
recorded under a different task id. It is the evidence behind idea #27634 [executing]
(clinerules_amend_rule needs content-hash dedup so duplicates fold into a
"reappeared N times" counter instead of appending a full copy).

## Amendment (from reversal, 2026-08-19 19:50 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787123639000
- RCA bucket: insufficient probe
- Trigger pattern: Publishing a Google Drive file id as 'verified' in a completion/PICKUP PROMPT without resolving it live (get_file_info) — the recorded id 18sI3y8y7Q10Cqzl93x37tlYI89m3000_ was stale and invisible until the live resolve.
- Reversal note: Within-window reversal: the consolidated TDSHS response PICKUP PROMPT recorded Drive file id 18sI3y8y7Q10Cqzl93x37tlYI89m3000_ as verified, but a live get_file_info returned 'File not found'. The actual file exists under id 1IwAPEXqYfXB-VGyVqpvB187uF_HbYeUo (found via search_drive by name). Desktop and server PDFs were byte-identical (MD5 070cb39f38eeb9341d43a376fc85a835), so only the Drive id was wrong — but the id was cited as a verified deliverable. Amendment: a Drive file id (like any external id/token) is not 'verified' until a live resolve returns it; publish the id only after an actual API resolve, not from an upload-return captured in a prior turn.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 22:30 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787174702000
- RCA bucket: insufficient probe
- Trigger pattern: Declaring a JS-emitting PHP page verified with 'PHP lint OK' after write_server_file, without a browser-console probe. php -l cannot see embedded-JS syntax errors (missing braces), load-order globals, or incomplete view allowlists.
- Reversal note: Rule 317 verification standard corrected: php -l / write_server_file's PHP lint only checks PHP syntax, so it cannot catch JavaScript errors embedded in heredoc/ENDJS blocks (e.g. missing closing braces that silently kill an entire tail script block), load-order globals (window.bootstrap undefined at mid-page IIFE time), or incomplete view allowlists. On 2026-08-19 Team Hub shipped 'PHP lint OK' twice while the live page threw 'SyntaxError: Unexpected end of input' on every load and the 'My Schedule' pill was dead. Amended rule 317: for any deployed PHP page that emits JavaScript, 'lint OK' is NOT a completion-confidence verification — a real browser-console probe (or JS parse) is REQUIRED before claiming 'console clean / no errors'.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 22:32 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787174702000
- RCA bucket: scope error
- Trigger pattern: Framing the causal fix for a verification gap at tool-chain granularity ('php -l cannot see embedded JS') when the failure class is 'deploy-tool auto-check used as functional verification'. The durable lesson is the generalization, not the one-off.
- Reversal note: Raised the earlier 2026-08-19 amendment from micro (PHP lint cannot verify embedded JS) to the larger principle, per Ruben's steer that one-off/micro fixes miss the durable lesson. A deploy/build tool's automatic success signal (php -l, write_server_file lint+reload, exit code 0, npm build, 'deployed OK') verifies ONLY what that tool checked (syntax of one layer). It is NEVER functional verification of the running deliverable. Claim scope must equal probe scope: any completion claim about user-facing behavior ('console clean', 'page renders', 'flow works', 'pickup clickable', 'no errors') requires a probe of THAT surface this window (browser console, rendered DOM, live HTTP/API response) — never an inference from the deploy tool's auto-check. This supersedes and generalizes the narrower JS-emitting-PHP-page wording added earlier this task.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Source of the 4-mode taxonomy (for the GOLDEN RULE table)

`/var/www/emtskills/docs/317-reversal-corrections.md` — generated 2026-08-14 from 280
catalogued rule-317 gate failures (2026-08-08 through 2026-08-15): MODE 1
SELF_CONTRADICTING_DISPOSITION (251), MODE 2 R317_UNVERIFIED_STATE (24), MODE 3
R317_REVERSAL_LOG (5), MODE 4 PREMATURE_EMAIL_QA_COMPLETION (scope error).

## 2026-08-19 audit (this trim)

Gate scoreboard (trailing 7d, verified via clinerules_gate_scoreboard): the check is ON
(554 validations, 348 blocks). SELF_CONTRADICTING_DISPOSITION is STILL the #1 blocker
(173 blocks/7d) even though its gate exists (idea #25185) — the gate catches it, models
keep emitting it. R317_UNVERIFIED_STATE is #3 overall (70 blocks/7d). Conclusion: the
durable fix is distillation + retrieval (GOLDEN RULE front-load, ideas #27634/#27635),
not more prose. This trim is the small-model half of that fix: the hardfloor file now
carries only the axiom + the numbered mechanics; the trail lives here.