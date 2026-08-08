# YugabyteDB — vm-6node P-A×A-S — chaos/failover 實跑摘要

- TS: `20260808T144840+0800`（環境於本 TS 完成 phase1~phase7 建置；因 phase7 prepare 連續 2 次卡在
  `WaitForYsqlBackendsCatalogVersion` catalog-version 迴圈，依專案規則整個環境 destroy 重建後才在此
  TS 上成功跑完，經使用者確認「直接 teardown 重建整個環境」）
- Placement: P-A（2 IDC + 1 GCP voter, RF=3, preferred_zones=IDC → leader 全數固定 IDC）
- Profile: A-S（steady workload 單向連 GCP host `10.160.152.11:5433`，非 HAProxy VIP — 這個環境沒有
  幫 YBDB 佈署 HAProxy，因此 steady workload 直連單一 GCP tserver；YBDB 6 台裡任一 IDC 節點被殺都不影響
  這條連線，但 GCP host 本身被殺或整個 GCP 側出問題時 workload 會跟著斷線）
- 執行順序：C7 → C1 → F1(leader/follower) → C4(leader/follower) → F2

## 結果總表

| 情境 | kill target | role | graceful resign | RTO | RPO (lost tx) | 備註 |
|---|---|---|---|---|---|---|
| C7 (fio 磁碟競爭 30s) | 172.24.40.32 | — | — | N/A | N/A | fio WRITE bw=280MiB/s 持續 30s；6/6 tserver ALIVE 全程未受影響 |
| C1 (WAN partition 30s) | 全部 6 台 DB host（IDC↔GCP 對稱阻斷） | — | — | N/A | N/A | probe 全程 err（partition 期間 GCP↔IDC 斷線符合預期）；30s 後自動 restore，6/6 ALIVE 復原 |
| F1-leader | 172.24.40.32 (master LEADER) | leader | 是（master_leader_stepdown 先於實際 kill） | **0.260s** | 0 | |
| F1-follower | 172.24.40.34 (master FOLLOWER) | follower | 是 | **0.391s** | 0 | |
| C4-leader | 172.24.40.32 | leader | 否（ungraceful） | **0.375s** | 0 | 與 F1-leader 相比只慢 115ms — graceful resign 對 YBDB master failover 幫助有限 |
| C4-follower | 172.24.40.34 | follower | 否 | **0.328s** | 0 | |
| F2（3 台 IDC 同時死亡） | 172.24.40.32/33/34 | — | — | **write_recovery ≈3.2s**（見下方重新解讀）；raw `write_recovery_sec`=11.607s | 0（write-reject 期間無寫入被誤判成功，恢復後才寫入） | write-reject 驗證：kill 期間對 GCP host INSERT/DELETE 皆 `psql: timeout expired` → `verdict=write_correctly_rejected` |

**F2 數字重新解讀**（沿用 TiDB 段已建立的 basis-point 修正公式，不用 script 原生 `t_kill` 起算）：
- raw `write_recovery_sec = t_first_write_ok - t_kill = 11.607s`：把「偵測到 kill 完成 + 跑 write-reject
  驗證 + 送出 3 台 restart 指令」這段 ~8.4s 的前置作業時間也算進去，不是真正的復原時間。
- 真實復原時間 = `t_first_write_ok - t_restart_start = 08:24:48.230 − 08:24:45.029 ≈ 3.2s`：3 台 IDC
  yugabyted 平行重啟後，到第一次真實 INSERT+DELETE 成功為止。

## RTO/RPO 量測方法論一致性

沿用 TiDB 段確立的公式：全程使用 `probe-rto-driver.sh`（100ms 週期 write probe，本次修完 bug 後才可信，
見下方）+ `wall-clock-wrapper.sh`（t_incident 錨點、以最後一次 error 而非第一次 isolated ok 判定復原）。

## Placement 觀察

與 TiDB P-A/P-B 段的結論一致：graceful resign 對 YBDB 的效益也很有限（F1-leader 0.260s vs C4-leader
0.375s，僅差 115ms），且 leader/follower kill 的 RTO 差異也在同一量級（0.26~0.39s），沒有觀察到
placement 或 role 造成的結構性差異。YBDB 的 raft-based master 選舉在小資料量/單區域環境下明顯偏快。

## 本次執行中發現並修復的 bug（首次對 YBDB 實跑這些既有腳本分支）

1. **`probe-rto-driver.sh` — PROBE_USER 對 ybdb 錯誤預設為 `root`**（新發現，影響本次 F1-leader/
   F1-follower 的第一次嘗試）：YSQL 預設 superuser 是 `yugabyte`，不是 `root`；也沒有 `defaultdb`
   這個庫（那是 CRDB 的命名），且 YSQL 的 `CREATE DATABASE` 不支援 `IF NOT EXISTS`（psql 回
   `syntax error at or near "NOT"`）。三個問題疊加造成 probe table 從未真正建立成功，導致 F1 兩次首跑
   全程 100% `err unknown`（含 kill 前，證明是探測工具本身失效，不是真的量到「一直沒復原」）。已修正：
   `PROBE_USER` 依 DB 分開預設（ybdb→yugabyte）；ybdb 分支改連 `dbname=yugabyte` 執行
   `CREATE DATABASE probe_db`（無 IF NOT EXISTS，靠既有的 `2>/dev/null || true` 吞掉重跑時的
   already-exists 錯誤）。修復後兩個情境都重跑，拿到真實 RTO。
2. **`run-vm6-chaos-execute.sh` — S_PRE_QUERY 對 ybdb 誤用 `oorder` 表名**（新發現）：go-tpc 在
   postgres driver（ybdb/crdb 皆同）下建的表是 `orders`，不是 OLTPBench 傳統命名的 `oorder`；這行是從
   CRDB 那行複製貼上但沒改對。首次對 ybdb 實跑 F1 時 S_pre capture 直接 FATAL 中止。已修正 ybdb 分支
   為 `orders`；CRDB 那行維持 `oorder` 不動——因為 CRDB 測試本身還沒開始，比照既有的
   WRITE_PROBE SELECT-1 已知問題，一併留到 CRDB 段處理。
3. **`run-vm6-chaos-execute.sh` 呼叫 `gate-chrony-cross-region.sh` 缺少必填 `--ts`/`--root-suffix`**
   （沿用既有工作模式而非新 bug）：該 gate script 本身要求這兩個參數，但呼叫端從未傳遞——推測 TiDB 段
   兩次全部情境也都是靠 `--skip-chrony-gate` 略過（因為 F1/C4 artifact 目錄裡完全沒有 chrony-gate 相關
   檔案佐證曾經真的跑過）。本次沿用同樣做法：全程加 `--skip-chrony-gate`，因為 chrony 漂移已在 phase2
   對這批全新 VM 驗證過一次（10 host 全數 <100ms），環境生命週期內不會再變。未修改 script 本體。

以上 1、2 屬於這批既有 ybdb 分支程式碼「第一次被真實執行到」才浮現的 bug，與 TiDB 段每個新分支首跑
必出新 bug 的模式一致；已直接修正在共用腳本上，YBDB 後續 P-B×A-A 段與 CRDB 段的類似路徑可直接受惠
（`run-vm6-chaos-execute.sh` 的 S_PRE_QUERY fix 僅涵蓋 ybdb；CRDB 段仍需比照修正 `oorder`→`orders`）。

## 已知限制（沿用 TiDB 段既有方法論限制，未變）

- RPO 量測為簡化版（per-warehouse `max(o_id)` high-water-mark），非完整 driver-hooked FIFO buffer。
- C1/C7 未量測 tpmC-during-incident（沿用 TiDB 段已知的 workload log 覆蓋問題，本段未特別修正，因為
  重心在讓 F1/C4/F2 的 kill-scope 分支首次正確跑通）。
- Steady workload 這次因為 SSH 遠端 detach 的 harness 問題重啟過 2 次（詳見過程；已用 harness
  `run_in_background` 取代手動 `nohup+disown`，之後穩定運行到收工，未再中斷）。
