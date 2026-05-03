# Cline Edit Discipline — What Not To Put In The Conversation

This is the AI-side companion to `97-extension-host-oom.md`. The watchdog stack catches balloons after the fact. The actual prevention is: don't write a conversation that balloons on parse-on-resume.

## The rule of thumb

Every byte you put into a tool result goes into `ui_messages.json` and stays there for the life of the task. When the window reloads, V8 parses the whole file in one shot at 30-100x inflation factor. So:

- **Keep tool results small.** Summarize, don't quote in full.
- **Don't `read_file` images, PDFs, or videos for "vibes" or to "have a look."** Their base64 explodes V8.
- **Don't paste serialized blobs into `replace_in_file` SEARCH/REPLACE.** Use sed/awk/python on the host instead, or `write_to_file` for whole-file replacement.
- **Truncate command output.** A `tail`, a `grep`, a `head -50` is usually enough. A 50-line summary is better than a 5000-line dump.
- **Long tasks → archive yourself.** If the conversation has been going for a day and is doing real work, finish a phase via `attempt_completion` and start fresh on the next phase. Don't accumulate forever in one task.

## Specific don'ts

### Don't read large binaries into the conversation

```
read_file path=/somewhere/screenshot.png         # NO — base64 inflation
read_file path=/somewhere/audit.pdf              # NO — same
read_file path=/somewhere/build.zip              # NO — same
```

If you need the contents, process them on disk:
- For images: `file`, `identify`, OCR via a host command, then summarize.
- For PDFs: `pdftotext file.pdf -` then `head` the result.
- For zips: `unzip -l` to list, don't read.

### Don't paste minified JS / CSS / build bundles into edits

If you need to change a 3000-line minified bundle, you almost certainly are touching the wrong file. Find the source `.ts` / `.scss` / `.vue` and edit that. The bundle regenerates.

### Don't quote whole files in messages

If the file is 200 KB and you want to make a 5-line change, use `replace_in_file` with a tight 3–8 line SEARCH context. Don't `read_file` it just to confirm contents — that puts the whole thing in `ui_messages.json` forever.

### Don't dump SQL / DB rows verbatim if the result is huge

```sql
SELECT * FROM tickets;       -- 12,000 rows = bloat
SELECT COUNT(*) FROM tickets WHERE status='open';   -- 1 number = fine
SELECT id, subject FROM tickets WHERE ... LIMIT 20; -- summary = fine
```

Aggregate first. Show the user a count + a sample, not the whole result set.

### Don't use `browser_action` screenshots for casual confirmation

Each screenshot is a base64 PNG that lives in the conversation forever. They're useful for verifying a UI change works, but don't take 10 of them in a row when 1 is enough.

## Specific do's

- **Heredoc is your friend on the server side.** `ssh wopr "cat > /tmp/file.json <<'EOF' ... EOF"` — the content lives on the server, not in your message log.
- **Process-then-summarize.** Run the command, capture to a temp file, then read just the summary.
- **`attempt_completion` aggressively.** Closing a task is the cheapest archive operation Cline has.
- **Use the host shell.** `awk`, `sed`, `jq`, `python -c`, `grep` all run on the box and put nothing in the conversation if you redirect output to a file.

## When you DO need to look at a big thing

Use a side channel:
1. Save it to `/tmp/something.txt` on the server.
2. `head -100 /tmp/something.txt` to look.
3. The 100-line head is what enters the conversation, not the 50 MB file.

Or for browser screenshots: take ONE, look at it, close the browser. Don't accumulate.

## Last updated

2026-05-02 — initial rule. Written alongside `96-cline-window-discipline.md` and `97-extension-host-oom.md` after the Mac panic + Artemis storm post-mortem at 19:14-19:22 PT.
