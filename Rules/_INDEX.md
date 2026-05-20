# Cline Rules Index (always-loaded, MCP-independent)

This file is the fail-safe table of contents for all rules in the .clinerules corpus.
It loads with every Cline task (~10KB) regardless of whether the clinerules-mcp is up.

**Phase 3 layout (2026-05-19):** the 10 hardfloor rules + this index live in
`~/Documents/Cline/Rules/` so Cline auto-loads them every task. The other ~110
rules live in `~/Documents/Cline/Rules-archive/` and are queryable on demand via
`clinerules_lookup` / `clinerules_search`. This keeps each Cline task at ~90KB
of injected rules instead of ~1.2MB.

## How to use

1. Scan this index for the right rule_id by topic/trigger.
2. **Preferred:** call `clinerules_lookup(rule_id=N)` MCP tool to get the full body
   (works for hardfloor AND archived rules).
3. **Fallback (MCP down):**
   - Hardfloor: `read_file /Users/rubenmajor/Documents/Cline/Rules/<N>-<slug>.md`
   - Everything else: `read_file /Users/rubenmajor/Documents/Cline/Rules-archive/<N>-<slug>.md`
4. The hard-floor rules (marked ★) are ALWAYS in the system prompt — never need lookup.

## Hard-floor rules (always in system prompt — ★)

| ID | Slug | What it fires on |
|---|---|---|
| 00-READ-FIRST-17 ★ | force-subagent-use | Default first move every task; tripwire on every tool call |
| 01 ★ | voice-and-persona | Ops chat 55/64/5/84/88 voice — Ruben speaking, casual, no em-dash |
| 02 ★ | no-apologies-in-student-emails | Student-facing email composition |
| 29 ★ | agents-act-on-confidence-tier | act/Q-card/escalate gate for any non-trivial action |
| 38 ★ | ruben-asks-equals-autonomous-or-shipped | Ruben-directed work goes status=approved |
| 41 ★ | post-deploy-call-the-tool-do-not-narrate | Banned "Deployed./Now I'll/Next" prose |
| 91 ★ | every-completion-needs-pickup-prompt | attempt_completion shape + forbidden phrases |
| 92 ★ | work-at-the-core-not-bandaids | Fix RUBEN, don't fix FOR RUBEN |
| 99 ★ | yolo-prevention-learned | Auto-generated per-failure playbook |
| EXECUTE_ORDER_66 ★ | wrap-up protocol | Trigger phrases + 6-step protocol |

## On-demand rules (fetch when topic comes up)

### Voice + comms
| 10 | staff-ticket-escalations-plain-language | Vicky/Jon/Cori plain language |
| 13 | signed-affiliation-agreement-vicky-jon-cc | Affiliation handoff CC pattern |
| 15 | no-internal-reasoning-narration-in-student-emails | "I should/will/per rule" leaks |
| 19 | no-third-party-assessment-names | Wonderlic/TEAS/HESI hallucination block |
| 30 | staff-chat-context-and-acknowledgment | Read chat 55 before sending |
| 31 | proctoring-handoff-not-autonomous-commitment | Routing not promising timelines |
| 47 | use-full-web-addresses-not-shortcuts | https://emsuniversity.com/... in emails |
| 48 | ruben-house-style-plain-email | rmajor@ outbound voice + signature |
| 57 | never-send-staff-imessage-without-explicit-request | Cline does NOT page chat 55/64 |
| 72 | no-time-deadline-promises-to-staff | No "Vicky will reach out within 24h" |
| 96 | promise-of-staff-followup-cc-staff | If body says "X will follow up", X is CC'd |
| 101 | no-cline-self-reference-or-internal-jargon-in-staff-comms | Strip Cline/clinerules/Opus from staff emails |

### Agent behavior + escalation
| 12 | cross-chain-policy-questions-go-on-ruben-questions | Q-card portal vs inline |
| 22 | executor-self-supervision-loops | RUBEN classifier + recipe framework |
| 23 | kaizen-mcp-failure-classifier | When to use KAIZEN MCP |
| 36 | self-healing-the-orchestrator-itself | Repair the agent, not just symptom |
| 42 | offer-proactive-systemic-solutions | Class fix > spot fix |
| 46 | every-agent-correction-loops-back-to-ruben-kaizen | Correction = learned pattern + recipe |
| 49 | if-ruben-asks-did-you-offer-to-do-it | Offer, don't just answer no |
| 53 | subagent-iteration-and-narration | Dispatch model picker + narration |
| 54 | subagents-can-act-under-locking-primitives | Subagents CAN write under safe-deploy CAS |
| 56 | offer-ideas-when-implied | If Ruben implies idea, file it |
| 65 | multi-file-incident-opus-root-cause | ≥3 simultaneous failures → Opus subagent |
| 66 | offer-to-fix-everyone-in-same-situation | Class query before closing one-student task |
| 67 | agents-act-autonomously-before-human-escalation | Exhaust tools before Vicky/Jon |
| 68 | agents-exhaust-tools-and-request-expansion | Capability-gap idea filing |
| 69 | jon-is-policy-override-not-technical-fixer | Jon = policy. Technical = Ticket Agent |
| 73 | close-the-agent-capability-gap | Ship capability + playbook in same session |
| 74 | opus-main-aggressive-haiku-dispatch | 2+ reads = parallel Haiku |
| 75 | verification-tasks-default-mcp-and-subagents | Verify = MCP + subagents + 7B first |
| 78 | idea-mentions-need-yn-explanation-recommendation | Idea mention 4-line format |
| 81 | ruben-silent-on-ops-chat-cline-babysits | Babysit when RUBEN scanner silent |
| 82 | use-subagents-to-develop-and-execute-plans | Multi-phase = parallel plan subagents |
| 85 | student-issues-prefer-systemic-fix | Run class query before fixing one |
| 86 | fleet-agent-retry-kaizen-rewrite-redraw | LoRA workstream retry ladder |
| 87 | fleet-agent-opportunity-cost-math | Delay cost > action cost = ship now |
| 88 | llm-judge-must-be-cross-family | Anthropic can't judge Anthropic |
| 90 | cline-resolves-proactively-agents-first | Ticket Agent first, Vicky second, Ruben last |
| 94 | train-agents-do-not-fix-for-them | Every cross-lane = improve the agent |
| 97 | ticket-agent-first-touch-and-1h-human-callback-delay | Ticket Agent universal first-touch |

### Infrastructure / debugging
| 16 | yolo-threshold-and-recovery | maxConsecutiveMistakes=10/15 dual-path |
| 20 | mcp-host-resolver-required | New MCPs use _shared/host_resolver |
| 24 | cline-tabs-cap-and-distribution | 5 tabs per code-server instance |
| 25 | mac-side-cline-tab-die-chrome-discard | Chrome Memory Saver = OFF |
| 26 | phantom-vscode-extension-manifest | extensions.json says installed, disk says no |
| 27 | wopr-trusted-device-via-wireguard | Trust by WG identity, not IP |
| 28 | mac-vscode-argv-js-flags-amplifier | argv.json js-flags = jetsam cliff |
| 29-mac-jetsam-cliff-without-argv-amplifier | residual jetsam class | Disk full / swap=0 |
| 32 | prefer-dedicated-mcp-tools-over-raw-shell | MCP wrapper > raw SSH/SQL |
| 33 | meta-business-platform-onboarding | FB/IG System User token path |
| 34 | cline-input-clear-bug-and-self-heal-patch | Cline 3.82 input-clear self-heal |
| 35 | verify-external-urls-before-citing | curl -sIL before pasting URLs |
| 37 | no-dry-run-sink-or-swim | Skip "let's run shadow for 24h" |
| 40 | default-to-artemis-ollama-first | 7B-LoRA = analysis baseline |
| 43 | no-sms-email-ruben-instead | In-chat updates, not SMS |
| 44 | cline-anthropic-outage-failover-to-openai | gpt-5.5 manual fallback |
| 45 | verify-with-web-when-ruben-says-newer-version-exists | Live source > training data |
| 50 | rag-augmented-prompts-expected | RAG context appears in system prompt |
| 51 | runpod-cloud-gpu-workflow | RunPod API + offer protocol |
| 55 | investigate-fix-report-bugs-before-mentioning | Don't mention without investigating |
| 60 | grievance-approval-stipulation-logic | Approval w/ stipulations always |
| 61 | grievance-disposition-email-mechanics | response_draft is the send field |
| 62 | visual-ui-bug-requires-browser-first | browser_action mandatory before claim fix |
| 63 | session-bridge-for-auth-gated-debugging | sid-bridge for Puppeteer EMSU pages |
| 64 | user-says-nothing-changed-verify-before-iterating | Verify before second fix |
| 70 | always-exhaust-authnet-mcp-before-assuming-alternate-processor | Authnet only, no Stripe |
| 71 | team-hub-mcp-for-instructor-scheduling | Hub tools before CS routing |
| 76 | personnel-agent-handoffs-default-mcp-and-subagents | call_ollama first on personnel |
| 77 | cline-router-overload-error-recovery | Mac tunnel kick recovery |
| 79 | course-materials-fee-is-bundled-and-equipment-claims | Bundle fee + first-day instructor CC |
| 80 | important-tasks-get-starred | "important" → INSERT ruben_task_stars |
| 83 | browser-action-token-auth-for-emsu-routes | sid token, never type creds |
| 84 | use-runpod-to-save-time | Default-on cloud for >6h parallel |
| 89 | ollama-cold-load-timeout-not-broken | 60s timeout before declaring 7B down |
| 89-ruben-personal-assistant-voice-system | RUBEN PA TNG voice line (+17602807886) |
| 93 | create-idea-status-approved-when-ruben-directed | INSERT idea AT approved |
| 95 | cline-30s-tool-wall-and-remote-long-running-work | scp + nohup + tail pattern |
| 100 | ptyhost-saturation-fingerprint | journalctl grep RequestStore |
| 102 | exam-technical-3day-extension-policy | 3-day extension blanket rule |
| 102-mac-battery-drain-mcp-fork-bomb | macOS jetsam supergateway fork bomb |
| 103 | technical-fail-completion-past-window | TECHNICAL_FAIL bucket precedence over 18 |
| 104 | artemis-freshness-self-check | Verify learner pipeline before non-trivial work |
| 105 | turn-0-sanity-check | MCP roster, call_ollama, tunnel checks |
| 106 | ruben-runtime-quickref | Agents/crons/tables/kill switches |

### Compliance + regulatory
| 08 | regulator-noi-response-posture | NOI response 15 postures + anti-patterns |
| 18 | emsu-fault-externship-paperwork-stuck-cases | Bucket-C treatment (rule 103 comes first) |
| 60-61 | grievance | see Voice section |

### Task hygiene
| 03 | task-completion-resume-kit | attempt_completion shape |
| 04 | timezone-pacific-for-emsu | All times in PT |
| 05 | default-background-queue-and-clarifying-questions | Y/N card format |
| 06 | pagination-and-search-standard | ruben_paginate helper for list routes |
| 07 | task-ledger-task-id-discipline | No composite task_ids |
| 09 | chat-ai-hard-escalation-triggers | widget_force_handoff |
| 21 | (none) | |
| 39 | (none) | |
| 52 | answer-questions-in-attempt-completion | Q/A block at TOP of result |
| 58-59 | (none) | |
| 98 | edit-discipline | Don't bloat ui_messages.json |

## When MCP is down

If `clinerules_lookup` returns connection error:
1. This index still loaded (it's a regular .clinerules file).
2. Use `read_file` directly: `path=/Users/rubenmajor/Documents/Cline/Rules/<id>-<slug>.md`
3. Slugs are predictable from titles. If unsure: `ls ~/Documents/Cline/Rules/ | grep -i <topic>`
4. Index updated on every new rule. If a rule_id isn't here, see source-of-truth dir.

## When to ADD to this index

Whenever a new .clinerules file is written, append a row to the right section. The index is the single line of defense if MCP is down.
