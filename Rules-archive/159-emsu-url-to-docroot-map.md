# 159 — EMSU URL → filesystem docroot map. A public URL path is NOT the filesystem path (Plesk vhosts + symlinks).

Permanent rule. Workspace-scoped. Source: 2026-06-16 — a Cline window tasked with removing "CAPCE" from `https://emsuniversity.com/ems` repeatedly grepped `/var/www/emtskills/ems/` (the WRONG docroot), found nothing, and looped — Ruben had to manually re-tell it where the files were. Ruben: "I have a hard time believing it can be this dumb. There must be some configuration issue." He was right: the URL→filesystem mapping lives nowhere a window can read. This rule fixes that.

## The bright-line rule

**Before searching the server filesystem for a file you only know by its public URL, RESOLVE the URL to its real filesystem path first. On WOPR (a Plesk server), the public URL path does NOT match the filesystem path — vhosts and symlinks remap them.** Grepping the wrong docroot and looping is the failure this rule prevents.

## The canonical map (emsuniversity.com)

The Plesk vhost docroot is `/var/www/vhosts/emsuniversity.com/httpdocs`. Inside it, two symlinks remap the important paths:

| Public URL | REAL filesystem path | What it is |
|---|---|---|
| `https://emsuniversity.com/` | `/var/www/vhosts/emsuniversity.com/httpdocs/` | WordPress marketing site |
| `https://emsuniversity.com/ems` | **`/var/www/moodle/ems`** (symlink) | **Moodle LMS** — courses, grading, users, local plugins |
| `https://emsuniversity.com/emtskills` | **`/var/www/emtskills`** (symlink) | EMTSkills PHP app — admin portal, agents, crons |

**The trap:** `/var/www/emtskills/ems` EXISTS but is a DIFFERENT, smaller app — it is NOT what `emsuniversity.com/ems` serves. `emsuniversity.com/ems` = `/var/www/moodle/ems` (Moodle). A window searching `/var/www/emtskills/ems` for content seen at `emsuniversity.com/ems` will find nothing and loop. This exact mistake triggered this rule.

## Rule of thumb

- URL under **`/ems`** → Moodle → **`/var/www/moodle/ems`** (NOT `/var/www/emtskills/ems`).
- URL under **`/emtskills`** → **`/var/www/emtskills`**.
- Bare `emsuniversity.com/` → the Plesk httpdocs WordPress root.
- Other domains (emsuwildland.com, emswire.com, sunriserescue.com, rubenmajorforsenate.com) → each its own Plesk vhost: `/var/www/vhosts/<domain>/httpdocs` (WordPress).

## How to resolve ANY URL to its real path (do this FIRST, don't guess)

```
# 1. List the first path segment under the vhost httpdocs and follow the symlink:
sudo ls -ld /var/www/vhosts/emsuniversity.com/httpdocs/<first-segment>
# 2. If it's a symlink (lrwxrwxrwx ... -> /var/www/...), THAT target is the real docroot.
# 3. Grep there, not in a guessed path.
```

The server also carries this map at `/var/www/emtskills/docs/DOCROOT_MAP.md` (and a copy at `/var/www/moodle/ems/DOCROOT_MAP.md`). Read it if unsure.

## Self-check before any filesystem search-by-URL

1. *Do I know the URL but am about to guess the filesystem path?* → STOP. Resolve via the table above or `ls -ld` the vhost segment + follow the symlink.
2. *Is the URL under `/ems`?* → It's Moodle at `/var/www/moodle/ems`, NOT `/var/www/emtskills/ems`.
3. *Did my first grep return nothing?* → Do NOT re-grep the same wrong path twice (rule 143 loop). Re-resolve the docroot first.

## Cross-references

- Rule 92 — fix at the core (the durable fix is this map as a read-at-runtime surface, not re-telling each window)
- Rule 144 — server-path edits via emsu-operations ssh_command (and Moodle paths are server paths)
- Rule 143 — don't loop the same failing search; re-resolve the path instead
- `/var/www/emtskills/docs/DOCROOT_MAP.md` — the server-side copy

## Source incident

2026-06-16 — Cline window on "remove CAPCE from emsuniversity.com/ems" grepped `/var/www/emtskills/ems/` 3× (wrong docroot), found nothing, looped until Ruben manually pointed it at the right place. Truth: `emsuniversity.com/ems` is a symlink to `/var/www/moodle/ems`. No URL→filesystem map existed anywhere a window could read. Fixed by creating DOCROOT_MAP.md on the server + this always-loaded rule.

## Last updated

2026-06-16 — initial.
