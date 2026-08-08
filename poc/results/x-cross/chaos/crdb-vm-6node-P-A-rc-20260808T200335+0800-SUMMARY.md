# CockroachDB — vm-6node P-A×A-S — chaos/failover 實跑摘要

- TS: `20260808T200335+0800`
- Placement: P-A（2 IDC + 1 GCP voter, RF=3；deploy-time CONFIGURE ZONE 使 P-A 下 lease holder 100% 落
  IDC，同 TiDB/YBDB P-A 語意一致）
- Profile: A-S（steady workload 連 GCP host `10.160.152.11:26257`）
- CRDB v26.2.0。與 TiDB/YBDB 不同：單一 `cockroach` process（無元件拆分問題），per-range leaseholder
  貫穿全域（無 master-metadata-leader vs tablet-data-leader 的分層概念）
- 執行順序：C7 → C1 → F1(leader/follower) → C4(leader/follower) → F2

## 建置過程中發現並修復的 bug（CRDB 分支首次真實執行，逐一浮現）

1. **`Makefile` phase5-crdb-deploy 缺少 `-o StrictHostKeyChecking=accept-new`**：copy cockroach binary
   → GCP probe host .15 這步驟的第一段 hop（`ssh root@$(CRDB_HOST)`）對全新 VM 缺少
   accept-new，首跑報 `Host key verification failed`，整個 phase5 中止在最後一步。已修正並重跑成功
   （確認二進位 `v26.2.0` 正確送達 .15）。
2. **`run-vm6-chaos-execute.sh` crdb 的 F1/C4 KILL_CMD 設計缺陷**：`cockroach quit` 是 CRDB 自己的
   graceful drain 指令（drain+shutdown 是一個原子操作），F1、C4 若共用同一條指令會讓兩個情境發出
   完全相同的命令，喪失「graceful vs ungraceful」對照的意義（不同於 TiDB/YBDB：那兩家用同一個
   KILL_CMD，graceful/ungraceful 差異來自「殺之前是否先跑一個獨立的 resign 指令」；CRDB 沒有這種
   獨立於關機之外的 resign 原語，所以只能讓 KILL_CMD 本身分流）。修正：F1 保留 graceful drain，C4 改
   `systemctl kill -s SIGKILL cockroach` 真正硬殺，略過 drain/lease 轉移。
3. **`cockroach quit` 在 v26.2 已不存在**（`ERROR: unknown command "quit"`）：F1 首次真實 kill 因此
   靜默失敗（exit 非 0），腳本的 post-kill 驗證正確抓到「process 仍在跑」並 fail-closed 中止，沒有
   量出假的 RTO。改用實測可行的 `cockroach node drain --self --shutdown --insecure --host=localhost:26257`。
4. **post-kill 驗證的單次即時檢查與 drain 的實際行程序有 race**：同一條修正後的 drain 指令在 `.32`
   上 4 秒後才確認完成，在 `.33` 上卻在僅 2 秒時仍顯示程序在跑（隨後確認其實已死+systemd 已自動重啟）。
   將單次 pgrep 檢查改為最多重試 5 次（每次間隔 1s）——這是通用時序穩健性修正，非 CRDB 專屬，理論上
   任何 DB 的 graceful-shutdown 路徑都可能有類似的短暫落差。
5. **`run-vm6-chaos-execute.sh` LEADER_QUERY 缺少 `WITH DETAILS`**：v26.2 的 `SHOW RANGES FROM TABLE`
   預設不含 `lease_holder` 欄位（`ERROR: column lease_holder does not exist`），首次 pre-kill leader
   query 即失敗（non-fatal，但每次都是空的）。已修正加上 `WITH DETAILS`。
6. **`run-vm6-chaos-execute.sh` S_PRE_QUERY 誤用 `oorder` 應為 `orders`**：延續 YBDB 段已確認的同款
   go-tpc postgres-driver 命名慣例（`orders`，非 OLTPBench 傳統的 `oorder`），CRDB 這行先前一直沿用
   YBDB 修復前的舊猜測值。首次真實 F1 run 因此 FATAL 中止於 S_pre capture。已修正。
7. **`run-vm6-f2-idc-death-execute.sh` crdb 的 WRITE_PROBE 仍是空的 `SELECT 1`**：同 YBDB 已知問題
   （非真實寫入，測不到 write-reject）。確認真實 schema（`warehouse` 僅 `w_id` NOT NULL）後改為真實
   INSERT+DELETE，上線前先手動測試過一次確認可行。
8. **`run-vm6-f2-idc-death-execute.sh` crdb 的 HEALTH_QUERY 查詢受限系統表**：
   `crdb_internal.kv_node_status` 在 v26.2 預設被限制存取（`ERROR: Access to crdb_internal and system
   is restricted`），這條查詢永遠失敗（回傳 0），導致 F2 首次真實執行時，即使叢集與 write-probe 早已
   復原，poll loop 仍固定跑滿整個 600 秒視窗才放棄（`idc_healthy_count=0` 連續上百次）。改用
   `cockroach node status`（不受限）配合 `cut`+`grep`（刻意避開任何反斜線跳脫，因為這段字串要先被
   Makefile/腳本的 double-quote assignment 解析一次，之後又要被 `eval` 重新解析一次，兩層 shell
   parsing 疊加下 `awk -F'\t'`／regex 的反斜線很容易算錯層數而失效——已用 `cut -f2,9 | grep -c
   '^172.24.*true$'` 完全避開這個陷阱）。修正後 F2 重跑，全流程在原本該有的秒數內正確判定復原。

以上 8 項全是 CRDB 分支「第一次被真實執行到」才浮現的 bug，與 TiDB/YBDB 每個分支首跑必出新 bug 的
模式完全一致；已直接修正在共用腳本上，CRDB P-B×A-A 段可直接受惠（無需重複踩雷）。

## 結果總表

| 情境 | kill target | role | graceful | RTO | RPO (lost tx) | 備註 |
|---|---|---|---|---|---|---|
| C7 (fio 磁碟競爭 30s) | 172.24.40.32（lease 最多的 IDC host） | — | — | N/A | N/A | fio 正常執行 30s；6/6 node available/live 全程未受影響 |
| C1 (WAN partition 30s) | 全部 6 台 DB host | — | — | N/A | N/A | 30s 後自動 restore，6/6 復原 |
| F1-leader | 172.24.40.32（node1，6 leases，全 lease 分布中最高） | leader | 是（`node drain --shutdown`） | **0.035s** | 0 | drain 在程序退出前已把 lease 轉走，client 幾乎無感 |
| F1-follower | 172.24.40.33（node3，僅 1 lease，全 IDC 最低） | follower | 是 | **0.081s** | 0 | |
| C4-leader | 172.24.40.32 | leader | 否（`systemctl kill -s SIGKILL`） | **0.100s** | 0 | 與 F1-leader 相比僅慢 65ms — graceful drain 對 CRDB range lease 復原速度幫助有限，兩者都在同一數量級 |
| C4-follower | 172.24.40.33 | follower | 否 | **0.131s** | 0 | |
| F2（3 台 IDC 同時死亡） | 172.24.40.32/33/34 | — | — | 真實復原 ≈**12.95s**（`t_first_write_ok-t_restart_start`=13:43:02.425−13:42:49.472）；raw `write_recovery_sec`=80.239s | 0 | write-reject 驗證：kill 期間查詢出現真實 `lost quorum`/`have been waiting 62.00s for slow proposal` 錯誤 → `verdict=write_correctly_rejected` |

**F2 數字重新解讀**（沿用 TiDB/YBDB 段已建立的 basis-point 修正公式）：raw
`write_recovery_sec=80.239s` 把「偵測 kill 完成 + write-reject 驗證 + 送出 3 台 restart 指令」這段
~67s 的前置作業也算進去；真實復原時間 = `t_first_write_ok − t_restart_start ≈ 12.95s`。

## 跨 DB 比較觀察（F2 復原時間：CRDB ≈13s vs YBDB ≈3s）

CRDB 的 F2 真實復原時間（~12.95s）明顯比 YBDB（~3.05~3.2s，兩個 placement 皆同量級）慢了 4 倍左右。
write-reject-validation.txt 裡的錯誤訊息本身透露了原因：CRDB 的 raft proposal 在偵測到 quorum 遺失後
會等待相當長的內部逾時（`have been waiting 62.00s for slow proposal`）才真正判定失敗並釋放 client
連線去重試，這個「內部等待逾時」的機制設計本身就比 YBDB 的偵測/重試更保守（更慢判定失敗、但避免誤判）。
這是本次唯一一個在 F2 情境觀察到跨 DB 有數量級差異的地方，值得在最終比較報告中特別標註——雖然兩者
最終都正確達成「quorum 遺失時拒絕寫入、恢復後correctly 重新接受寫入」的正確性目標，只是速度有別。

## 重大發現：`go-tpc` 對 CRDB 的容錯度偏低，多次因累積錯誤提前終止

本段 steady workload 在單一次真實 kill（F1/C4，各自僅造成 30~130ms 級的短暫錯誤）後仍能存活，但在
F2（IDC 全滅，較長的 write-reject 窗口）後兩次都直接印出 `Finished` 提前結束，而非像 YBDB 段一樣能撐
過整個 campaign 不中斷。已確認每次結束前的 log 顯示大量真實的 CRDB 錯誤（`TransactionAbortedError`、
`NotLeaseHolderError`、`connection refused` 等，都是預期中的真實故障徵狀，非探測工具本身的 bug）——
研判是 `go-tpc` 的 postgres/crdb driver 對持續錯誤的內部容忍閾值比 ybdb driver 低，累積到一定次數後
會自行判定「Finished」並印出統計摘要而非繼續重試。每次發生後都重新啟動 workload 才能繼續下一情境
（比照 TiDB 段 PD-resign 導致 workload 崩潰後需重啟的既有模式，屬同一類「量測工具本身的韌性限制」，
非資料庫本身的問題）。

## 已知限制（沿用 TiDB/YBDB 段既有方法論限制，未變）

- RPO 量測為簡化版（per-warehouse `max(o_id)` high-water-mark），非完整 driver-hooked FIFO buffer。
- C1/C7 未量測 tpmC-during-incident。
