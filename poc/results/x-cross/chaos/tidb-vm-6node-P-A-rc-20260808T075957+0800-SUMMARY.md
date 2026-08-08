# TiDB P-A×A-S — 完整 5 情境 chaos/failover 實跑 (2026-08-08)

環境 TS=`20260808T075957+0800`，W=128，placement gate PASS（idc=20/20, 100%）。
依 48 次注入campaign 規劃第一組（TiDB, P-A×A-S），共 11 次真實注入。

## 結果總表

| 情境 | Kill target | Role | Scope | RTO (s) | RPO (lost tx) |
|---|---|---|---|---:|---:|
| C7 disk-slow | .33 | - | - | n/a（韌性敘述，見下） | n/a |
| C1 partition | 全6台 | - | - | n/a（韌性敘述，見下） | n/a |
| F1 | .33 | leader | tidb+tikv | 6.934 | 0 |
| F1 | .33 | leader | tidb+tikv+pd | 6.692 | 0 |
| F1 | .33 | follower | tidb+tikv | 7.315 | 0 |
| F1 | .33 | follower | tidb+tikv+pd | 6.909 | 0 |
| C4 | .33 | leader | tidb+tikv | 6.844 | 0 |
| C4 | .33 | leader | tidb+tikv+pd | 6.684 | 0 |
| C4 | .32 | follower | tidb+tikv | 0.030（見下方警語） | 0 |
| C4 | .32 | follower | tidb+tikv+pd | 6.715 | 0 |
| F2 | 全3台IDC | - | tidb+tikv+pd | 見下方拆解 | write correctly rejected |

## 重要方法論發現與警語

1. **HAProxy backend 限定**：本拓樸 HAProxy（10.160.152.14）只 balance 3 台
   （172.24.40.32、172.24.40.33、10.160.152.11），`.34`／GCP `.12`／`.13`
   不跑 `tidb-4000`（只有 TiKV+PD）。第一次 C4-leader 誤選 `.34` 當
   kill target，量到 RTO=0.06s——**該次結果無效**（HAProxy 從未路由過去，
   等於沒測到任何東西），已移至
   `...scenarioC4-leader-tidbtikv-INVALID-not-haproxy-backend/` 保留備查，
   不計入上表。**日後任何 DB 的 F1/C4 kill target 都必須先確認是否在
   client 實際連線的 backend/topology 裡。**
2. **follower-kill RTO 測量雜訊大**：C4-follower-tidbtikv（.32）量到
   RTO=0.030s，但同一台主機的 +pd 變體卻量到 6.715s；F1-follower（.33）
   兩個變體都在 ~7s。單一探測樣本受 HAProxy round-robin 是否「運氣好」
   剛好沒連到掛掉的 backend 影響很大，0.030s 這筆**很可能是量測雜訊，
   不是「follower 真的無感知」的證據**——4 組 follower 測試中 3 組落在
   leader-kill 同量級（~6.7-7.3s），只有 1 組是離群值。
3. **F1/C4 kill 範圍已修正為 tidb+tikv(+pd)**：原腳本只停無狀態的
   `tidb-server`，未觸發真正的 TiKV Region Raft leader 重選；修正後
   leader/follower/±pd 共 8 組數據都落在 6.68-7.32s 這個窄區間，顯示
   （a）此環境下 graceful resign 幾乎不省時間、（b）多殺一個共置 PD
   對客戶端可見 RTO 無實質影響、（c）follower vs leader 差異被 HAProxy
   本身的健康檢查機制蓋過，未觀察到預期中的「follower 應該更快」訊號。
4. **重複執行 PD resign 曾導致背景 workload 崩潰**：F1 第 4 次（follower+pd）
   注入前後，go-tpc 因 `[PD:tso:ErrGenerateTimestamp]generate timestamp
   failed, requested pd is not leader of cluster` 直接終止（見
   `logs/`）。已重啟 workload；此為真實發現，非腳本 bug——短時間內連續
   多次 PD resign 可能造成 client 端 TSO 請求失敗到足以讓長跑 benchmark
   放棄整個 run，這本身是值得記錄的韌性觀察。
5. **F2 `cluster_rebuild_sec`／`write_recovery_sec` 基準點需重新解讀**：
   腳本兩個欄位都是從 `t_kill` 起算，**內含我們刻意保留 IDC down 狀態
   157.4 秒去驗證 write-reject 的操作時間**，不是單純的「DB 自己重建要
   多久」。原始時間戳：`t_kill=01:24:02.243Z`、
   `t_restart_start=01:26:39.632Z`（相隔 157.389s，操作等待）、
   `t_all_idc_healthy=01:26:39.815Z`（重啟後僅 0.183s——**極可能是 PD
   store-down 判定閾值長於本次停機時間，狀態根本沒被標記過 Down，屬
   量測假訊號，不可視為真實復原時間**）、
   `t_first_write_ok=01:27:23.930Z`（重啟後 44.298s——**這是唯一可信的
   「重啟後到能再次成功寫入」時間**，因為必須 TiDB+TiKV+PD 三者都真正
   恢復運作才可能寫入成功）。**建議日後報告一律引用「重啟後 44.3s
   恢復可寫」，不要直接引用腳本輸出的 `write_recovery_sec: 201.687`
   （那是含等待時間的總數）或 `cluster_rebuild_sec: 157.572`（含假訊號）。**
6. Write-reject 驗證正確：兩次寫入嘗試皆收到
   `ERROR 9001 (HY000): PD server timeout`，判定
   `write_correctly_rejected`——符合 P-A（IDC 多數）下 IDC 全滅、GCP
   單獨無法達成 quorum 的預期行為。

## 過程中新修復的既有腳本 bug（本次新增，前次已修 5 個）

7. `chaos-c7-disk-slow-execute.sh`：新環境的 VM 上 `fio` 未安裝（每次
   VM 重建都是全新機器，前次裝的東西不會留存）——已加開跑前 `command -v
   fio` 檢查，缺失時直接 FATAL 中止而非產生假結果；並修正
   `fio_launch_ok` 過去只驗證「launch 指令本身有沒有回傳 0」、未驗證
   fio 實際跑完（`grep "Run status"`），曾在第一次真實執行時把
   fio 找不到二進位檔的失敗誤判成成功。
8. `run-vm6-f2-idc-death-execute.sh`：`SVC="tidb-server"` 同樣是錯誤
   unit name（比照前次 F1/C4 的修法），已改為 `tidb-4000 tikv-20160
   pd-2379` 三個服務一起停，才是真正的「IDC 全死」語意。

## 目錄索引

各情境 raw artifact 見對應 `tidb-vm-6node-P-A-rc-20260808T075957+0800-scenario<X>/`
子目錄（`kill.log`／`rto-rpo.json`／`plan.txt`／`probe.txt`／`fio-summary.txt`／
`io-latency-p99.txt`／`error-rate-by-sec.txt` 等，依情境而異）。
`logs/`（背景 steady workload raw log，含本輪 PD resign 導致的崩潰紀錄）。

## 待續

TiDB P-B×A-A 尚未執行；YugabyteDB、CockroachDB 兩家完全尚未開始（含
scripts 的 crdb/ybdb 分支從未實跑驗證過，比照本輪 TiDB 的模式，預期
會抓到新的 unit name／路徑／欄位名稱錯誤）。
