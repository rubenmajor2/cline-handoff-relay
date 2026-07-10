# 122 — Deliver runnable text as fenced copy-blocks in chat (incl. the rule-91 pickup prompt)

Source: 2026-06-03 Ruben directive verbatim: *"Need the copy block here in chat. Make that a cline rule. Easier to have copy blocks, including for the 91 handoff."*

## The bright-line rule

**Any time the response contains text the user is meant to copy and run/paste — a terminal command, a multi-line script, a config, an SSH key block, OR the rule-91 PICKUP PROMPT — it MUST be rendered as a fenced code block (```lang ... ```) directly in the chat response.** Cline's UI puts a one-click copy icon on every fenced block, so a fenced block = a clickable copy button for Ruben.

Do NOT make the user open a Desktop `.txt`/`.md` file to copy it. Saving a backup copy to a file is fine and encouraged, but the copy-pasteable version MUST also be inline in the chat as a fenced block.

## Lines must not bleed off the page — wrap to ≤80 chars

Cline's code-block UI does NOT soft-wrap. Long lines run off the right edge and the user can't read them (they only see the left portion). So every line inside a copy-block MUST be self-contained and ≤ ~80 characters. Concretely:

- **Commands:** break long one-liners across multiple lines with a trailing `\` (backslash-newline) so each visible line is short. Bash treats `\`+newline as one command. Example:
  ```bash
  ssh -f -N -o StrictHostKeyChecking=accept-new \
    -o ExitOnForwardFailure=yes -o ServerAliveInterval=20 \
    -i "$HOME/.ssh/jump_to_wopr" -p 2222 \
    -L 5902:127.0.0.1:5902 emsuserver@emsuniversity.com
  ```
  NOT one 180-char line that scrolls off-screen.
- **The rule-91 PICKUP PROMPT:** hard-wrap every bullet/sentence to ≤80 chars by inserting real newlines. Do not write a 200-char bullet. Keep file paths and IDs on their own short lines if needed. The `═══` divider should be ~50 chars, not stretched.
- **Unsplittable tokens** (an SSH key, a base64 blob, a long URL): these are fine because the user copies them as-is and never reads them line-by-line. SSH private keys are already pre-wrapped at 70 chars by ssh-keygen — leave them. But do not put long *prose* or *paths* on the same line as them.

The test: if a line in the rendered block would require horizontal scrolling to read, it violates this rule. Wrap it.


## What must be a fenced copy-block

- Terminal commands the user runs (even one-liners) → ```bash block.
- Multi-line install/paste scripts → ```bash block.
- SSH keys, WireGuard configs, plist XML, JSON the user pastes → fenced block with the right lang.
- **The rule-91 PICKUP PROMPT** → render it inside a fenced block so Ruben can one-click copy the whole thing into a fresh window. (The `═══` divider style still goes inside the fence.)

## Why

Ruben copies these blocks constantly (Mac-to-Mac paste, pasting commands into Terminal, pasting pickup prompts into new Cline windows). Prose instructions or "see the file on your Desktop" force manual selection or a detour. A fenced block is a single click. This is the same problem class as rule 91's PICKUP-BY-REFERENCE anti-pattern (don't point at a file, embed it inline) — extended to ALL runnable text.

## Anti-patterns that violate this rule

- ❌ Pasting a multi-line command as indented prose or plain text with no fence.
- ❌ "The command is saved at ~/Desktop/foo.txt, copy it from there."
- ❌ Putting a key/script in a file and only telling the user the path.
- ❌ Rendering the rule-91 pickup prompt as plain text the user has to hand-select.
- ❌ Splitting one runnable block across prose so the copy icon only grabs part of it.

## Correct shape

Inline, fenced, one block per runnable unit:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "this is one clickable copy block"
```

And the rule-91 pickup prompt also fenced:

```
═══════════════════════════════════════════════
PICKUP PROMPT (paste into a fresh Cline window)
═══════════════════════════════════════════════
...
═══════════════════════════════════════════════
```

## Interaction with rule 41 / 99 (no-tool-use trap)

This rule is about the CONTENT of an `attempt_completion.result` (or a chat answer), not about emitting tool calls. It does not change the rule-41/99 requirement that assistant turns doing work must contain tool calls. Fenced blocks live inside the final result text, which is allowed.

## Self-check before any completion

Ask: *"Does my response contain anything Ruben will copy — a command, a script, a key, or the pickup prompt? If yes, is each one inside a fenced ``` block right here in the chat?"* If any runnable text is bare prose or only in a file, wrap it in a fence inline.

## Last updated

2026-06-03 — initial. Source: Ruben, during the Mac-2 remote-access setup, repeatedly needed the install command as a clickable copy block in chat rather than a Desktop file; asked that copy-blocks (including the rule-91 handoff) become the default.
