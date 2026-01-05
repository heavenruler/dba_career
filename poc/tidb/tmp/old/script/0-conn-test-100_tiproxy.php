#!/usr/bin/env php
<?php
/**
 * TiDB 連接測試腳本
 * 
 * 此腳本用於測試 TiDB 數據庫的連接性能，包括：
 * - 單線程單連接測試
 * - 單線程多連接測試  
 * - 多線程多連接測試
 * 
 * 測試指標包括：
 * - 平均響應時間
 * - 錯誤率
 * - 每秒請求數
 * - 總執行時間
 * 
 * 注意：請確保 TiDB 服務正在運行，並根據實際環境修改連接參數
 */

class TiDBConnectionTester {
    private $host;
    private $user;
    private $pass;
    private $port;
    private $db;
    private $results = [];
    private $totalTests = 10000;
    private $numThreads = 100;

    public function __construct($host, $user, $pass, $port, $db) {
        $this->host = $host;
        $this->user = $user;
        $this->pass = $pass;
        $this->port = $port;
        $this->db = $db;
        
        // 初始化時確保數據庫存在
        $this->ensureDatabase();
    }

    private function ensureDatabase() {
        try {
            //echo "正在連接到 TiDB: {$this->host}:{$this->port}\n";
            //echo "用戶: {$this->user}\n";
            //echo "密碼: " . (empty($this->pass) ? '(空)' : '(已設置)') . "\n";
            
            // 使用 PDO 連接到 TiDB（不指定數據庫）
            $dsn = "mysql:host={$this->host};port={$this->port};charset=utf8mb4";
            $pdo = new PDO($dsn, $this->user, $this->pass, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_TIMEOUT => 10
            ]);

            //echo "成功連接到 TiDB!\n";
            
            // 檢查 TiDB 版本
            $stmt = $pdo->query("SELECT VERSION()");
            $version = $stmt->fetchColumn();
            //echo "TiDB 版本: " . $version . "\n";

            // 檢查數據庫是否存在
            $stmt = $pdo->query("SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '{$this->db}'");
            
            if ($stmt->rowCount() == 0) {
                // 數據庫不存在，創建它
                //echo "數據庫 {$this->db} 不存在，正在創建...\n";
                $pdo->exec("CREATE DATABASE {$this->db}");
                //echo "數據庫 {$this->db} 創建成功!\n";
            } else {
                //echo "數據庫 {$this->db} 已存在\n";
            }

            $pdo = null;
        } catch (Exception $e) {
            //echo "初始化數據庫時發生錯誤: " . $e->getMessage() . "\n";
            //echo "請檢查 TiDB 服務狀態和連接參數\n";
            die("Error initializing database: " . $e->getMessage());
        }
    }

    // 單線程單連接測試
    public function testSingleThreadSingleConnection() {
        //echo "Testing Single Thread Single Connection...\n";
        $start = microtime(true);
        $errors = 0;
        $totalTime = 0;
        
        try {
            $dsn = "mysql:host={$this->host};port={$this->port};dbname={$this->db};charset=utf8mb4";
            $pdo = new PDO($dsn, $this->user, $this->pass, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_TIMEOUT => 10
            ]);
            
            for ($i = 0; $i < $this->totalTests; $i++) {
                $queryStart = microtime(true);
                
                try {
                    // 測試基本查詢
                    $stmt = $pdo->query("SELECT 1");
                    if (!$stmt) {
                        $errors++;
                    }
                    
                    // 測試 TiDB 版本信息
                    $versionStmt = $pdo->query("SELECT VERSION()");
                    if ($versionStmt) {
                        $version = $versionStmt->fetchColumn();
                        if (strpos($version, 'TiDB') !== false) {
                            // 確認是 TiDB
                        }
                    }
                } catch (Exception $e) {
                    $errors++;
                }
                
                $totalTime += (microtime(true) - $queryStart);
            }
            
            $pdo = null;
        } catch (Exception $e) {
            echo "連接失敗: " . $e->getMessage() . "\n";
            return $this->calculateResults('single_thread_single_conn', $start, 0, $this->totalTests);
        }
        
        return $this->calculateResults('single_thread_single_conn', $start, $totalTime, $errors);
    }

    // 單線程多連接測試
    public function testSingleThreadMultiConnection() {
        //echo "Testing Single Thread Multi Connection...\n";
        $start = microtime(true);
        $errors = 0;
        $totalTime = 0;
    
        // 創建連接池
        $connectionPool = [];
        try {
            for ($i = 0; $i < $this->numThreads; $i++) {
                $dsn = "mysql:host={$this->host};port={$this->port};dbname={$this->db};charset=utf8mb4";
                $connectionPool[] = new PDO($dsn, $this->user, $this->pass, [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_TIMEOUT => 10
                ]);
            }
        } catch (Exception $e) {
            echo "創建連接池失敗: " . $e->getMessage() . "\n";
            return $this->calculateResults('single_thread_multi_conn', $start, 0, $this->totalTests);
        }
    
        for ($i = 0; $i < $this->totalTests; $i++) {
            $queryStart = microtime(true);
    
            try {
                // 從連接池中獲取一個連接
                $pdo = $connectionPool[$i % count($connectionPool)];
                
                // 測試基本查詢
                $stmt = $pdo->query("SELECT 1");
                if (!$stmt) {
                    $errors++;
                }
                
                // 測試 TiDB 版本信息
                $versionStmt = $pdo->query("SELECT VERSION()");
                if ($versionStmt) {
                    $version = $versionStmt->fetchColumn();
                    if (strpos($version, 'TiDB') !== false) {
                        // 確認是 TiDB
                    }
                }
            } catch (Exception $e) {
                $errors++;
            }
    
            $totalTime += (microtime(true) - $queryStart);
        }
    
        // 關閉所有連接
        foreach ($connectionPool as $pdo) {
            $pdo = null;
        }
    
        return $this->calculateResults('single_thread_multi_conn', $start, $totalTime, $errors);
    }

    // 多線程多連接測試
    public function testMultiThreadMultiConnection() {
        //echo "Testing Multi Thread Multi Connection...\n";
        $start = microtime(true);
        $errors = 0;
        $totalTime = 0;
        
        $processes = [];
        $testsPerThread = ceil($this->totalTests / $this->numThreads);
        
        for ($i = 0; $i < $this->numThreads; $i++) {
            $pid = pcntl_fork();
            
            if ($pid == -1) {
                die("Could not fork");
            } else if ($pid) {
                $processes[] = $pid;
            } else {
                $threadStart = microtime(true);
                $threadErrors = 0;
                $threadTime = 0;

                for ($j = 0; $j < $testsPerThread; $j++) {
                    $queryStart = microtime(true);
                    
                    try {
                        $dsn = "mysql:host={$this->host};port={$this->port};dbname={$this->db};charset=utf8mb4";
                        $pdo = new PDO($dsn, $this->user, $this->pass, [
                            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                            PDO::ATTR_TIMEOUT => 10
                        ]);
                        
                        // 測試基本查詢
                        $stmt = $pdo->query("SELECT 1");
                        if (!$stmt) {
                            $threadErrors++;
                        }
                        
                        // 測試 TiDB 版本信息
                        $versionStmt = $pdo->query("SELECT VERSION()");
                        if ($versionStmt) {
                            $version = $versionStmt->fetchColumn();
                            if (strpos($version, 'TiDB') !== false) {
                                // 確認是 TiDB
                            }
                        }
                        
                        $pdo = null;
                    } catch (Exception $e) {
                        $threadErrors++;
                    }
                    
                    $threadTime += (microtime(true) - $queryStart);
                }

                file_put_contents("/tmp/tidb_test_thread_{$i}", json_encode([
                    'errors' => $threadErrors,
                    'time' => $threadTime
                ]));
                
                exit(0);
            }
        }
        
        foreach ($processes as $pid) {
            pcntl_waitpid($pid, $status);
        }
        
        for ($i = 0; $i < $this->numThreads; $i++) {
            $data = json_decode(file_get_contents("/tmp/tidb_test_thread_{$i}"), true);
            $errors += $data['errors'];
            $totalTime += $data['time'];
            unlink("/tmp/tidb_test_thread_{$i}");
        }
        
        return $this->calculateResults('multi_thread_multi_conn', $start, $totalTime, $errors, $this->numThreads);
    }

    private function calculateResults($type, $start, $totalTime, $errors, $threads = 1) {
        $totalDuration = microtime(true) - $start;
        $avgResponseTime = ($totalTime / $this->totalTests) * 1000;
        $errorRate = ($errors / $this->totalTests) * 100;
        
        return [
            'type' => $type,
            'total_tests' => $this->totalTests,
            'total_duration' => round($totalDuration, 3),
            'avg_response_time' => round($avgResponseTime, 3),
            'error_count' => $errors,
            'error_rate' => round($errorRate, 2),
            'requests_per_second' => round($this->totalTests / $totalDuration, 2),
            'threads' => $threads
        ];
    }

    public function testBasicConnection() {
        //echo "\n=== 基本連接測試 ===\n";
        try {
            $dsn = "mysql:host={$this->host};port={$this->port};charset=utf8mb4";
            $pdo = new PDO($dsn, $this->user, $this->pass, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_TIMEOUT => 10
            ]);
            
            //echo "✅ 基本連接成功!\n";
            
            // 測試簡單查詢
            $stmt = $pdo->query("SELECT 1 as test");
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            //echo "✅ 查詢測試成功: " . $row['test'] . "\n";
            
            $pdo = null;
            return true;
        } catch (Exception $e) {
            echo "❌ 基本連接測試異常: " . $e->getMessage() . "\n";
            return false;
        }
    }

    public function runAllTests() {
        // 先進行基本連接測試
        if (!$this->testBasicConnection()) {
            echo "基本連接測試失敗，停止執行後續測試\n";
            return;
        }
        
        //echo "\n=== 開始性能測試 ===\n";
        $this->results[] = $this->testSingleThreadSingleConnection();
        $this->results[] = $this->testSingleThreadMultiConnection();
        $this->results[] = $this->testMultiThreadMultiConnection();
        
        $this->printResults();
    }

    private function printResults() {
        //echo "\nTest Results:\n";
        echo str_repeat("=", 120) . "\n";
        echo sprintf("%-25s %-15s %-20s %-15s %-15s %-15s %-10s\n",
            "Test Type",
            "Total Tests",
            "Avg Response (ms)",
            "Error Rate %",
            "Total Time (s)",
            "Req/sec",
            "Threads"
        );
        echo str_repeat("-", 120) . "\n";
        
        foreach ($this->results as $result) {
            echo sprintf("%-25s %-15d %-20.3f %-15.2f %-15.3f %-15.2f %-10d\n",
                $result['type'],
                $result['total_tests'],
                $result['avg_response_time'],
                $result['error_rate'],
                $result['total_duration'],
                $result['requests_per_second'],
                $result['threads']
            );
        }
        echo str_repeat("=", 120) . "\n";
    }
}

// 使用示例 - TiDB 測試配置
$tester = new TiDBConnectionTester(
    '172.24.40.25',        // TiDB host (請根據實際 TiDB 地址修改)
    'root',             // user
    '1qaz@WSX',                 // password (TiDB 預設無密碼)
    '6000',             // TiDB 預設端口
    'test'              // database
);

$tester->runAllTests();
