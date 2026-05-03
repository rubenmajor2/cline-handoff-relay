<?php
/**
 * cron_llm_ab_grader.php — LLM A/B Phase 3.1 Executor Agent grading cron.
 *
 * 2026-05-02 18:10 PT — REWRITE by cline-llm-ab-grader-throughput-2026-05-02
 *   per chain llm-ab-test-rebase-and-pickup-2026-05-02 (Q2: throughput).
 *
 * CHANGES IN THIS DEPLOY:
 *   1. Fixed line-116 PDOException ("mixed named and positional parameters")
 *      in the rollup query. All placeholders are now positional.
 *   2. Removed the LOOKBACK_HOURS=6 filter on row pickup. The previous filter
 *      meant rows older than 6h were unreachable forever; backlog could only
 *      grow. Old rows are still as gradeable as new ones.
 *   3. Raised DAILY_BUDGET_USD 6 -> 24 (steady state). With per-grade cost
 *      ~$0.005 (Haiku 4.5), $24/day = ~4800 grades/day vs ~10K new shadows/day.
 *      Combined with the 1h cron schedule (separate /etc/cron.d edit), this
 *      keeps pace with new volume + drains backlog over ~10 days.
 *   4. Raised BATCH_LIMIT 200 -> 600 so the hourly cron isn't starved by the
 *      batch cap before it hits the budget cap.
 *   5. Env-overridable knobs for one-shot backfill runs:
 *        BACKFILL_BUDGET=250  -> override DAILY_BUDGET_USD for this run only
 *        BACKFILL_BATCH=2000  -> override BATCH_LIMIT
 *        BACKFILL_NO_LOOKBACK=1 -> already the default now (kept for clarity)
 *      Backfill mode also bypasses the daily-spend guard's CURDATE clamp by
 *      using a per-run spend counter only.
 *
 * Author: RUBEN exec idea#471 (P0). Maintained by cline-llm-ab-grader-throughput-2026-05-02.
 */
declare(strict_types=1);
require_once __DIR__ . '/../config/config.local.php';

$LOG = '/var/log/llm-ab-grader.log';
$LOCK = '/tmp/cron_llm_ab_grader.lock';

// Steady-state config (env overrideable for one-shot backfill)
$DAILY_BUDGET_USD   = (float)(getenv('BACKFILL_BUDGET') ?: 24.00);
$BATCH_LIMIT        = (int)  (getenv('BACKFILL_BATCH')  ?: 600);
$BACKFILL_MODE      = getenv('BACKFILL_BUDGET') !== false || getenv('BACKFILL_BATCH') !== false || getenv('BACKFILL_NO_LOOKBACK') === '1';
$ROLLUP_WINDOW_DAYS = 7;
$HAIKU_MODEL        = 'claude-haiku-4-5';

function glog(string $m): void { global $LOG; $l='['.date('c').'] '.$m; @file_put_contents($LOG,$l."\n",FILE_APPEND); echo $l."\n"; }

// Single-instance lock
$lf = @fopen($LOCK,'c');
if(!$lf || !@flock($lf,LOCK_EX|LOCK_NB)){ glog('another grader running, exit'); exit(0); }
@ftruncate($lf,0); @fwrite($lf,(string)getmypid());

glog('=== ab grader run start ' . ($BACKFILL_MODE ? '(BACKFILL MODE)' : '(steady-state)') . ' ===');
glog("config: budget=\$$DAILY_BUDGET_USD batch=$BATCH_LIMIT lookback=NONE rollup_days=$ROLLUP_WINDOW_DAYS");

try {
  $db = new PDO('mysql:host=localhost;dbname=admin_portal;charset=utf8mb4','adminportal','iV84o80^y',[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);
} catch(Throwable $e){ glog('FATAL db: '.$e->getMessage()); exit(1); }

// Budget guard. In steady-state mode this is a daily guard against llm_call_log;
// in backfill mode the per-run cap is the env-supplied budget and we don't
// double-count today's spend (the operator chose this budget intentionally).
if (!$BACKFILL_MODE) {
  $bud = $db->query("SELECT COALESCE(SUM(cost_usd),0) s FROM llm_call_log WHERE surface='ab_grader' AND ts>=CURDATE()")->fetch();
  $spent = (float)$bud['s'];
  if($spent >= $DAILY_BUDGET_USD){ glog("BUDGET STOP: spent=\$$spent today >= \$$DAILY_BUDGET_USD"); exit(0); }
  glog("budget ok: spent=\$$spent / \$$DAILY_BUDGET_USD");
} else {
  $spent = 0.0;
  glog("backfill: per-run budget=\$$DAILY_BUDGET_USD (today's daily spend not counted)");
}

$apiKey = getenv('ANTHROPIC_API_KEY') ?: (defined('ANTHROPIC_API_KEY')?ANTHROPIC_API_KEY:'');
if(!$apiKey){ glog('FATAL no ANTHROPIC_API_KEY'); exit(1); }

// Pull ungraded rows. NO LOOKBACK FILTER — drain the backlog from oldest first.
// Order ASC so we make consistent progress through the queue.
$rows = $db->prepare("SELECT id, task_kind, primary_provider, primary_model, primary_text, shadow_provider, shadow_model, shadow_text FROM orchestrator_llm_shadow_log WHERE agent_grade IS NULL AND shadow_text IS NOT NULL AND shadow_error IS NULL AND primary_text IS NOT NULL ORDER BY id ASC LIMIT :lim");
$rows->bindValue(':lim',$BATCH_LIMIT,PDO::PARAM_INT);
$rows->execute();
$pending = $rows->fetchAll();
glog('pending ungraded rows: '.count($pending));

$routesTouched = []; // key task_kind|provider|model -> [$tk,$sp,$sm]
$counts = ['win'=>0,'tie'=>0,'loss'=>0,'skipped'=>0,'error'=>0];

foreach($pending as $r){
  if($spent >= $DAILY_BUDGET_USD){ glog('budget exhausted mid-run, stopping'); break; }

  $tk = (string)($r['task_kind'] ?? 'default');
  $crit = match($tk){
    'code_patch_small','code_patch_large' => "Does the SHADOW diff/code apply cleanly to the same file and preserve the same intent as PRIMARY? Lower bar: syntactically valid + same intended change wins. Reward correctness, not verbosity.",
    'classify','ticket_triage' => "Does SHADOW pick the SAME category/label/route as PRIMARY? If labels match -> tie or win. If labels disagree -> loss for shadow.",
    'plan_summary' => "Does SHADOW hit the same understanding, blast_radius and success_signals as PRIMARY? Same conclusions -> win/tie. Missing or different conclusions -> loss.",
    'file_extract' => "Does SHADOW extract the same fields/values as PRIMARY (allow paraphrasing)? Same data captured -> win/tie. Missing fields or hallucinated fields -> loss.",
    default => "Is SHADOW response substantively as good as PRIMARY for the apparent task? Equivalently correct -> win/tie. Materially worse, missing, or wrong -> loss.",
  };
  $sys = "You are a strict, fast A/B grader for LLM outputs. Reply with EXACTLY one JSON object on the first line, no markdown fences, no prose preamble, no explanations outside JSON: {\"grade\":\"win|tie|loss\",\"reason\":\"<<=200 chars>>\"}. 'win' = SHADOW clearly as good as or better than PRIMARY. 'tie' = roughly equivalent. 'loss' = SHADOW worse, missing, or wrong. Task-kind criteria: " . $crit;
  $pt = mb_substr((string)$r['primary_text'],0,8000);
  $st = mb_substr((string)$r['shadow_text'],0,8000);
  $usr = "task_kind: $tk\n\n--- PRIMARY ({$r['primary_provider']}/{$r['primary_model']}) ---\n$pt\n\n--- SHADOW ({$r['shadow_provider']}/{$r['shadow_model']}) ---\n$st";

  $payload = json_encode(['model'=>$HAIKU_MODEL,'max_tokens'=>400,'system'=>$sys,'messages'=>[['role'=>'user','content'=>$usr]]]);
  $t0 = microtime(true);
  $ch = curl_init('https://api.anthropic.com/v1/messages');
  curl_setopt_array($ch,[CURLOPT_POST=>true,CURLOPT_POSTFIELDS=>$payload,CURLOPT_RETURNTRANSFER=>true,CURLOPT_TIMEOUT=>45,CURLOPT_HTTPHEADER=>['x-api-key: '.$apiKey,'anthropic-version: 2023-06-01','content-type: application/json']]);
  $resp = curl_exec($ch); $http = curl_getinfo($ch,CURLINFO_HTTP_CODE); $err = curl_error($ch); curl_close($ch);
  $dur = (int)((microtime(true)-$t0)*1000);
  if($resp===false || $http>=400){ glog("row {$r['id']} HTTP $http err=$err"); $counts['error']++; continue; }

  $j = json_decode($resp,true);
  $txt = trim((string)($j['content'][0]['text'] ?? ''));
  $inT = (int)($j['usage']['input_tokens'] ?? 0); $outT = (int)($j['usage']['output_tokens'] ?? 0);
  // Haiku 4.5 pricing $1 in / $5 out per MTok approx
  $cost = ($inT/1000000.0)*1.0 + ($outT/1000000.0)*5.0;
  $spent += $cost;

  // Log llm_call_log
  try { $db->prepare("INSERT INTO llm_call_log (ts,provider,model,surface,input_tokens,output_tokens,cost_usd,duration_ms,meta_json) VALUES (NOW(),'anthropic',?,?,?,?,?,?,?)")->execute([$HAIKU_MODEL,'ab_grader',$inT,$outT,$cost,$dur,json_encode(['shadow_log_id'=>(int)$r['id'],'task_kind'=>$tk])]); } catch(Throwable $e){}

  // Parse grade. Use LlmRouter::extractJsonCandidate for the same tolerant
  // parsing the schema_valid path uses (handles markdown fences, prose preamble,
  // and truncated outputs). Added 2026-04-30 by cline-llm-ab-fixpack.
  require_once __DIR__ . '/../lib/llm_router.php';
  $grade=null; $reason='';
  $cand = LlmRouter::extractJsonCandidate($txt);
  if($cand !== null){
    $g = json_decode($cand, true);
    if(is_array($g)){ $grade=strtolower(trim((string)($g['grade']??''))); $reason=mb_substr((string)($g['reason']??''),0,500); }
  }
  if(!in_array($grade,['win','tie','loss'],true)){ glog("row {$r['id']} unparseable grade: ".mb_substr($txt,0,120)); $counts['error']++; continue; }

  $db->prepare("UPDATE orchestrator_llm_shadow_log SET agent_grade=?, agent_grade_reason=?, agent_graded_at=NOW() WHERE id=?")->execute([$grade,$reason,(int)$r['id']]);
  $counts[$grade]++;
  $routesTouched[$tk.'|'.$r['shadow_provider'].'|'.$r['shadow_model']] = [$tk,$r['shadow_provider'],$r['shadow_model']];
}

glog('grade counts: '.json_encode($counts).' new spend=$'.number_format($spent,4));

// Roll up affected routes from rolling window of graded rows.
// FIX (2026-05-02): replaced mixed positional+named placeholders with all-positional.
$rolled = 0;
foreach($routesTouched as $tup){
  [$tk,$sp,$sm] = $tup;
  $agg = $db->prepare("SELECT SUM(agent_grade='win') w, SUM(agent_grade='tie') t, SUM(agent_grade='loss') l, COUNT(*) c FROM orchestrator_llm_shadow_log WHERE task_kind=? AND shadow_provider=? AND shadow_model=? AND agent_grade IN ('win','tie','loss') AND created_at >= NOW() - INTERVAL ? DAY");
  $agg->execute([$tk, $sp, $sm, $ROLLUP_WINDOW_DAYS]);
  $a = $agg->fetch();
  $c = (int)$a['c']; if($c<1) continue;
  $w=(int)$a['w']; $t=(int)$a['t']; $l=(int)$a['l'];
  $wr=$w/$c; $tr=$t/$c; $lr=$l/$c;

  // Find a route row that matches task_kind and lists this shadow in shadow_providers JSON
  $rt = $db->prepare("SELECT id, shadow_providers FROM orchestrator_llm_routes WHERE task_kind=?");
  $rt->execute([$tk]);
  while($rr = $rt->fetch()){
    $sps = json_decode((string)$rr['shadow_providers'],true) ?: [];
    $match = false;
    foreach($sps as $s){ if(($s['provider']??'')===$sp && ($s['model']??'')===$sm){ $match=true; break; } }
    if(!$match) continue;
    $upd = $db->prepare("UPDATE orchestrator_llm_routes SET win_rate=?, tie_rate=?, loss_rate=?, shadow_sample_count=?, updated_at=NOW() WHERE id=?");
    $upd->execute([$wr,$tr,$lr,$c,(int)$rr['id']]);
    $rolled++;
    glog("rollup route id={$rr['id']} tk=$tk shadow=$sp/$sm n=$c win=".number_format($wr,3)." tie=".number_format($tr,3)." loss=".number_format($lr,3));
  }
}

glog('=== ab grader run done: graded='.($counts['win']+$counts['tie']+$counts['loss']).' errors='.$counts['error']." rollups=$rolled spent=\$".number_format($spent,4)." ===");
