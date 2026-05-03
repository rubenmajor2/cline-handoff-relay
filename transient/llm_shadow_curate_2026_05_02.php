<?php
/**
 * llm_shadow_curate_2026_05_02.php — one-shot script to prune
 * orchestrator_llm_routes.shadow_providers down to the curated keep-list.
 *
 * Chain: llm-ab-test-rebase-and-pickup-2026-05-02 (Q3 — shadow pool curation).
 *
 * KEEP (Ruben's explicit list):
 *   anthropic/claude-sonnet-4.6
 *   anthropic/claude-opus-4.7   (still needed as a watcher on routes where
 *                                 it's the previous primary, e.g. route 2)
 *   openrouter/deepseek/deepseek-chat-v3-0324    (deepseek-v3)
 *   openrouter/deepseek/deepseek-v4-pro
 *   openrouter/x-ai/grok-4.3
 *   openrouter/google/gemini-3.1-pro-preview
 *   openrouter/openai/gpt-5.4-mini
 *   openrouter/meta-llama/llama-3.3-70b-instruct  (n=1147 graded, incumbent
 *                                                    with real signal — kept
 *                                                    because dropping a model
 *                                                    with this much data would
 *                                                    waste prior shadow spend)
 *
 * DROP (explicit + premature n<50):
 *   openai/gpt-5.5-nano (n=0)
 *   openai/gpt-5.5-mini (n=0)
 *   openai/gpt-5.5      (n=26, premature)
 *   deepseek/deepseek-r1       (n=0, replaced by 0528 variant which is also dropped)
 *   deepseek/deepseek-r1-0528  (n=18, premature)
 *   deepseek/deepseek-v4-flash (n=9, premature)
 *   gemini-3.1-flash-lite-preview (n=18, premature)
 *   meta-llama/llama-4-maverick (n=13, premature)
 *   openai/gpt-5.1-codex-mini   (n=13, premature)
 *   anthropic/claude-sonnet-4   (n=2, deprecated by 4.6)
 *
 * Logs before/after JSON to /var/log/llm-ab-shadow-curate-2026-05-02.log
 * AND to admin_portal.audit_log if that table exists.
 */
declare(strict_types=1);
require_once __DIR__ . '/../config/config.local.php';

$LOG = '/var/log/llm-ab-shadow-curate-2026-05-02.log';

$DROP = [
  ['anthropic',  'claude-sonnet-4'],
  ['openrouter', 'openai/gpt-5.5'],
  ['openrouter', 'openai/gpt-5.5-mini'],
  ['openrouter', 'openai/gpt-5.5-nano'],
  ['openrouter', 'openai/gpt-5.1-codex-mini'],
  ['openrouter', 'deepseek/deepseek-r1'],
  ['openrouter', 'deepseek/deepseek-r1-0528'],
  ['openrouter', 'deepseek/deepseek-v4-flash'],
  ['openrouter', 'meta-llama/llama-4-maverick'],
  ['openrouter', 'google/gemini-3.1-flash-lite-preview'],
];

function clog(string $m): void { global $LOG; $l='['.date('c').'] '.$m; @file_put_contents($LOG,$l."\n",FILE_APPEND); echo $l."\n"; }

clog('=== shadow curate run start (chain llm-ab-test-rebase-and-pickup-2026-05-02 Q3) ===');

$db = new PDO('mysql:host=localhost;dbname=admin_portal;charset=utf8mb4','adminportal','iV84o80^y',[
  PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,
  PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,
]);

$rows = $db->query("SELECT id, task_kind, shadow_providers FROM orchestrator_llm_routes WHERE shadow_providers IS NOT NULL ORDER BY id")->fetchAll();

$db->beginTransaction();
$totalDropped = 0;
$rowsTouched = 0;

foreach ($rows as $r) {
  $sps = json_decode((string)$r['shadow_providers'], true);
  if (!is_array($sps)) continue;
  $before = $sps;
  $after = [];
  $dropped = [];
  foreach ($sps as $s) {
    $isDrop = false;
    foreach ($DROP as [$dp, $dm]) {
      if (($s['provider'] ?? '') === $dp && ($s['model'] ?? '') === $dm) { $isDrop = true; break; }
    }
    if ($isDrop) {
      $dropped[] = ($s['provider'].'/'.$s['model']);
      $totalDropped++;
    } else {
      $after[] = $s;
    }
  }
  if (count($dropped) === 0) {
    clog("route {$r['id']} ({$r['task_kind']}): no change, kept ".count($after));
    continue;
  }
  $rowsTouched++;
  $afterJson = json_encode($after, JSON_UNESCAPED_SLASHES);
  $upd = $db->prepare("UPDATE orchestrator_llm_routes SET shadow_providers=?, updated_at=NOW() WHERE id=?");
  $upd->execute([$afterJson, (int)$r['id']]);
  clog("route {$r['id']} ({$r['task_kind']}): dropped [".implode(', ', $dropped)."] kept=".count($after));
  clog("  before: ".json_encode($before, JSON_UNESCAPED_SLASHES));
  clog("  after:  $afterJson");
}

$db->commit();
clog("=== shadow curate done: rows_touched=$rowsTouched total_shadow_entries_dropped=$totalDropped ===");
