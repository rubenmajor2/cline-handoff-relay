#!/usr/bin/env python3
"""Patch cline_tempe_signin.php to give a more useful error message.

Distinguishes timeout (Artemis overloaded — wait + watchdog will recover) from
connection-refused (code-server actually down — operator action required).
"""
import sys

P = '/var/www/emtskills/routes/cline_tempe_signin.php'

OLD = """if ($response === false || $httpCode === 0) {
    http_response_code(502);
    error_log('cline_tempe_signin: code-server /login unreachable: ' . $curlErr);
    echo 'Cline-Tempe is unreachable right now (code-server may be down). Try again in a minute.';
    exit;
}"""

NEW = """if ($response === false || $httpCode === 0) {
    http_response_code(502);
    error_log('cline_tempe_signin: code-server /login unreachable: ' . $curlErr);
    // 2026-05-02 #cline-tempe-signin-unreachable-2026-05-02 — distinguish
    // timeout (Artemis overloaded by bloated ext-hosts; watchdog will recover)
    // from refusal (code-server itself down; operator must investigate).
    $isTimeout = (stripos($curlErr, 'timed out') !== false || stripos($curlErr, 'timeout') !== false);
    $isRefused = (stripos($curlErr, 'connection refused') !== false || stripos($curlErr, 'could not connect') !== false);
    if ($isTimeout) {
        echo 'Cline-Tempe is overloaded right now (code-server is up but timed out responding). ';
        echo 'This usually means one or more Cline ext-host processes have ballooned and are starving the box. ';
        echo 'The exthost-watchdog will renice within ~60s and SIGTERM/SIGKILL within ~10 min if they do not recover on their own. ';
        echo 'Wait 30-60s and refresh, or SSH to artemis and check /var/tmp/cline-watchdog-heartbeat and /var/log/cline-watchdog.log. ';
        echo 'Detail: ' . htmlspecialchars($curlErr);
    } elseif ($isRefused) {
        echo 'Cline-Tempe is truly unreachable (code-server appears to be down on Artemis). ';
        echo 'SSH to artemis and run: systemctl status code-server@emsuserver. ';
        echo 'Detail: ' . htmlspecialchars($curlErr);
    } else {
        echo 'Cline-Tempe is unreachable right now (code-server may be down). Try again in a minute. ';
        echo 'Detail: ' . htmlspecialchars($curlErr);
    }
    exit;
}"""

with open(P) as f:
    src = f.read()

if NEW.split("\n")[3] in src:
    print("already patched, no-op")
    sys.exit(0)

if OLD not in src:
    print("ERROR: original block not found — file structure changed", file=sys.stderr)
    sys.exit(1)

with open(P, "w") as f:
    f.write(src.replace(OLD, NEW))

print("patched OK")
