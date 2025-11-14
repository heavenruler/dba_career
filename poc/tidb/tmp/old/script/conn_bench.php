#!/usr/bin/env php
<?php
/**
 * Enhanced TiDB connection / simple query benchmark.
 *
 * Features:
 *  - Modes: single_conn, single_thread_pool, multi_thread
 *  - Warmup phase excluded from stats
 *  - Connection reuse (no per-iteration reconnect except where intentional)
 *  - Prepared statement reuse (if query has no semicolon)
 *  - Per-request latency collection & percentile output (p50/p90/p95/p99/max)
 *  - CLI options for host, port, user, pass, db, total requests, threads, warmup seconds, query, modes, JSON output
 *  - Distinguishes connect errors vs query errors
 *  - Graceful Ctrl+C handling (aggregates partial results)
 *
 * Example:
 *   php conn_bench.php --host=127.0.0.1 --port=4000 --user=root --db=test \
 *       --total=20000 --threads=100 --warmup=2 --query="SELECT 1" --modes=single_conn,multi_thread
 */

declare(strict_types=1);

class BenchConfig {
    public string $host = '172.24.40.25';
    public int $port = 6000;
    public string $user = 'root';
    public string $pass = '1qaz@WSX';
    public string $db = 'test';
    public int $total = 10000;
    public int $threads = 100;
    public float $warmup = 2.0; // seconds
    public string $query = 'SELECT 1';
    /** @var string[] */
    public array $modes = ['single_conn','single_thread_pool','multi_thread'];
    public bool $json = false;
    public bool $debug = false;
    /** @var int[]|null */
    public ?array $threadsList = null; // batch thread counts
    public ?int $perThread = null;      // requests per thread (multi_thread)
    public int $burst = 1;              // queries per iteration
    public ?float $duration = null;      // duration seconds (overrides per-thread/total in multi_thread)
    // CPU sampling of TiDB device
    public bool $cpuSample = false;      // enable sampling
    public float $cpuInterval = 1.0;     // seconds between samples
    public string $cpuLog = 'cpu_remote.csv';
    public string $cpuSource = 'ssh';    // ssh | cluster
    public ?string $sshTarget = null;    // override ssh target (user@host); default derive from host
    public ?string $sshUser = null;      // ssh username for multi-host mode
    /** @var string[] */
    public array $cpuTargets = [];       // generic extra hosts for ssh sampling
    /** @var string[] */
    public array $tidbHosts = [];        // TiDB nodes for per-process stats
    /** @var string[] */
    public array $tiproxyHosts = [];     // TiProxy nodes for per-process stats
}

class BenchStats {
    public string $mode;
    public int $requests = 0;
    public int $errors = 0;
    public int $connectErrors = 0;
    public float $startTime = 0.0;
    public float $endTime = 0.0;
    /** @var float[] ms */
    public array $latencies = [];
    public function duration(): float { return $this->endTime - $this->startTime; }
    public function qps(): float { return $this->requests > 0 && $this->duration() > 0 ? $this->requests / $this->duration() : 0.0; }
}

function parse_args(): BenchConfig {
    $cfg = new BenchConfig();
    $opts = getopt('', [
        'host::','port::','user::','pass::','db::','total::','threads::','threads-list::','per-thread::','burst::','duration::','cpu-sample::','cpu-interval::','cpu-log::','cpu-source::','ssh-target::','ssh-user::','cpu-targets::','tidb-hosts::','tiproxy-hosts::','warmup::','query::','modes::','json::','debug::'
    ]);
    foreach ($opts as $k=>$v) {
        switch ($k) {
            case 'host': $cfg->host = (string)$v; break;
            case 'port': $cfg->port = (int)$v; break;
            case 'user': $cfg->user = (string)$v; break;
            case 'pass': $cfg->pass = (string)$v; break;
            case 'db': $cfg->db = (string)$v; break;
            case 'total': $cfg->total = max(1,(int)$v); break;
            case 'threads': $cfg->threads = max(1,(int)$v); break;
            case 'warmup': $cfg->warmup = max(0.0,(float)$v); break;
            case 'threads-list':
                $cfg->threadsList = array_values(array_filter(array_map(function($x){ return (int)trim($x); }, explode(',', (string)$v)), function($n){ return $n>0; }));
                break;
            case 'per-thread': $cfg->perThread = max(1,(int)$v); break;
            case 'burst': $cfg->burst = max(1,(int)$v); break;
            case 'duration': $cfg->duration = max(0.1,(float)$v); break; // at least 100ms
            case 'cpu-sample': $cfg->cpuSample = true; break;
            case 'cpu-interval': $cfg->cpuInterval = max(0.1,(float)$v); break;
            case 'cpu-log': $cfg->cpuLog = (string)$v; break;
            case 'cpu-source': $cfg->cpuSource = in_array($v,['ssh','cluster'])? (string)$v : 'ssh'; break;
            case 'ssh-target': $cfg->sshTarget = (string)$v; break;
            case 'ssh-user': $cfg->sshUser = (string)$v; break;
            case 'cpu-targets': $cfg->cpuTargets = array_values(array_filter(array_map('trim', explode(',', (string)$v)))); break;
            case 'tidb-hosts': $cfg->tidbHosts = array_values(array_filter(array_map('trim', explode(',', (string)$v)))); break;
            case 'tiproxy-hosts': $cfg->tiproxyHosts = array_values(array_filter(array_map('trim', explode(',', (string)$v)))); break;
            case 'query': $cfg->query = (string)$v; break;
            case 'modes': $cfg->modes = array_filter(array_map('trim', explode(',', (string)$v))); break;
            case 'json': $cfg->json = true; break;
            case 'debug': $cfg->debug = true; break;
        }
    }
    return $cfg;
}

function pdo_connect(BenchConfig $cfg, bool $selectDb = true): PDO {
    $dsn = $selectDb
        ? sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', $cfg->host, $cfg->port, $cfg->db)
        : sprintf('mysql:host=%s;port=%d;charset=utf8mb4', $cfg->host, $cfg->port);
    return new PDO($dsn, $cfg->user, $cfg->pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_TIMEOUT => 10,
        //PDO::ATTR_PERSISTENT => true, // optional; enable if environment supports
    ]);
}

function ensure_database(BenchConfig $cfg): void {
    try {
        $pdo = pdo_connect($cfg, false);
        $stmt = $pdo->prepare('SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = ?');
        $stmt->execute([$cfg->db]);
        if (!$stmt->fetch()) {
            $pdo->exec('CREATE DATABASE `'.$cfg->db.'`');
        }
    } catch (Throwable $e) {
        fwrite(STDERR, "[FATAL] init database failed: {$e->getMessage()}\n");
        exit(1);
    }
}

function percentile(array $vals, float $p): float {
    $n = count($vals); if ($n===0) return 0.0; if ($n===1) return $vals[0];
    $rank = ($p/100)*($n-1); $lo = (int)floor($rank); $hi = (int)ceil($rank);
    if ($lo === $hi) return $vals[$lo];
    $w = $rank - $lo; return $vals[$lo]*(1-$w) + $vals[$hi]*$w;
}

function compute_latency_summary(array $latencies): array {
    sort($latencies);
    return [
        'count' => count($latencies),
        'avg_ms' => count($latencies)? array_sum($latencies)/count($latencies) : 0,
        'p50_ms' => percentile($latencies,50),
        'p90_ms' => percentile($latencies,90),
        'p95_ms' => percentile($latencies,95),
        'p99_ms' => percentile($latencies,99),
        'max_ms' => $latencies? max($latencies):0,
    ];
}

function warmup_phase(PDO $pdo, BenchConfig $cfg): void {
    if ($cfg->warmup <= 0) return;
    $end = microtime(true) + $cfg->warmup;
    $sql = $cfg->query;
    $prepared = !str_contains($sql,';') ? $pdo->prepare($sql) : null;
    while (microtime(true) < $end) {
        try {
            if ($prepared) { $prepared->execute(); } else { $pdo->query($sql); }
        } catch (Throwable $e) { /* ignore warmup errors */ }
    }
}

function run_single_conn(BenchConfig $cfg): BenchStats {
    $s = new BenchStats(); $s->mode='single_conn'; $s->startTime=microtime(true);
    try { $pdo = pdo_connect($cfg); }
    catch (Throwable $e) { $s->connectErrors=$cfg->total; $s->errors=$cfg->total; $s->endTime=microtime(true); return $s; }
    warmup_phase($pdo,$cfg);
    $sql=$cfg->query; $prep = !str_contains($sql,';') ? $pdo->prepare($sql):null;
    for ($i=0;$i<$cfg->total;$i++) {
        $t0 = hrtime(true);
        try {
            if ($prep) { $prep->execute(); } else { $pdo->query($sql); }
        } catch (Throwable $e) { $s->errors++; }
        $s->latencies[] = (hrtime(true)-$t0)/1e6;
        $s->requests++;
    }
    $s->endTime = microtime(true); $pdo=null; return $s;
}

function run_single_thread_pool(BenchConfig $cfg): BenchStats {
    $s = new BenchStats(); $s->mode='single_thread_pool'; $s->startTime=microtime(true);
    $pool=[]; try { for($i=0;$i<$cfg->threads;$i++){ $pool[$i]=pdo_connect($cfg);} } catch(Throwable $e){ $s->connectErrors=$cfg->total; $s->errors=$cfg->total; $s->endTime=microtime(true); return $s; }
    warmup_phase($pool[0],$cfg);
    $sql=$cfg->query; $preparedPool=[]; if(!str_contains($sql,';')){ foreach($pool as $i=>$pdo){ $preparedPool[$i]=$pdo->prepare($sql);} }
    for($i=0;$i<$cfg->total;$i++){
        $idx=$i % $cfg->threads; $pdo=$pool[$idx]; $t0=hrtime(true);
        try { if(isset($preparedPool[$idx])){ $preparedPool[$idx]->execute(); } else { $pdo->query($sql);} }
        catch(Throwable $e){ $s->errors++; }
        $s->latencies[]=(hrtime(true)-$t0)/1e6; $s->requests++;
    }
    $s->endTime=microtime(true); foreach($pool as $pdo){$pdo=null;} return $s;
}

function run_multi_thread(BenchConfig $cfg): BenchStats {
    if (!function_exists('pcntl_fork')) { fwrite(STDERR,"[WARN] pcntl not available, skipping multi_thread.\n"); $s=new BenchStats(); $s->mode='multi_thread'; return $s; }
    $s = new BenchStats(); $s->mode='multi_thread';
    $useDuration = $cfg->duration !== null;
    if ($useDuration) {
        $perThread = 0; // unused
    } else {
        if ($cfg->perThread !== null) {
            $perThread = $cfg->perThread;
            $cfg->total = $perThread * $cfg->threads; // for reporting
        } else {
            $perThread = (int)ceil($cfg->total / $cfg->threads);
        }
    }
    $pids=[];
    $tempDir = sys_get_temp_dir();
    $barrierFile = $tempDir.'/conn_bench_barrier_'.getmypid();
    @unlink($barrierFile);
    for($i=0;$i<$cfg->threads;$i++){
        $pid = pcntl_fork();
        if($pid===-1){ fwrite(STDERR,"[FORK-ERR] \n"); continue; }
        if($pid){ $pids[]=$pid; }
        else {
            $childStats=['errors'=>0,'connectErrors'=>0,'latencies'=>[],'requests'=>0];
            try { $pdo = pdo_connect($cfg); } catch(Throwable $e){ $childStats['connectErrors']=$perThread; $childStats['errors']=$perThread; file_put_contents("$tempDir/conn_bench_{$i}.json", json_encode($childStats)); exit(0);}            
            // warmup only in thread 0 to reduce load
            if($i===0) warmup_phase($pdo,$cfg);
            $sql=$cfg->query; $prep = !str_contains($sql,';') ? $pdo->prepare($sql):null;
            // signal ready by creating a temp file per child
            file_put_contents("$tempDir/conn_bench_ready_{$i}", '1');
            // spin until barrier file exists
            while(!file_exists($barrierFile)) { usleep(1000); }
            if ($useDuration) {
                // children will read end timestamp from barrier file content
                // (written by parent before touching barrier)
                $endTs = null; // assigned after barrier release
                // after barrier loop below will set $endTs
                // loop placed after barrier wait below
            } else {
                for($j=0;$j<$perThread;$j++){
                    if($childStats['requests'] + $i*$perThread >= $cfg->total) break;
                    $t0=hrtime(true);
                    try {
                        if($prep){ for($b=0;$b<$cfg->burst;$b++){ $prep->execute(); } }
                        else { for($b=0;$b<$cfg->burst;$b++){ $pdo->query($sql); } }
                    } catch(Throwable $e){ $childStats['errors'] += $cfg->burst; }
                    $childStats['latencies'][]=(hrtime(true)-$t0)/1e6;
                    $childStats['requests'] += $cfg->burst;
                }
            }
            $pdo=null; file_put_contents("$tempDir/conn_bench_{$i}.json", json_encode($childStats)); exit(0);
        }
    }
    // wait until all children ready
    $readyCount = 0; $expected=$cfg->threads; $deadline=time()+30;
    while($readyCount < $expected && time()<$deadline){
        $readyCount = 0; for($i=0;$i<$expected;$i++){ if(is_file("$tempDir/conn_bench_ready_{$i}")) $readyCount++; }
        if($readyCount < $expected) usleep(5000);
    }
    // start timing only after all children prepared; write end timestamp if duration mode
    $s->startTime = microtime(true);
    if ($useDuration) {
        $endTs = $s->startTime + $cfg->duration;
        file_put_contents($barrierFile, (string)$endTs);
    } else {
        touch($barrierFile);
    }
    // wait children
    foreach($pids as $pid){ pcntl_waitpid($pid,$status); }
    // aggregate
    for($i=0;$i<$cfg->threads;$i++){
        $f = "$tempDir/conn_bench_{$i}.json"; if(!is_file($f)) continue; $data=json_decode(file_get_contents($f), true); @unlink($f);
        if(!$data) continue; $s->errors += $data['errors']; $s->connectErrors += $data['connectErrors']; $s->requests += $data['requests']; $s->latencies = array_merge($s->latencies, $data['latencies']);
        @unlink("$tempDir/conn_bench_ready_{$i}");
    }
    @unlink($barrierFile);
    $s->endTime=microtime(true); return $s;
}

function summarize(BenchStats $s): array {
    $lat = compute_latency_summary($s->latencies);
    return [
        'mode' => $s->mode,
        'requests' => $s->requests,
        'errors' => $s->errors,
        'connect_errors' => $s->connectErrors,
        'duration_s' => round($s->duration(),3),
        'qps' => round($s->qps(),2),
        'lat_avg_ms' => round($lat['avg_ms'],3),
        'lat_p50_ms' => round($lat['p50_ms'],3),
        'lat_p90_ms' => round($lat['p90_ms'],3),
        'lat_p95_ms' => round($lat['p95_ms'],3),
        'lat_p99_ms' => round($lat['p99_ms'],3),
        'lat_max_ms' => round($lat['max_ms'],3),
    ];
}

function install_signal_handler(&$stop){
    if(!function_exists('pcntl_signal')) return;
    pcntl_signal(SIGINT, function() use (&$stop){ $stop = true; });
}

// ---------------- Remote CPU Sampling -----------------
function start_remote_cpu_sampler(BenchConfig $cfg): ?int {
    if(!$cfg->cpuSample) return null;
    if(!function_exists('pcntl_fork')) { fwrite(STDERR,"[CPU] pcntl not available, disable cpu sampling.\n"); return null; }
    $pid = pcntl_fork();
    if($pid === -1){ fwrite(STDERR,"[CPU] fork failed, skip cpu sampling.\n"); return null; }
    if($pid) return $pid; // parent returns child pid
    // build host lists
    $hasMulti = $cfg->cpuTargets || $cfg->tidbHosts || $cfg->tiproxyHosts;
    $target = $cfg->sshTarget ?: $cfg->host; // legacy single-target fallback
    $allHosts = [];
    if($hasMulti){
        $allHosts = array_values(array_unique(array_merge($cfg->cpuTargets, $cfg->tidbHosts, $cfg->tiproxyHosts)));
    } else {
        $allHosts = [$target];
    }
    $log = fopen($cfg->cpuLog,'w');
    if($log) fputcsv($log, ['iso_time','epoch','source','metric','instance','value']);
    $stopFile = sys_get_temp_dir().'/cpu_sampler_stop_'.getmypid();
    $prevStats = []; // host => ['total'=>, 'idle'=>]
    while(!file_exists($stopFile)) {
        $nowIso = date('c'); $now = microtime(true);
        if($cfg->cpuSource === 'cluster') {
            // query cluster_load if exists
            try {
                $pdo = pdo_connect($cfg,false); // default DB OK
                $sql = "SELECT INSTANCE, VALUE FROM information_schema.CLUSTER_LOAD WHERE TYPE='cpu'";
                $res = $pdo->query($sql); $rows = $res? $res->fetchAll(PDO::FETCH_NUM):[];
                if($rows){
                    foreach($rows as $r){ if($log) fputcsv($log, [$nowIso,$now,'cluster','cpu',$r[0],$r[1]]); }
                } else {
                    if($log) fputcsv($log, [$nowIso,$now,'cluster','cpu','n/a','0']);
                }
                $pdo=null;
            } catch(Throwable $e){ if($log) fputcsv($log, [$nowIso,$now,'cluster','error','exception',$e->getMessage()]); }
        } else { // ssh multi / single
            foreach($allHosts as $h){
                $sshHost = $cfg->sshUser ? ($cfg->sshUser.'@'.$h) : $h;
                $statLine = trim((string)@shell_exec("ssh -o BatchMode=yes -o ConnectTimeout=3 " . escapeshellarg($sshHost) . " 'grep ^cpu /proc/stat' 2>/dev/null"));
                $cpuPct = '';
                if($statLine){
                    $parts = preg_split('/\s+/', trim($statLine)); array_shift($parts); $vals=array_map('floatval',$parts);
                    if(count($vals)>=8){
                        $idleAll = $vals[3] + $vals[4]; $total = array_sum($vals);
                        if(isset($prevStats[$h])){ $dtTotal=$total-$prevStats[$h]['total']; $dtIdle=$idleAll-$prevStats[$h]['idle']; if($dtTotal>0){ $cpuPct = 100*($dtTotal-$dtIdle)/$dtTotal; } }
                        $prevStats[$h] = ['total'=>$total,'idle'=>$idleAll];
                    }
                }
                if($cpuPct!==''){ if($log) fputcsv($log, [$nowIso,$now,'ssh','cpu_total',$h,round((float)$cpuPct,2)]); }
                // TiDB per-process
                if(in_array($h, $cfg->tidbHosts)){
                    $psOut = trim((string)@shell_exec("ssh -o BatchMode=yes -o ConnectTimeout=3 " . escapeshellarg($sshHost) . " 'pgrep -f tidb-server | xargs -r ps -o %cpu= -p' 2>/dev/null"));
                    if($psOut!==''){
                        $sum=0; $cnt=0; foreach(preg_split('/\s+/',$psOut) as $c){ if($c==='') continue; if(is_numeric($c)){ $sum += (float)$c; $cnt++; }}
                        if($log){ fputcsv($log, [$nowIso,$now,'ssh','tidb_cpu_sum',$h,round($sum,2)]); fputcsv($log, [$nowIso,$now,'ssh','tidb_proc_count',$h,$cnt]); }
                    }
                }
                // TiProxy per-process
                if(in_array($h, $cfg->tiproxyHosts)){
                    $psOut2 = trim((string)@shell_exec("ssh -o BatchMode=yes -o ConnectTimeout=3 " . escapeshellarg($sshHost) . " 'pgrep -f tiproxy | xargs -r ps -o %cpu= -p' 2>/dev/null"));
                    if($psOut2!==''){
                        $sum=0; $cnt=0; foreach(preg_split('/\s+/',$psOut2) as $c){ if($c==='') continue; if(is_numeric($c)){ $sum += (float)$c; $cnt++; }}
                        if($log){ fputcsv($log, [$nowIso,$now,'ssh','tiproxy_cpu_sum',$h,round($sum,2)]); fputcsv($log, [$nowIso,$now,'ssh','tiproxy_proc_count',$h,$cnt]); }
                    }
                }
            }
        }
        if($log) fflush($log);
        usleep((int)($cfg->cpuInterval*1_000_000));
    }
    if($log) fclose($log);
    exit(0);
}

function stop_remote_cpu_sampler(?int $pid): void {
    if(!$pid) return;
    $stopFile = sys_get_temp_dir().'/cpu_sampler_stop_'.$pid;
    @file_put_contents($stopFile,'1');
    pcntl_waitpid($pid,$status, WNOHANG);
}

function main(): void {
    $cfg = parse_args(); ensure_database($cfg); $all=[]; $stop=false; install_signal_handler($stop);
    $cpuSamplerPid = start_remote_cpu_sampler($cfg);
    $batch = $cfg->threadsList ?: [$cfg->threads];
    $ranSingleConn = false;
    foreach($batch as $t){ if($stop) break; $cfg->threads = $t;
        foreach($cfg->modes as $mode){ if($stop) break; switch($mode){
            case 'single_conn':
                // only run once even in batch thread list (threads not meaningful)
                if($ranSingleConn) continue 2; $st=run_single_conn($cfg); $ranSingleConn=true; break;
            case 'single_thread_pool': $st=run_single_thread_pool($cfg); break;
            case 'multi_thread': $st=run_multi_thread($cfg); break;
            default: fwrite(STDERR,"[WARN] Unknown mode: $mode\n"); continue 2; }
            $row = summarize($st);
            if($cfg->threadsList && $row['mode']!=='single_conn'){ $row['mode'] .= '@'.$t; }
            $all[] = $row;
        }
    }
    if($cfg->json){ echo json_encode($all, JSON_PRETTY_PRINT)."\n"; return; }
    // table
    echo str_repeat('=',140)."\n";
    echo sprintf("%-18s %8s %6s %6s %8s %8s %9s %9s %9s %9s %9s %9s\n",
        'Mode','Reqs','Err','CErr','Dur(s)','QPS','Avg(ms)','P50','P90','P95','P99','Max');
    echo str_repeat('-',140)."\n";
    foreach($all as $row){
        echo sprintf("%-18s %8d %6d %6d %8.2f %8.2f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f\n",
            $row['mode'],$row['requests'],$row['errors'],$row['connect_errors'],$row['duration_s'],$row['qps'],$row['lat_avg_ms'],$row['lat_p50_ms'],$row['lat_p90_ms'],$row['lat_p95_ms'],$row['lat_p99_ms'],$row['lat_max_ms']);
    }
    echo str_repeat('=',140)."\n";
    if($cpuSamplerPid) stop_remote_cpu_sampler($cpuSamplerPid);
}

main();
?>
