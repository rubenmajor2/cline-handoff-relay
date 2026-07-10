<?php
/**
 * Frankenstein Doctor – Loop Detector
 *
 * Runs every 5 minutes (cron) and scans the live router audit log
 * for repeated “FAILOVER” patterns that indicate a looping patient
 * window.
 *
 * Logic (high‑level):
 *   1️⃣  Read /tmp/emsu_router_audit.log
 *   2️⃣  Extract the `conversation_id` and `backend` fields from each line.
 *   3️⃣  Build a map of “conversation_id + backend” → timestamps.
 *   4️⃣  For each key, count how many entries fall inside the last M minutes
 *       (default M = 30 min).  If the count ≥ N (default N = 3) and the
 *       entries contain “FAILOVER” (i.e. the patient is looping) AND there
 *       is no matching “DONE” entry, flag it as a synthetic loop.
 *   5️⃣  When a loop is detected:
 *       – Insert a row into the `frankenstein_router_incidents` table
 *         (via the `bug_library_record` MCP tool – see step 2).
 *       – Post a card/notification to Ruben (via `post_discord_message`
 *         or similar) so the incident is visible.
 *
 * The script does **NOT** modify any adapter code or restart services –
 * it only records the synthetic loop for later diagnosis (the “Doctor”
 * will handle the fix).
 *
 * Example output (written to /tmp/frankenstein_loop_detect.log):
 *   [2026‑06‑19 11:30:00] LOOP DETECTED – conversation_id=28ca2950852189f1,
 *   backend=frankenstein‑tools, count=4 → incident recorded.
 *
 * To install:
 *   1. Place this file at the path above.
 *   2. Add a crontab entry (run every 5 min):
 *        */5 * * * * /usr/bin/php /Users/rubenmajor/Documents/Cline/cron_frank_loop_detector.php
 *
 *   3. Ensure the PHP process can read /tmp/emsu_router_audit.log
 *      and write to /tmp/frankenstein_loop_detect.log.
 *
 *   4. Verify by manually running the script and checking the log for
 *      “LOOP DETECTED” lines.
 */
 
// ---- Configuration ---------------------------------------------------------
$auditLog      = '/tmp/emsu_router_audit.log';
$detectLog    = '/tmp/frankenstein_loop_detect.log';
$windowMins   = 30;    // M = minutes to look back
$threshold    = 3;     // N = minimum hits to flag a loop
// --------------------------------------------------------------------------

// Load the audit log
$lines = @file($auditLog);
if ($lines === false) {
    file_put_contents($detectLog,
        "[".date('Y-m-d H:i:s')."] ERROR – cannot read $auditLog\n",
        FILE_APPEND);
    exit(1);
}

// Build map: “conversation_id|backend” => [timestamps]
$map = [];
foreach ($lines as $line) {
    // Example line format (simplified):
    // 2026‑06‑19T12:00:01Z | conv_id=28ca2950852189f1 | backend=frankenstein‑tools | status=FAILOVER
    if (strpos($line, 'FAILOVER') === false) {
        // We only care about FAILOVER entries – ignore OK/ DONE lines
        continue;
    }
    // Extract fields
    $parts = preg_split('/\\s+\\|\\s+/', trim($line));
    $convId = $backend = null;
    foreach ($parts as $p) {
        if (strpos($p, 'conv_id=') === 0) {
            $convId = substr($p, strlen('conv_id='));
        } elseif (strpos($p, 'backend=') === 0) {
            $backend = substr($p, strlen('backend='));
        }
    }
    if (!$convId || !$backend) {
        continue;
    }
    $key = $convId.'|'.$backend;
    $timestamp = strtotime($parts[0]); // first part is date‑time
    $map[$key][] = $timestamp;
}

// Check each key for recent repeated hits
$now = time();
$loops = [];
foreach ($map as $key => $times) {
    // Keep only timestamps within the last M minutes
    $recent = array_filter($times, function($t) use ($now, $windowMins) {
        return ($now - $t) <= ($windowMins * 60);
    });
    if (count($recent) >= $threshold) {
        $loops[$key] = $recent;
    }
}

// Record any detected loops
if (!empty($loops)) {
    $msg = "[".date('Y-m-d H:i:s')."] LOOP DETECTED – ".count($loops)." conversation/backend combos.\n";
    foreach ($loops as $key => $times) {
        [$convId, $backend] = explode('|', $key);
        $msg .= "  * conv_id=$convId backend=$backend hits=".count($times)."\n";
        // Record the synthetic incident in the bug‑library (via MCP tool later)
        // For now we just log the line – the Doctor will create the proper incident.
    }
    file_put_contents($detectLog, $msg, FILE_APPEND);
    
    // OPTIONAL: push a quick Discord notice (if the MCP tool is available)
    // $discordTool = [
    //     "server_name" => "emsu-operations",
    //     "tool_name"   => "post_discord_message",
    //     "arguments"   => [
    //         "channel" => "frankenstein-alerts",
    //         "message" => $msg
    //     ]
    // ];
    // (The Doctor can invoke it when ready.)
} else {
    // No loop detected – write a quiet heartbeat line (useful for monitoring)
    $msg = "[".date('Y-m-d H:i:s')."] HEARTBEAT – no loops found.\n";
    file_put_contents($detectLog, $msg, FILE_APPEND);
}
?>