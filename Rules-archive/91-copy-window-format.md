# 91e — Copy-Window Format: Fenced Code Blocks for One-Click Copy

Hardfloor-adjacent (gate 9e in _RULE_TREE.md). 2026-07-28.

## The problem

Ruben asked for "copy windows where I click the copy prompt only, where I don't select text, just press the button and it copies to the clipboard." Prose-wrapped copy prompts require text selection (drag-select or triple-click), which on long multi-step prompts is error-prone and frustrating.

## The format: fenced code blocks with `——[COPY]——` markers

Every copy window delivered to Ruben MUST be wrapped in a fenced code block:

```
```text
——[COPY]——
# COPY WINDOW N — Title

Pick up task — <what this window does>.

Context:
- #NNNN [disposition] — brief context

Step 1 — <action>:
  concrete_tool_path(...)

Step N — <action>:
  concrete_tool_path(...)

Verification:
  check_command
——[/COPY]——
```
```

**Rules:**
1. **Fenced code blocks** (```text ... ```) are mandatory — they provide the native copy button in Cline's UI. No text selection required.
2. **`——[COPY]——` opens, `——[/COPY]——` closes** — these are inside the fenced block. They let Ruben visually delimit where a copy window starts/ends even if the blocks get pasted or shared.
3. **# COPY WINDOW N — Title** as the first line after the open marker.
4. **Concrete tool paths** in every step (gate 9d). No prose-only instructions.
5. **Verification step** included at the end.
6. **Parallel-safe:** every copy window must be safe to run independently, regardless of order (rule 209).
7. **Run-to-completion:** every window includes enough context and concrete steps to complete without iterative back-and-forth (rule 209).

## When to use

- Anytime Ruben asks for "copy windows," "copy prompts," "dispatch prompts," or "prompts to push this"
- When offloading work to parallel windows per rule 267 / rule 209
- When handing off a multi-step investigation or deploy task

## When NOT to use

- Single-step operations that can be done inline (use the direct tool call)
- Rule-91 pickup prompts (those use the U+2550 divider format, not fenced code blocks)

## Cross-refs

- `_RULE_TREE.md` — gate 9d (concrete-tool-path test), gate 9e (this format)
- Rule 91 — pickup prompt format (separate from copy-window format)
- Rule 209 — multi-copy-windows run-to-completion parallel
- Rule 194 — parallel dispatch windows must run simultaneously
- Rule 267 — offload + reconcile before completion