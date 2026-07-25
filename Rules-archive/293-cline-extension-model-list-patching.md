# 293 - How to add/upgrade a Claude model in Cline's Settings dropdown

Permanent rule. Workspace-scoped. Source: 2026-07-25 - "add Opus 5 to Cline settings" took THREE separate debugging rounds (wrong file, wrong file again, then a second hidden gate) before it actually worked end to end. Ruben's repeated feedback across all three rounds: "why was this so hard" and "make it so future agents don't have such difficulty." This rewrite replaces the original "patch these 5 fixed objects" approach (which turned out to be incomplete) with a general, repeatable METHOD that finds every place a new model needs to be added, instead of a fixed checklist that can miss gates nobody has hit yet.

## The core lesson: use a working sibling model as your reference, and clone EVERY occurrence of it

The first version of this rule said "patch these 5 specific object-contexts." That was wrong-shaped advice: it was a snapshot of what one investigation happened to find, not a complete list. When Ruben actually tried using the new model, a 6th gate (a hardcoded model-name-detector controlling the Anthropic API request shape) turned out to exist and broke everything with a 400 error, because it wasn't one of the "5 objects."

The generalizable technique that actually works: pick an existing model in the SAME family and SAME generation as the one you're adding (e.g., if adding claude-opus-5, use claude-sonnet-5 as the reference - same release wave, so it's gone through all the same code paths already). Then:

1. Find EVERY literal occurrence of the reference model's exact string in BOTH bundle files (see "the two files" below). Do not guess how many there will be - count them. In the 2026-07-25 build, claude-sonnet-5 appeared 33 times in dist/extension.js alone, spanning far more than 5 contexts: catalog objects for Anthropic, Bedrock, Vertex, OpenRouter, and SAP-OCA, alias/shortcut tables, a request-shape detector function, and multiple switch(modelId) blocks that apply provider-specific overrides (pricing corrections, context-window bumps, tier assignments) for OpenRouter and SAP OCA specifically.
2. For each occurrence, determine whether the code path is (a) a literal one-to-one mirror you can clone by adding a matching entry for the new model, or (b) a place where the reference model is just ONE example among a list of several equivalent-generation models sharing one code branch (in which case the new model may already be covered by that branch's other conditions, or may need to be added to it).
3. Patch every clone-able occurrence. Do NOT stop at "the first 5 I found" - that's exactly the mistake that caused this task to take 3 rounds.
4. If a switch statement branches per exact model ID string (case matching a literal provider-prefixed model name), the new model needs its own case line too, UNLESS it's already covered by an existing case that matches on a version-family pattern rather than an exact ID (read the case list carefully - some switches key off literal IDs, some off substring matches like the detector-function pattern below).

Why this beats a fixed checklist: any fixed list of "N objects to patch" is a guess about what THIS release's codebase happens to contain. The sibling-clone method scales to future Cline versions automatically, because whatever the reference model touches, the new model needs to touch too, since they're the same generation and go through the same code.

## The bright-line fact: there are TWO bundle files, not one

Cline (extension saoudrizwan.claude-dev) hardcodes its model catalog into TWO separate minified JS bundles:

1. dist/extension.js - the extension host's copy. This is the ONLY file that constructs and sends actual API requests. Any request-shape or capability-detection logic (like the thinking-format gate below) lives here, and ONLY here.
2. webview-ui/build/assets/index.js - the Settings UI panel's OWN separate copy. This is what actually renders the Model dropdown. It has its own copy of the catalog objects but does NOT construct API requests - confirmed 2026-07-25 that request-shape logic present in file 1 has zero matching occurrences in file 2. Don't waste time searching file 2 for backend or request logic.

Run the sibling-occurrence scan (step 1 above) against BOTH files. The catalog objects will show up in both; the request-construction logic will only show up in file 1.

Find both files fast with a find command over the extension install directory, filtering to js/json files over 50k and excluding backup files.

## Known gate categories (examples from 2026-07-25, NOT an exhaustive list - always re-scan)

These are what the sibling-clone scan turned up for claude-sonnet-5 and claude-opus-5 in the 2026-07 build. Treat this as "these kinds of things exist," not a checklist to stop at:

- Direct-provider catalog objects - one per API surface (native Anthropic, AWS Bedrock with an anthropic-dot prefix, GCP Vertex with a different field order, SAP OCA with a double-dash prefix, OpenRouter with a slash prefix). Each has its own pricing and capability object, sometimes with a per-provider price override.
- Alias and shortcut tables - object-spread constructions that build shorthand names (like "opus" or "sonnet") and bracket-suffixed 1M-context variants. The wrapping variable name changes per build and per file - extract it dynamically via regex, never hardcode it.
- Request-shape and capability detector functions - a model-name-pattern-matching function (minified name changes per build) that decides which API request format to use. In this case: legacy thinking-enabled-with-budget-tokens format versus a newer adaptive-thinking-with-effort format. If a new model isn't recognized here, the API rejects requests with a 400 error even though the model is fully selectable in the UI. This is the gate most likely to be missed because its failure mode (a 400 at send-time) is invisible until someone actually sends a message - the UI shows nothing wrong.
- Dynamic model-info switch statements - blocks keyed on exact provider-prefixed model ID strings (seen for OpenRouter and SAP OCA) that apply context-window bumps, 1M-tier assignment, and pricing corrections at runtime based on exact ID match. These exist for providers that fetch model info dynamically rather than reading the static catalog objects.

## The technique: Node.js indexOf-splice, never grep or sed on these files

These files are single-line, multi-megabyte minified JS.
- macOS/BSD grep's repetition-count syntax has a hard cap around 255 repeats - wide-context extraction via grep with interval expressions silently errors or truncates on files this size.
- sed regex escaping for strings full of curly braces, bangs, dots, colons, and commas is error-prone at this scale.

Always use a small Node.js script instead:
1. Read the file with fs.readFileSync in utf8 mode.
2. To find ALL occurrences of the reference model's literal string with context, loop indexOf and print a slice of surrounding characters for each - this is the sibling-occurrence scan, run it FIRST before patching anything.
3. For each clone-able occurrence, build the exact anchor string by copying it verbatim from the scan output - never hand-type minified JS.
4. Safety check: split the content on the anchor and confirm the occurrence count is exactly one, BEFORE any write.
5. Splice the new entry in immediately after the anchor.
6. Write the file back, then re-read and verify the new occurrence count plus a context slice.
7. Run node with the --check flag to confirm the whole file still parses as valid JavaScript.

For alias-table objects where the wrapping variable name changes between builds or files, extract it dynamically with a regex capture group rather than hardcoding a specific letter combination.

## Always back up first, unconditionally

Copy both target files to timestamped backup siblings before writing anything. This is a Mac-local path, not a server path, so the ordinary local file tools are correct here.

## How to make it live WITHOUT a full VS Code restart

A new VS Code window respins the webview from the SAME already-running extension host process - it does NOT reload patched files from disk. Trigger "Developer: Restart Extension Host" programmatically instead of asking Ruben to restart VS Code, by activating VS Code, opening the command palette with Cmd+Shift+P, typing the command name, and pressing return (this can be done via osascript). This reloads the extension host (and respins the webview) in a few seconds, no app restart needed. Run this after EVERY patch pass, including follow-up patches to the same file later in the same session.

## Verify end-to-end, not just "is it in the dropdown"

Being selectable in the Settings dropdown is necessary but NOT sufficient. The task is only actually done when:
1. The model appears in the dropdown (catalog objects patched, both files).
2. A real message can be sent and gets a real response (request-shape and capability detector patched, file 1 only). Do not report done after step 1 alone - that was the exact mistake that caused round 2 of this task. If you cannot personally send a test message (Cline agents cannot drive their own extension's chat UI), say so explicitly and ask Ruben to confirm a real send, or better: proactively scan for and patch the known request-shape gate category above BEFORE declaring done, since its failure is invisible until send-time.

## Never defer follow-up investigation as human-only or out of scope

Gaps found DURING a live debugging session, on a tool you already have full read and write access to (a local file, in this case), are NOT human-only decisions, they are undone work per rule 29. If a second bundle location, a missed gate category, or an unverified assumption surfaces while actively fixing something, fix it in the same pass. Only genuinely human-policy calls (which model to add, what pricing to assign, whether to ship to production) need sign-off.

## Self-check before declaring a Cline extension model-add complete

1. Did I run the sibling-occurrence scan against BOTH files, using a same-generation reference model, instead of just pattern-matching the gate categories listed above from memory?
2. Did I clone every occurrence that needed cloning, including switch-statement cases for OpenRouter, SAP-OCA, or other dynamic-info providers if the reference model appeared there?
3. Did I patch the request-shape and capability detector in dist/extension.js specifically (the gate most likely to be silently missed)?
4. Did I back up both files before writing, and verify via occurrence-count plus a syntax check after?
5. Did I trigger Developer: Restart Extension Host myself after every patch pass?
6. Did I verify (or explicitly flag that I could not verify) that a real message actually sends successfully, not just that the model is selectable?
7. Did I complete any "if X doesn't work, check Y" follow-ups myself instead of parking them as open threads?

## Cross-refs

- Rule 144 (server-path write gate) does not apply here - this is Mac-local, not WOPR.
- Rule 29 (agents act on confidence tier) - gaps found mid-session are not human-only deferrals.
- Rule 143 precedent - the maxConsecutiveMistakes patch to this same extension.js file proved direct-patching the bundled extension is safe and supported.

## Source

2026-07-25 - Ruben's task "add Opus 5 to Cline settings" required 3 rounds: (1) a misdirected WOPR/LiteLLM edit that had no effect on the native Anthropic provider, (2) an extension-host-only catalog patch that missed the separate webview bundle, (3) a working dropdown that still 400'd at send-time because a hidden request-shape detector function wasn't covered by the original "5 fixed objects" checklist. After round 3, Ruben asked again to "make it so future agents know how to do this better" - this rewrite replaces the fixed-checklist approach with the sibling-clone method, which generalizes to whatever gates exist in any future Cline build instead of listing only the ones this investigation happened to find.
