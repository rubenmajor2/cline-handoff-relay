# Subagent Model Picker — per-subtask model selection guide

## When I dispatch use_subagents, I should set prompt_N_model

This extension was patched on 2026-05-12 to support optional `prompt_N_model` parameters.
When set, each subagent runs on the specified model instead of the parent's model.

## Model selection guide

| Task type | Model | Why |
|---|---|---|
| Research, read files, status checks, grep, list | `claude-haiku-4-5` | $0.80/$4 per MTok, fast, fine for reads |
| File extraction, data shaping, classification, short summaries | `claude-haiku-4-5` | Same — light cognitive load |
| Code patches <100 lines, single-file edits, single-tool plans | `claude-sonnet-4-6` | $3/$15, good reasoning for code |
| Plan composition, architectural decisions, cross-system analysis | `claude-sonnet-4-6` | Default for most multi-step |
| Regulator-grade writing, complex legal/compliance reasoning, NOI responses | `claude-opus-4-7` | $15/$75, only when it matters |
| Anything I'd normally burn Opus on "just to be safe" | `claude-sonnet-4-6` | Sonnet is 5x cheaper, usually just as good |

## When to leave prompt_N_model UNSET

- Leave unset when the parent is already on Sonnet 4.6 and the subagent is the same complexity (no point switching)
- Leave unset for tool-use-heavy subagents where the model matters less than the MCP tool results
- Leave unset when Haiku/Sonnet previously YOLO'd on a similar sub-task and needed Opus

## Examples

```
use_subagents(
  prompt_1="Research: what does the mcp::check_exam_enforcement tool return for student 26908W-08?",
  prompt_1_model="claude-haiku-4-5",
  prompt_2="Using the research above, compose a student-facing email about the exam policy per .clinerules/02",
  prompt_2_model="claude-sonnet-4-6",
  prompt_3="Review the composed email for regulator exposure per .clinerules/08",
  prompt_3_model="claude-opus-4-7"
)
```

```
use_subagents(
  prompt_1="List all tickets filed in the last 24h via mcp::search_tickets",
  prompt_1_model="claude-haiku-4-5",
  prompt_2="Classify and prioritize the tickets by student impact",
  prompt_2_model="claude-haiku-4-5",
  prompt_3="Draft a daily digest summary for the ops team",
  prompt_3_model="claude-sonnet-4-6"
)
```

## Cost math (why this matters)

- 100k input token subagent on Haiku: $0.08
- Same on Sonnet: $0.30
- Same on Opus: $1.50

A single research subagent that was burning Opus can drop from $1.50 to $0.08 per dispatch.
Across 10 subagent dispatches/day: was $15/day on Opus, now $0.80/day on Haiku.

## What does NOT work yet (v1 limitations)

- Ollama routing (`ollama:emsu-qwen2.5-coder:7b-lora`) requires provider override, not just model ID.
  The v1 patch only handles same-provider model switching (Anthropic → Anthropic different model).
  V2 will add Ollama provider routing for the truly free sub-tasks.

## Reversal

The bundle is patched in place. Backup at:
`~/.vscode/extensions/saoudrizwan.claude-dev-3.82.0/dist/extension.js.bak-pre-model-picker-2026-05-12`

To revert: `cp ~/.vscode/extensions/saoudrizwan.claude-dev-3.82.0/dist/extension.js.bak-pre-model-picker-2026-05-12 ~/.vscode/extensions/saoudrizwan.claude-dev-3.82.0/dist/extension.js`
Then reload window.
