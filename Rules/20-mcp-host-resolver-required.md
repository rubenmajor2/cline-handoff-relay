# 20 — Any new MCP doing outbound SSH/exec MUST import the canonical host resolver

Permanent rule. Workspace-scoped. Source incident: 2026-05-05 cline
#1777968053585 (+ follow-ups #1777969865297, #1777970309649). The
emsu-operations MCP was hardcoding `emsuserver@76.167.100.188:2222` as its
SSH target. When the MCP itself ran *on* WOPR (under supergateway stdio),
every `sshExec` hairpinned out to WOPR's own WAN IP. Spectrum's router does
not support NAT loopback on TCP/2222, so every call returned "Connection
refused" and the MCP swallowed the failure into `''`. Symptom:
`server_status` came back 200 with empty disk/load/PHP-FPM blocks. Took
hours to diagnose because the failure looked like "the tool is fine, the
server has nothing to report."

Idea #1195 (P1, approved) is the systemic fix. This rule is **layer 5** of
that idea — the policy layer. Layers 1-4 (canonical resolver, lint gate,
systemd drop-in, daily self-test cron) are code-side mitigations. This rule
is the documentation that makes the fix sticky for future MCP work.

## The bright-line rule

**Any new or modified MCP server that does outbound SSH or `exec`-style
shell-out to WOPR MUST resolve its target host via the canonical
host_resolver, NOT a hardcoded WAN IP or hostname literal.**

Canonical resolver lives at:

- TypeScript / Node MCPs: `mcp-servers/_shared/host_resolver.ts`
  (and the compiled `.js` next to it — same module, just transpiled).
- PHP callers: `lib/host_resolver.php`.

The resolver implements this exact precedence order — do not invent your
own variant:

1. **`EMSU_SSH_HOST` env var wins.** Always. This is the operator's
   override hatch. If the env var is set and non-empty, return it as-is.
2. **Local hairpin detect.** If `hostname()` (or PHP `gethostname()`)
   starts with `wopr` or matches `wopr.*`, return `emsuserver@127.0.0.1`.
   This is the case the source incident missed: when the MCP runs on the
   same box as the SSH target, route over loopback, NOT the WAN IP.
3. **Off-box default.** Return `emsuserver@76.167.100.188`. This is for
   Mac-side stdio callers and other off-WOPR consumers.

The proven reference implementation is in
`mcp-servers/emsu-operations/build/ssh.js` (function `resolveSshHost`).
Copy the shape, don't re-derive it.

## What "outbound SSH/exec to WOPR" means

The rule fires for any of these patterns in a new MCP:

- Direct `ssh emsuserver@<host> ...` invocation via `child_process.exec`,
  `execSync`, `spawn`, `Promise<exec>`, `shell_exec`, `popen`, etc.
- `scp` / `rsync` / any other transport that takes a `user@host` argument.
- Wrappers like `supergateway --stdio`, `mosh`, `autossh` that take a
  remote target string.
- PHP `proc_open` / `passthru` with an `ssh` invocation.
- Any third-party SSH client library where the constructor takes a host
  string (`ssh2`, `node-ssh`, `phpseclib`, etc.).

It does NOT fire for:

- HTTP(S) calls to `https://emsuniversity.com/...` — those go through
  nginx, not SSH, and have no NAT-loopback issue.
- MySQL TCP to `localhost:3306` from a PHP route already running on WOPR.
- Tools that only ever run client-side on the Mac (no on-WOPR deploy
  surface). If the MCP can never run on WOPR by design, skip the rule.

If unsure, apply the rule — false positives cost one extra `import` line.

## What's forbidden

These specific literals MUST NOT appear in MCP source code under
`mcp-servers/*/src/` or `mcp-servers/*/build/`:

- `76.167.100.188` (the WOPR WAN IP — same hairpin trap)
- `emsuserver@76.167.100.188` and any port-suffixed variant
- `wopr.emsuniversity.com` as a literal SSH target (use the resolver)
- Hardcoded port `2222` baked into a host string instead of `-p` flag
  + resolver output

Allowlist (where the WAN IP IS allowed because it's canonical reference,
not a runtime path):

- `mcp-servers/_shared/host_resolver.ts` and `.js` (the resolver itself).
- `lib/host_resolver.php` (PHP twin).
- `docs/HANDOFF_NOTES.md`, `docs/CHANGELOG.md` (postmortem references).
- `scripts/healthcheck.sh` if it specifically tests the WAN path
  (rare — internal monitors should hit loopback).
- `scripts/lint_no_hardcoded_wan_ip.sh` (the lint tool itself, by
  necessity).
- `.clinerules/20-mcp-host-resolver-required.md` (this file).

The lint tool from idea #1195 layer 2 enforces this allowlist
automatically once shipped. Until then, manual self-check applies.

## Required env / systemd posture

Idea #1195 layer 3 also requires a systemd drop-in for every Node-based
MCP that runs on WOPR:

```
# /etc/systemd/system/mcp-<name>.service.d/exec-override.conf
[Service]
Environment=EMSU_SSH_HOST=emsuserver@127.0.0.1
```

This is belt + suspenders. Even if a future code change accidentally
reintroduces a hardcoded WAN IP, the env override forces the resolver's
step-1 path to return loopback. Any new MCP that gets a systemd unit
under `mcp-*.service` MUST also get this drop-in.

The MCPs known to need it as of 2026-05-05:
`mcp-emsu-operations`, `mcp-ruben-control`, `mcp-ruben-orchestrator`,
`mcp-google-drive`, `mcp-imessage-reader`. Add new ones as they ship.

## What I (Cline) MUST do when building a new MCP

1. **Before writing any SSH/exec call**, check whether the canonical
   resolver exists at `mcp-servers/_shared/host_resolver.ts` (or
   `lib/host_resolver.php`). If yes, import it. If no, that's idea #1195
   layer 1 and it should ship before this MCP — escalate, don't reinvent.
2. **Never paste a `76.167.100.188` literal** into MCP source code, even
   "temporarily." The lint gate will catch it; me not writing it in the
   first place is faster.
3. **Add the systemd drop-in** at the same time the MCP gets its
   `mcp-<name>.service` unit. Same commit if possible.
4. **Wire one smoke-test call** (e.g. `server_status`-equivalent) into
   the MCP's tool surface so the daily self-test cron from idea #1195
   layer 4 has something to call. A no-op tool that exercises the SSH
   path counts.
5. **Same-day HANDOFF entry on WOPR** documenting the new MCP's SSH
   call shape and confirming resolver use. Future agents will grep
   HANDOFF before writing yet another wrapper.

## What I MUST do when modifying an existing MCP that does SSH

1. **Grep first.** `grep -rn "76\.167\.100\.188\|wopr.emsuniversity" src/
   build/` in the MCP's directory. Any hit outside the allowlist above is
   pre-existing tech debt — fix it as part of the change, don't add to
   it.
2. **If the MCP doesn't already use the resolver**, that's a regression
   waiting to happen. Add an idea #1195-style follow-up and migrate it
   in the same PR if the change is touching the SSH layer anyway.
3. **Don't break the precedence order.** The 3-step resolver order
   (env → loopback-detect → WAN default) is load-bearing. Don't
   reorder, don't skip a step, don't add a 4th step without the
   incident review that justified it.

## When this rule does NOT apply

- One-off local scripts in `~/Desktop/` or `/tmp/` that touch SSH but
  are not registered as MCPs.
- Cron scripts under `/var/www/emtskills/cron/` that already run on
  WOPR and use `localhost` directly — they have no hairpin surface.
- Mac-side dev tooling that never runs on WOPR by design.
- Test fixtures and mocks that intentionally hardcode IPs to assert
  the resolver behavior.

## Cross-references

- Idea #1195 (approved, P1) — the 5-layer systemic fix. This rule is
  layer 5.
- Idea #1194 (P1) — companion hot-fix for `ruben-control` and
  `ruben-orchestrator` MCPs that had the same bug class.
- `mcp-servers/emsu-operations/build/ssh.js` — proven reference
  implementation of `resolveSshHost`.
- HANDOFF_NOTES.md, 2026-05-05 entries — the diagnostic trail and the
  canonical resolver call shape.
- `.clinerules/22-executor-self-supervision-loops.md` — sister rule on
  the exec side, not the host-resolution side. The two together cover
  the surface where most MCP-driven incidents originate.

## Self-check before any non-trivial MCP-build tool call

Ask: *"Does this MCP do outbound SSH or exec to WOPR?"* If yes, my next
read MUST include `mcp-servers/_shared/host_resolver.ts` (or the PHP
twin), and the SSH layer MUST import it before I write the first
`sshExec`. If the resolver doesn't exist yet and I'm building a new MCP,
I escalate idea #1195 layer 1 first instead of inventing a fourth
incompatible variant.

## Last updated

2026-05-05 11:55 PT — initial rule (idea #1195 layer 5). Source incident:
emsu-operations MCP WAN-IP hairpin returning empty `server_status`
fields. Filed by cline_babysit_other_window 2026-05-05 02:07 PT,
codified into .clinerules same-day per Mac-side rules-write follow-up.
