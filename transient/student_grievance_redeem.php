<?php
declare(strict_types=1);

/**
 * routes/student_grievance_redeem.php
 *
 * GI-3: token-gated public-facing redeem page. Step 2 of the grievance
 * intake redesign (after the student requests a code via GI-2 and
 * receives the magic-link email).
 *
 * Auth: NONE — token-gated. ?t=<raw> from the email is HMAC-verified by
 * lib/grievance_intake.php::verifyIntakeCode.
 *
 * Workflow:
 *   GET  ?t=<token>   show policy/form links + 3-checkbox required-reading + file upload
 *   POST ?t=<token>   validate uploads, copy file, INSERT grievance row with
 *                      student_id from token, mark token used.
 *
 * Voice: rules 02 (no apologies), 13 (Good Morning/Afternoon/Evening),
 *        15 (no internal-reasoning narration).
 */

require_once __DIR__ . '/../lib/grievance_intake.php';
require_once __DIR__ . '/../lib/db.php';

/**
 * Inline minimal text extraction. Full Vision OCR fallback runs later
 * via cron_grievance_auto_analyze.php (it picks up rows where
 * ai_analysis_json IS NULL). We deliberately do NOT pull
 * routes/api/grievance_api.php because it requires an admin session.
 */
function gi3_extract_text(string $filePath, string $mime): string {
    if ($mime === 'application/pdf') {
        $out = (string)@shell_exec('pdftotext -layout ' . escapeshellarg($filePath) . ' - 2>/dev/null');
        return gi3_sanitize_utf8($out);
    }
    // JPG/PNG: leave empty; auto-analyze cron + Vision OCR will populate.
    return '';
}
function gi3_sanitize_utf8(?string $s): string {
    if ($s === null) return '';
    $s = mb_convert_encoding($s, 'UTF-8', 'UTF-8');
    return (string)preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u', '', $s);
}

date_default_timezone_set('America/Los_Angeles');

const GI3_POLICY_PDF_URL  = '/emtskills/uploads/7-1100_Student_Grievance_Policy.pdf';
const GI3_POLICY_GDOC_URL = 'https://docs.google.com/document/d/1xwZ-0M-Z0oQoTQMTyiNvrtcyEtnh1roU/edit';
const GI3_FORM_PDF_URL    = '/emtskills/uploads/blank_grievance_form.pdf';
const GI3_FORM_GDOC_URL   = 'https://docs.google.com/document/d/1fxzrsN8xWirD8sHO37FodRNQVrDkQiZC/edit';
const GI3_MAX_BYTES       = 20 * 1024 * 1024; // 20 MB per chain spec
const GI3_ALLOWED_MIME    = ['application/pdf', 'image/jpeg', 'image/png'];

function gi3_greeting(): string {
    $h = (int)date('G');
    if ($h < 12) return 'Good Morning';
    if ($h < 17) return 'Good Afternoon';
    return 'Good Evening';
}

function gi3_render_error(string $title, string $body): string {
    $t = htmlspecialchars($title, ENT_QUOTES, 'UTF-8');
    $b = htmlspecialchars($body, ENT_QUOTES, 'UTF-8');
    return <<<HTML
<!doctype html><html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>{$t} &mdash; EMS University</title>
<style>body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;background:#f6f7fa;color:#1a1a1a;line-height:1.5}.wrap{max-width:560px;margin:60px auto;padding:0 16px;text-align:center}.card{background:#fff;border:1px solid #d6dae2;border-radius:8px;padding:32px 24px;box-shadow:0 1px 3px rgba(0,0,0,0.05)}.x{width:60px;height:60px;border-radius:50%;background:#b00020;color:#fff;line-height:60px;font-size:36px;margin:0 auto 16px}h1{margin:0 0 8px;color:#0e3866}p{color:#333}.muted{color:#555;font-size:14px}a{color:#1a5490}</style>
</head><body><div class="wrap"><div class="card"><div class="x">!</div><h1>{$t}</h1><p>{$b}</p><p class="muted">Email <a href="mailto:grievance@emsuniversity.com">grievance@emsuniversity.com</a> if you need help.</p></div></div></body></html>
HTML;
}

// -----------------------------------------------------------------------------
// 1) Verify token.
// -----------------------------------------------------------------------------
$rawToken = (string)($_GET['t'] ?? $_POST['t'] ?? '');
if ($rawToken === '') {
    http_response_code(400);
    echo gi3_render_error('Missing access link',
        'This page can only be opened via the link emailed to you. Click the link from your email again.');
    exit;
}

$verified = verifyIntakeCode($rawToken);
if (!$verified['ok']) {
    http_response_code(403);
    $msg = match ($verified['reason']) {
        'bad_format', 'bad_signature' => 'This link is not valid. Request a fresh code from the request page.',
        'not_found'                   => 'This link is no longer recognized. Request a fresh code from the request page.',
        'expired'                     => 'This link has expired. Request a fresh code from the request page.',
        'already_used'                => 'This link has already been used to file a grievance. If you need to file another or correct one, request a fresh code from the request page.',
        default                       => 'This link cannot be used right now. Email grievance@emsuniversity.com for help.',
    };
    echo gi3_render_error('Link not active', $msg);
    exit;
}

$tokenRow = $verified['row'];
$studentId = (int)$tokenRow['matched_student_id'];

// Pull the matched student record so we can prefill the grievance row.
$pdo = function_exists('getPortalPdo') ? getPortalPdo() : db('portal');
$st = $pdo->prepare('SELECT * FROM Students WHERE id = ? LIMIT 1');
$st->execute([$studentId]);
$student = $st->fetch(PDO::FETCH_ASSOC);
if (!$student) {
    http_response_code(500);
    echo gi3_render_error('Account record missing',
        'We could not load your enrollment record. Email grievance@emsuniversity.com so we can help.');
    exit;
}
$studentEmail = $tokenRow['email_sent_to'] ?: ($student['email'] ?? '');
$studentName  = trim(((string)($student['first_name'] ?? '')) . ' ' . ((string)($student['last_name'] ?? '')));
if ($studentName === '') $studentName = (string)$tokenRow['name_typed'];

// -----------------------------------------------------------------------------
// 2) POST: validate + create grievance.
// -----------------------------------------------------------------------------
$errors = [];
$success = false;
$createdGrvNumber = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Re-verify (token may have been consumed in another tab during a double-submit)
    $verified2 = verifyIntakeCode($rawToken);
    if (!$verified2['ok']) {
        $alreadyMsg = $verified2['reason'] === 'already_used'
            ? 'This grievance link was already used. If you need to file another, request a fresh code from the request page.'
            : 'This link is no longer active. Request a fresh code from the request page.';
        echo gi3_render_error('Link no longer active', $alreadyMsg);
        exit;
    }

    // Required-reading checkboxes
    $ackPolicy = !empty($_POST['ack_policy']);
    $ackForm   = !empty($_POST['ack_form']);
    $ackHand   = !empty($_POST['ack_handwriting']);
    if (!$ackPolicy)  $errors['ack_policy']      = 'Please confirm you have read the policy.';
    if (!$ackForm)    $errors['ack_form']        = 'Please confirm you have read the blank form.';
    if (!$ackHand)    $errors['ack_handwriting'] = 'Please confirm your form is in your own handwriting.';

    // File upload
    $file = $_FILES['grievance_file'] ?? null;
    if (!$file || ($file['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_NO_FILE) {
        $errors['grievance_file'] = 'Please attach your completed grievance form.';
    } elseif (($file['error'] ?? -1) !== UPLOAD_ERR_OK) {
        $codeMap = [
            UPLOAD_ERR_INI_SIZE   => 'File exceeds the server upload size limit. Please send a smaller file (under 20 MB).',
            UPLOAD_ERR_FORM_SIZE  => 'File exceeds the form size limit. Please send a smaller file (under 20 MB).',
            UPLOAD_ERR_PARTIAL    => 'The upload was interrupted. Try again.',
            UPLOAD_ERR_NO_TMP_DIR => 'Server temp directory missing. Email grievance@emsuniversity.com.',
            UPLOAD_ERR_CANT_WRITE => 'Server could not save the file. Email grievance@emsuniversity.com.',
            UPLOAD_ERR_EXTENSION  => 'Upload blocked by server extension. Email grievance@emsuniversity.com.',
        ];
        $errors['grievance_file'] = $codeMap[(int)$file['error']] ?? ('Upload error code: ' . (int)$file['error']);
    } elseif ((int)$file['size'] > GI3_MAX_BYTES) {
        $errors['grievance_file'] = 'File too large (' . round($file['size']/1024/1024, 1) . ' MB). Maximum: 20 MB.';
    } else {
        $finfo = new finfo(FILEINFO_MIME_TYPE);
        $mime  = (string)$finfo->file($file['tmp_name']);
        if (!in_array($mime, GI3_ALLOWED_MIME, true)) {
            $errors['grievance_file'] = 'Unsupported file type (' . htmlspecialchars($mime) . '). Accepted: PDF, JPG, PNG.';
        }
    }

    if (empty($errors)) {
        // Save file to /uploads/grievances/YYYY/MM/
        $uploadDir = '/var/www/emtskills/uploads/grievances/' . date('Y/m');
        if (!is_dir($uploadDir)) @mkdir($uploadDir, 0755, true);

        $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION) ?: 'pdf');
        if (!in_array($ext, ['pdf','jpg','jpeg','png'], true)) {
            // normalize from MIME so on-disk extension is always sane
            $ext = $mime === 'application/pdf' ? 'pdf' : ($mime === 'image/png' ? 'png' : 'jpg');
        }
        $safeName = 'GRV-' . date('Ymd-His') . '-' . bin2hex(random_bytes(4)) . '.' . $ext;
        $filePath = $uploadDir . '/' . $safeName;
        if (!@move_uploaded_file($file['tmp_name'], $filePath)) {
            $errors['__global'] = 'We could not save your file. Try again or email grievance@emsuniversity.com.';
        } else {
            // Inline pdftotext extraction; cron_grievance_auto_analyze.php
            // will run Vision OCR + AI analysis on this row asynchronously.
            $extractedText = gi3_extract_text($filePath, $mime);

            // Generate unique grievance number (year-anchored, collision-safe).
            $year = date('Y');
            $grievanceNumber = '';
            for ($retry = 0; $retry < 10; $retry++) {
                $maxStmt = $pdo->prepare("SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(grievance_number, '-', -1) AS UNSIGNED)), 0) FROM grievances WHERE grievance_number LIKE ?");
                $maxStmt->execute(['GRV-' . $year . '-%']);
                $maxSeq = (int)$maxStmt->fetchColumn();
                $candidate = 'GRV-' . $year . '-' . str_pad((string)($maxSeq + 1 + $retry), 4, '0', STR_PAD_LEFT);
                $existsStmt = $pdo->prepare("SELECT COUNT(*) FROM grievances WHERE grievance_number = ?");
                $existsStmt->execute([$candidate]);
                if ((int)$existsStmt->fetchColumn() === 0) { $grievanceNumber = $candidate; break; }
            }
            if ($grievanceNumber === '') {
                $errors['__global'] = 'Could not assign a grievance number. Try again or email grievance@emsuniversity.com.';
            } else {
                $today = date('Y-m-d');
                $responseDue  = date('Y-m-d', strtotime('+10 weekdays'));
                $committeeDue = date('Y-m-d', strtotime('+30 days'));
                $finalDue     = date('Y-m-d', strtotime('+45 days'));
                $subject = 'Student Grievance — ' . $studentName;
                $category = 'other';
                $severity = 'medium';

                $ins = $pdo->prepare("INSERT INTO grievances (
                    student_id, moodle_user_id, student_name, student_email, student_phone,
                    class_section, location, state_of_course, course_start_date, course_end_date, enrollment_status,
                    grievance_number, date_filed, subject, category, severity,
                    original_filename, file_path, file_size_bytes, file_type, extracted_text,
                    status, response_due_date, committee_deadline, final_deadline, created_by
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending_review', ?, ?, ?, 'student-self-service-redeem')");

                $ins->execute([
                    $studentId,
                    $student['moodle_user_id'] ?? null,
                    $studentName,
                    $studentEmail,
                    $student['phone'] ?? null,
                    $student['class_section'] ?? null,
                    $student['location'] ?? null,
                    $student['state_of_emt_course'] ?? null,
                    $student['course_start_date'] ?? null,
                    $student['course_end_date'] ?? null,
                    $student['enrollment_status'] ?? 'active',
                    $grievanceNumber,
                    $today,
                    $subject,
                    $category,
                    $severity,
                    (string)$file['name'],
                    $filePath,
                    (int)$file['size'],
                    $mime,
                    $extractedText,
                    $responseDue,
                    $committeeDue,
                    $finalDue,
                ]);
                $newId = (int)$pdo->lastInsertId();

                // Mark token used + link to the grievance row created.
                $up = $pdo->prepare('UPDATE grievance_intake_tokens SET used_at = NOW(), used_ip = ?, used_ua = ?, submission_grievance_id = ? WHERE id = ?');
                $up->execute([
                    (string)($_SERVER['REMOTE_ADDR'] ?? ''),
                    substr((string)($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 255),
                    $newId,
                    (int)$tokenRow['id'],
                ]);

                // Status history. logStatusChange expects (pdo, id, old, new, by, notes).
                if (function_exists('logStatusChange')) {
                    try { logStatusChange($pdo, $newId, null, 'pending_review', 'student-self-service-redeem', 'Filed via redeem page (intake_token id=' . (int)$tokenRow['id'] . ')'); }
                    catch (Throwable $e) { error_log('[gi3] logStatusChange failed: ' . $e->getMessage()); }
                }

                // Internal comment with provenance for the staff queue.
                try {
                    $cm = $pdo->prepare("INSERT INTO grievance_comments (grievance_id, author, comment, is_internal, created_at) VALUES (?, 'System', ?, 1, NOW())");
                    $cm->execute([$newId, "Filed via student self-service redeem page (GI-3). Intake token id=" . (int)$tokenRow['id'] . ", IP=" . ($_SERVER['REMOTE_ADDR'] ?? '?') . "."]);
                } catch (Throwable $e) {
                    error_log('[gi3] grievance_comments insert failed: ' . $e->getMessage());
                }

                // Trigger AI auto-analyze in-process if available; cron will pick it up otherwise.
                if (function_exists('autoTriageNewGrievance')) {
                    try { autoTriageNewGrievance($pdo, $newId, 'student-self-service-redeem'); }
                    catch (Throwable $e) { error_log('[gi3] autoTriageNewGrievance failed: ' . $e->getMessage()); }
                }

                $createdGrvNumber = $grievanceNumber;
                $success = true;
            }
        }
    }
}

// -----------------------------------------------------------------------------
// 3) Render: success page or form.
// -----------------------------------------------------------------------------
if ($success) {
    $g = htmlspecialchars($createdGrvNumber, ENT_QUOTES, 'UTF-8');
    echo <<<HTML
<!doctype html><html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>Grievance filed &mdash; {$g}</title>
<style>body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;background:#f6f7fa;color:#1a1a1a;line-height:1.5}.wrap{max-width:560px;margin:60px auto;padding:0 16px;text-align:center}.card{background:#fff;border:1px solid #d6dae2;border-radius:8px;padding:32px 24px;box-shadow:0 1px 3px rgba(0,0,0,0.05)}.ok{width:60px;height:60px;border-radius:50%;background:#1f7f3a;color:#fff;line-height:60px;font-size:36px;margin:0 auto 16px}h1{margin:0 0 8px;color:#0e3866}p{color:#333}.muted{color:#555;font-size:14px}strong{color:#0e3866}</style>
</head><body><div class="wrap"><div class="card"><div class="ok">&check;</div><h1>Grievance received</h1><p>Your grievance has been filed under reference <strong>{$g}</strong>.</p><p>Our administrative team will review it for completeness. You will be contacted by email if anything additional is needed, and again when the committee issues a decision.</p><p class="muted">You can close this page now.</p></div></div></body></html>
HTML;
    exit;
}

$greeting = gi3_greeting();
$nameSafe = htmlspecialchars($studentName, ENT_QUOTES, 'UTF-8');
$emailSafe = htmlspecialchars($studentEmail, ENT_QUOTES, 'UTF-8');
$tokSafe = htmlspecialchars($rawToken, ENT_QUOTES, 'UTF-8');

$globalErr = !empty($errors['__global'])
    ? '<div class="alert alert-error">' . htmlspecialchars($errors['__global'], ENT_QUOTES, 'UTF-8') . '</div>'
    : '';

$ackPolicyChecked = !empty($_POST['ack_policy']) ? 'checked' : '';
$ackFormChecked   = !empty($_POST['ack_form']) ? 'checked' : '';
$ackHandChecked   = !empty($_POST['ack_handwriting']) ? 'checked' : '';

$errPolicy = isset($errors['ack_policy']) ? '<div class="field-error">' . htmlspecialchars($errors['ack_policy'], ENT_QUOTES, 'UTF-8') . '</div>' : '';
$errForm   = isset($errors['ack_form']) ? '<div class="field-error">' . htmlspecialchars($errors['ack_form'], ENT_QUOTES, 'UTF-8') . '</div>' : '';
$errHand   = isset($errors['ack_handwriting']) ? '<div class="field-error">' . htmlspecialchars($errors['ack_handwriting'], ENT_QUOTES, 'UTF-8') . '</div>' : '';
$errFile   = isset($errors['grievance_file']) ? '<div class="field-error">' . htmlspecialchars($errors['grievance_file'], ENT_QUOTES, 'UTF-8') . '</div>' : '';

?><!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>File your grievance &mdash; EMS University</title>
<style>
:root { --primary:#1a5490; --primary-dark:#0e3866; --bg:#f6f7fa; --card:#fff; --border:#d6dae2; --error:#b00020; --ok:#1f7f3a; --text:#1a1a1a; --muted:#555; }
* { box-sizing: border-box; }
body { margin:0; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif; background:var(--bg); color:var(--text); line-height:1.5; }
.wrap { max-width:760px; margin:32px auto; padding:0 16px; }
.card { background:var(--card); border:1px solid var(--border); border-radius:8px; padding:24px; box-shadow:0 1px 3px rgba(0,0,0,0.05); margin-bottom:16px; }
h1 { margin:0 0 8px; font-size:22px; color:var(--primary-dark); }
h2 { margin:0 0 12px; font-size:16px; color:var(--primary-dark); }
.muted { color:var(--muted); font-size:14px; }
.alert { padding:12px 14px; border-radius:6px; margin-bottom:16px; }
.alert-error { background:#fdecea; color:var(--error); border:1px solid #f5c2bf; }
.alert-info { background:#e8f1fb; color:var(--primary-dark); border:1px solid #c4d8ef; }
.callout-warn { background:#fff8db; border:1px solid #ffe69a; color:#5a4500; padding:12px 14px; border-radius:6px; margin-bottom:12px; }
.btn-link { display:inline-block; background:var(--primary-dark); color:#fff; padding:10px 16px; border-radius:6px; text-decoration:none; font-weight:600; margin:4px 6px 4px 0; }
.btn-link.alt { background:#fff; color:var(--primary-dark); border:1px solid var(--primary-dark); }
.btn-link:hover { opacity:0.9; }
.required-reading { padding-left:0; list-style:none; margin:0; }
.required-reading li { padding:10px 0; border-top:1px solid var(--border); }
.required-reading li:first-child { border-top:none; }
.required-reading label { display:flex; gap:10px; align-items:flex-start; cursor:pointer; }
.required-reading input { margin-top:4px; transform:scale(1.2); }
.field { margin-bottom:18px; }
.field label { display:block; font-weight:600; margin-bottom:4px; color:var(--primary-dark); }
.field-help { font-size:13px; color:var(--muted); margin-bottom:8px; }
.field input[type=file] { padding:8px 0; font-family:inherit; }
.field-error { color:var(--error); font-size:13px; margin-top:6px; font-weight:500; }
.actions { display:flex; gap:10px; align-items:center; margin-top:24px; padding-top:16px; border-top:1px solid var(--border); flex-wrap:wrap; }
.btn-submit { background:var(--primary); color:#fff; border:none; padding:12px 22px; font-size:16px; font-weight:600; border-radius:6px; cursor:pointer; }
.btn-submit:hover { background:var(--primary-dark); }
.btn-submit:disabled { background:#999; cursor:not-allowed; }
.footer-note { margin-top:12px; font-size:12px; color:var(--muted); text-align:center; }
.kv { font-size:14px; color:var(--text); }
.kv strong { color:var(--primary-dark); }
</style>
</head>
<body>
<div class="wrap">

  <div class="card">
    <h1><?= $greeting ?>, <?= $nameSafe ?>.</h1>
    <div class="muted">This page accepts your filled-out and signed grievance form. The link below is tied to your enrollment record and expires when used or after 24 hours.</div>
    <div class="kv" style="margin-top:10px;">Filing as <strong><?= $nameSafe ?></strong> &middot; Email on file: <strong><?= $emailSafe ?></strong></div>
  </div>

  <div class="card">
    <h2>Step 1 &mdash; Read the policy and form</h2>
    <div class="callout-warn"><strong>Required reading.</strong> Please read both before you submit. Your form must be in <em>your own handwriting</em>.</div>
    <p>
      <a class="btn-link" href="<?= GI3_POLICY_PDF_URL ?>" target="_blank" rel="noopener">Read the policy (PDF)</a>
      <a class="btn-link alt" href="<?= GI3_POLICY_GDOC_URL ?>" target="_blank" rel="noopener">Policy &mdash; Google Doc</a>
    </p>
    <p>
      <a class="btn-link" href="<?= GI3_FORM_PDF_URL ?>" target="_blank" rel="noopener">Download the blank form (PDF)</a>
      <a class="btn-link alt" href="<?= GI3_FORM_GDOC_URL ?>" target="_blank" rel="noopener">Form &mdash; Google Doc</a>
    </p>
  </div>

  <div class="card">
    <h2>Step 2 &mdash; Confirm and submit</h2>
    <?= $globalErr ?>
    <form method="post" enctype="multipart/form-data" autocomplete="off" novalidate>
      <input type="hidden" name="t" value="<?= $tokSafe ?>">

      <ul class="required-reading">
        <li><label><input type="checkbox" name="ack_policy" value="1" <?= $ackPolicyChecked ?>> I have read the EMS University Student Grievance Policy (7-1100).</label><?= $errPolicy ?></li>
        <li><label><input type="checkbox" name="ack_form" value="1" <?= $ackFormChecked ?>> I have read the blank Student Grievance Form (7-1100.01).</label><?= $errForm ?></li>
        <li><label><input type="checkbox" name="ack_handwriting" value="1" <?= $ackHandChecked ?>> I understand the form must be in my own handwriting.</label><?= $errHand ?></li>
      </ul>

      <div class="field" style="margin-top:18px;">
        <label for="grievance_file">Upload your completed form</label>
        <div class="field-help">Accepted: PDF, JPG, or PNG. Maximum 20 MB.</div>
        <input type="file" id="grievance_file" name="grievance_file" accept=".pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png" required>
        <?= $errFile ?>
      </div>

      <div class="actions">
        <button type="submit" class="btn-submit">File my grievance</button>
        <span class="muted" style="font-size:13px;">After you file, the form is sent to the EMS University Grievance Committee for review.</span>
      </div>
    </form>
  </div>

  <div class="footer-note">
    EMS University &middot; Grievance filing portal &middot; Questions: <a href="mailto:grievance@emsuniversity.com">grievance@emsuniversity.com</a>
  </div>

</div>
</body>
</html>
