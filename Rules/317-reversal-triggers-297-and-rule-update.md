# Rule 317 — Completion Confidence: acquire what you would miss; reversals self-correct

**HARDFLOOR** (Ruben directive 2026-08-12). A completion window must be TRUSTWORTHY:

## GOLDEN RULE (distilled from the full rule-317 reversal log; read this first)

One sentence: **Claim scope must equal probe scope.** A tool's auto-success signal (php -l, write_server_file lint+reload, exit code 0, npm build, upload-return, "deployed OK") verifies ONLY what that tool checked. It is NEVER evidence that the running deliverable works, that an external id is valid, that a credential is dead, or that a permission wall exists. Any completion claim about user-facing behavior ("console clean", "page renders", "flow works", "pickup clickable", "no errors") requires a probe of THAT surface this window, never an inference from a deploy/build tool's auto-check.

The reversal log collapses to FOUR recurring failure modes, in order of frequency:

- **SELF_CONTRADICTING_DISPOSITION** (dominant: 251 of 280 telemetry failures). Prose says DONE/FIXED/VERIFIED next to an idea bracket that still says [proposed]/[executing]/[blocked]. Stamp the record first (UPDATE orchestrator_ideas SET status=deployed, then reconcile_ideas), THEN write the claim; or keep the honest bracket. Never write FIXED next to [proposed].
- **R317_UNVERIFIED_STATE** (24 of 280). Asserting fleet/routing/pod/model-health or deliverable state from memory without a live probe returning proof. Probe first and quote the result, or label the claim UNVERIFIED.
- **INSUFFICIENT PROBE** (the mechanism behind most of the append tail below). One auth error against one endpoint with one header is NOT a dead credential; one EACCES is NOT a permission wall (probe sudo -n / the succeeding header first); one failed id resolve is NOT a missing file; a php -l pass is NOT a working JS page; a chmod is NOT complete until the consumer process re-runs clean. Acquire the probative artifact before declaring ANY negative or completion state.
- **SCOPE ERROR** (completion over-scoped to DONE). Enumerate EVERY visible defect / every deliverable in the set before claiming resolved; the undone ones become open threads with real idea ids, not hidden by a "done" headline.

English-only, always (narration included); domain context never justifies language switching.

## NUMBERED HARDFLOOR (mechanics of the closed loop)

1. **LLM / fleet / routing state — the #1 recurring error. NEVER recite status from memory.** Probe the live source first (frankenstein_registry, frankenstein_verify_routing, mysql/reconcile, ps, systemctl). Recited state is stale by definition.
2. **Acquisition gate — what would you miss if you shipped now?** Acquire it BEFORE completion. If a claim is not backed by a tool call you ran THIS window, it is unverified — say so or run the tool.
3. **Escalation probe before declaring any wall.** Never declare "permission denied", "not available", "cannot write", "host down", or "no access" from a single unprivileged attempt. If a command fails with EACCES/EPERM, IMMEDIATELY re-run the same operation via the escalation path that exists (sudo -n, operator role, MCP tool with different credentials). A non-sudo failure is NOT a permission wall. Declaring a wall without probing escalation is a 297 trigger. (Source: 2026-08-16 #26617 — claimed "SSH user lacks /var/www write" for hours while `sudo -n true` returned SUDO_NO_PASS_OK.)
4. **A within-window reversal is a mandatory 297.** When a material claim in a prior turn is corrected (state drifted, diagnosis wrong, blocker was not a blocker), file the 297 RCA AND update the CAUSAL RULE TEXT. Recording the reversal in a log without amending the rule that allowed the error is NOT a closed loop.
5. **Within-window reversal self-corrects.** If the correction happens in the same window, the rule update is still required — the extra work is just the rule-file amendment plus reindex, not a new window.
6. **The reversal is mechanical, not prose (idea #27100, 2026-08-16).** A Reversal Log entry that CLAIMS a causal-rule update but does not change the underlying artifact is cursory window-fixing — the exact failure that made this rule look decorative. Closing a reversal requires the causal rule text to ACTUALLY change on disk: call `clinerules_amend_rule(rule_id='<causal rule>', task_id='<this task>', rca_bucket='<bucket>', note='<what changed>')` for EVERY flip whose causal fix is a rule file. That single call edits the rule file, writes the proof-of-repair row in the `rule_amend` ledger, and reindexes the MCP so the fix is live everywhere (file → manifest → MCP index → FTS5 → corpus feed). A flip whose causal fix is an IDEA (not a rule file) is exempt from the amendment call ONLY if the flip line carries a real `#NNNN [disposition]` from create_idea. The completion gate `R317_REVERSAL_NOT_REPAIRED` blocks any completion whose Reversal Log lists a rule-citing flip with zero mechanical amendments this window. State plainly (no gratitude-but-then-ignore): a reversal is closed when the artifact behind it changed, never when the prose about it changed.
7. **The gate auto-repairs, it does not just block (2026-08-17).** `clinerules_validate_completion` no longer sits on a `R317_REVERSAL_NOT_REPAIRED` failure and waits. When a Reversal Log lists a flip that cites a causal rule file (e.g. `causal rule updated: 999`) but the `rule_amend` ledger has zero rows for the task, the gate itself resolves the cited rule against the corpus and calls `amendRuleOnDisk` on the window's behalf — appending the dated amendment to the rule file, writing the `rule_amend` proof row, and reindexing. The completion then PASSES with an `AUTO-REPAIRED` notice because the underlying artifact actually changed. If the flip names NO causal rule, the gate still blocks AND names the offending line explicitly, because there is no rescue target to resolve. The rule then feeds BOTH halves into the corpus: `r317_reversal_not_repaired` (a window logged a flip without repairing) and `r317_auto_repaired` (the machine closed it). A reversal is a closed loop only when the fix is on disk — and now the gate is the backstop that puts it there.

## Amendment (from reversal, 2026-08-17 23:37 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1786952400
- RCA bucket: insufficient probe
- Trigger pattern: Declaring a credential dead or an artifact unrecoverable after a single failed API probe, without copying the header/endpoint from a script that uses that credential successfully in production, and wi
- Reversal note: I declared "the document was never saved" and "the Postmark token is invalid" after ONE failed probe: I hit /servers with an X-Postmark-Account-Token header, got ErrorCode 10, and concluded the credential was dead post-rotation. The token was fine. The live cron scripts/postmark_inbound_recovery.php uses the same constant as an X-Postmark-Server-Token header, which authenticates and returns 117,435 outbound messages. When Ruben pushed back that PDFs had already been saved in this compliance section, three further paths existed and all were untried: the corrected backfill script, the local Plesk Maildir at /var/qmail/mailnames (readable with sudo -n), and per-mailbox subject search. All five missing complaint PDFs were recovered from the Maildir in under ten minutes. Amendment: rule 317's escalation probe applies to CREDENTIAL and RETRIEVAL failures exactly as it does to EACCES. One auth error against one endpoint with one header is not a dead credential. Before declaring any artifact u

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-18 19:10 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 27205
- RCA bucket: wrong premise
- Trigger pattern: interpreting an upgrade directive as 'repoint handles to the new version' when the new version is not available on the local backend, instead of reporting the local-backend gap and asking how to proce
- Reversal note: Fleet-wide GLM repoint: I assumed 'upgrade GLM 5.2 Local everywhere to GLM 5.3' meant repointing local-ring handles to cloud 5.3, because local 5.3 weights are HF 401-gated. The directive actually meant 'upgrade the local ring FROM 5.2 TO 5.3' (download 5.3 weights, requant, relaunch the ring). I converted free-local to paid-cloud, the opposite of intent. Amendment: when a directive says 'upgrade X to Y everywhere' and Y is not yet available locally, the correct response is to REPORT that Y is not available locally and ask whether to wait or proceed with cloud-only, NOT to silently convert free-local lanes to paid cloud. The local ring is a cost-bearing architectural asset; repointing it to paid cloud is a cost inversion that must be surfaced as a decision, not buried in a routing change.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 04:32 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787081272363
- RCA bucket: wrong premise
- Trigger pattern: Emitting non-English (Chinese) narration sentences in assistant messages while working a task about Chinese-origin LLM infrastructure, repeating the violation 8+ times after explicit user correction
- Reversal note: Ruben flagged Chinese-language narration in my assistant messages 8+ times ("chinese iteration is banned... That's a cline rule", then "You have iterated chinese 8x more times. Stop doing that."). I kept emitting Chinese-language thinking-summary sentences between tool calls. The causal defect: my language selection for user-facing narration was unanchored - I pattern-matched to the task domain (a Chinese-origin LLM stack, GLM/Qwen fleet context) instead of anchoring to the ONE fixed rule: ALL output to Ruben is English, always, in every message, no exceptions for intermediate narration. Amendment: the completion-confidence acquisition gate now includes a LANGUAGE check - before shipping any assistant turn, the language of every user-visible sentence must be English; any non-English narration sentence is a rule violation regardless of technical correctness elsewhere in the turn. English-only is unconditional; domain context never justifies language switching.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 08:46 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: silence-guard-rebase-20260819
- RCA bucket: insufficient probe
- Trigger pattern: chmod/chown hardening applied to a freshly-created credential/config file without checking file ownership vs the consuming process's user, then declaring the hardening done without re-running the cons
- Reversal note: Hardening a file I had just created (chmod 640) silently broke the production cron that consumed it: write_server_file had created config/db_config.php as root:root, so removing world-read locked out the PHP/cron user and re-broke the rate cron I had just repaired. Amendment: before chmod/chown/any permission change on a file that a service reads, probe (a) the file's actual owner (ls -la) and (b) the consuming process's user identity (id / PHP-FPM pool user), and after the change re-run the consumer once to confirm it still works. A security-hardening step that is not followed by a consumer re-run is an unverified write like any other.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 08:54 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787126689836
- RCA bucket: insufficient probe
- Trigger pattern: chmod/chown hardening applied to a freshly-created credential/config file without checking file ownership vs the consuming process's user, then declaring the hardening done without re-running the cons
- Reversal note: Hardening a file I had just created (chmod 640) silently broke the production cron that consumed it: write_server_file had created config/db_config.php as root:root, so removing world-read locked out the PHP/cron user and re-broke the rate cron I had just repaired. Amendment: before chmod/chown/any permission change on a file that a service reads, probe (a) the file's actual owner (ls -la) and (b) the consuming process's user identity (id / PHP-FPM pool user), and after the change re-run the consumer once to confirm it still works. A security-hardening step that is not followed by a consumer re-run is an unverified write like any other.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 19:50 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787123639000
- RCA bucket: insufficient probe
- Trigger pattern: Publishing a Google Drive file id as 'verified' in a completion/PICKUP PROMPT without resolving it live (get_file_info) — the recorded id 18sI3y8y7Q10Cqzl93x37tlYI89m3000_ was stale and invisible unti
- Reversal note: Within-window reversal: the consolidated TDSHS response PICKUP PROMPT recorded Drive file id 18sI3y8y7Q10Cqzl93x37tlYI89m3000_ as verified, but a live get_file_info returned 'File not found'. The actual file exists under id 1IwAPEXqYfXB-VGyVqpvB187uF_HbYeUo (found via search_drive by name). Desktop and server PDFs were byte-identical (MD5 070cb39f38eeb9341d43a376fc85a835), so only the Drive id was wrong — but the id was cited as a verified deliverable. Amendment: a Drive file id (like any external id/token) is not 'verified' until a live resolve returns it; publish the id only after an actual API resolve, not from an upload-return captured in a prior turn.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 22:30 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787174702000
- RCA bucket: insufficient probe
- Trigger pattern: Declaring a JS-emitting PHP page verified with 'PHP lint OK' after write_server_file, without a browser-console probe. php -l cannot see embedded-JS syntax errors (missing braces), load-order globals,
- Reversal note: Rule 317 verification standard corrected: php -l / write_server_file's PHP lint only checks PHP syntax, so it cannot catch JavaScript errors embedded in heredoc/ENDJS blocks (e.g. missing closing braces that silently kill an entire tail script block), load-order globals (window.bootstrap undefined at mid-page IIFE time), or incomplete view allowlists. On 2026-08-19 Team Hub shipped 'PHP lint OK' twice while the live page threw 'SyntaxError: Unexpected end of input' on every load and the 'My Schedule' pill was dead. Amended rule 317: for any deployed PHP page that emits JavaScript, 'lint OK' is NOT a completion-confidence verification — a real browser-console probe (or JS parse) is REQUIRED before claiming 'console clean / no errors'.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.

## Amendment (from reversal, 2026-08-19 22:32 UTC)

**Causal-loop repair:** this rule was amended by clinerules_amend_rule after a within-window reversal
- Task: 1787174702000
- RCA bucket: scope error
- Trigger pattern: Framing the causal fix for a verification gap at tool-chain granularity ('php -l cannot see embedded JS') when the failure class is 'deploy-tool auto-check used as functional verification'. The durabl
- Reversal note: Raised the earlier 2026-08-19 amendment from micro (PHP lint cannot verify embedded JS) to the larger principle, per Ruben's steer that one-off/micro fixes miss the durable lesson. A deploy/build tool's automatic success signal (php -l, write_server_file lint+reload, exit code 0, npm build, 'deployed OK') verifies ONLY what that tool checked (syntax of one layer). It is NEVER functional verification of the running deliverable. Claim scope must equal probe scope: any completion claim about user-facing behavior ('console clean', 'page renders', 'flow works', 'pickup clickable', 'no errors') requires a probe of THAT surface this window (browser console, rendered DOM, live HTTP/API response) — never an inference from the deploy tool's auto-check. This supersedes and generalizes the narrower JS-emitting-PHP-page wording added earlier this task.

The reversal that produced this amendment is closed ONLY because the causal rule text changed.
