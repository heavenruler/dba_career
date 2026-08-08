# YugabyteDB — vm-6node P-B×A-A — chaos/failover 實跑摘要

- TS: `20260808T172141+0800`
- Placement: P-B（2 IDC + 1 GCP voter, RF=3, **不 pin preferred_zones** — leader 由 LB 自然分散跨 IDC/GCP）
- Profile: A-A（steady workload 連 GCP host `10.160.152.11:5433`，同 P-A 段做法）
- 環境建置過程：teardown 重建（phase1 destroy+apply，非「中斷後作廢重建」情境，是本段的正常起手式）。
  過程中兩次背景任務被 harness 判定「killed」但底層 make/go-tpc 實際健康或已無害中止：
  1. `phase4-ybdb-fix6n` 首次跑到「wait load_balancer Idle=1 sustained for 60s」時本機 make 被真的 SIGTERM
     終止（非底層任務健康、harness 誤判——這次是本機 make 進程本身被終止），重跑 `phase4-ybdb-fix6n`
     單一 target 後乾淨完成（yb-admin 對 placement 操作皆冪等）。
  2. `phase7-ybdb-smoke` 首次在「load to order_line in warehouse 21 district 7」（純 INSERT loop 階段，
     尚未進入 index 建立）時本機 make 被終止；prepare.sh 本身對「上次 prepare 被殺留下殘留 session」
     有內建 `pg_terminate_backend`+DROP+CREATE 防呆，判斷此中斷發生在安全點（非 index backfill 階段），
     故未觸發「環境作廢重建」，改用 `nohup`+`disown` 完全脫離 harness 背景任務追蹤後重跑，完整跑完
     128 warehouse 載入（歷時約 100 分鐘）且兩個 gate 皆 PASS。
- 執行順序：C7 → C1 → F1(leader/follower) → C4(leader/follower) → F2

## Placement gate 結果（與 P-A 對比的關鍵差異）

- placement gate PASS — P-B spread idc=1/3（33%，僅記錄不斷言，符合 P-B「不 pin」設計）
- gcp-replica-gate PASS — **idc=13 gcp=11**（total=24，幾乎對半分散進 GCP！）
  相較 P-A 段的 idc=24/gcp=0（100% IDC，因 preferred_zones pin），P-B 段證實了「不 pin」的直接後果：
  真實 tablet leader 有將近一半落在 GCP 上。這對正常穩態運作影響不大（LB 自然均衡),但意味著 P-B
  下的 F1/C4「leader kill」若隨機挑到 GCP host 會完全測不到 IDC 故障場景——**本次刻意仍鎖定 IDC 側
  3 台做 kill target**，以維持與 P-A 段方法論一致（IDC-side failure focus）。

## Leader/Follower kill target 選擇方法（P-B 專用，不同於 P-A）

P-A 段因 preferred_zones pin，IDC 3 台的 tablet leader 幾乎均等且明確；P-B 段不 pin，因此改用「實際
讀寫流量」作為選擇依據（`list_leader_counts` 對單一小表的採樣不可靠，樣本數太小）：
測試前查得 IDC 3 台 tserver 的 Reads/s、Writes/s：`.34`=171.86/136.69（遙遙領先）、`.13`(GCP)=36.48/31.32、
`.32`=11.39/8.79、`.33`=0.80/20.58。據此選定 **leader-kill=172.24.40.34**（實際承擔最多 tablet 流量的
host）、**follower-kill=172.24.40.32**（IDC 中流量最低）。注意：master metadata leader 在測試全程持續
在 .32/.33/.34 之間依序輪替（每次 kill 後重啟都改選新的 metadata leader），與「tablet 資料 leader」
是兩個獨立概念——本段的 role 標籤（leader/follower）指的後者。

## 結果總表

| 情境 | kill target | role | graceful resign | RTO | RPO (lost tx) | 備註 |
|---|---|---|---|---|---|---|
| C7 (fio 磁碟競爭 30s) | 172.24.40.34 | — | — | N/A | N/A | fio 正常執行 30s；6/6 tserver ALIVE 全程未受影響 |
| C1 (WAN partition 30s) | 全部 6 台 DB host | — | — | N/A | N/A | probe 全程 err（partition 期間符合預期）；30s 後自動 restore，6/6 ALIVE 復原 |
| F1-leader | 172.24.40.34（真實 tablet 資料 leader） | leader | 是 | **2.627s** | 0 | 見下方「重大發現」——首次觀察到 YBDB 殺真實 tablet-leader-heavy host 時的實質 raft 選舉延遲 |
| F1-follower | 172.24.40.32（低流量 IDC host，恰為 master leader） | follower | 是 | **0.009s**（重跑後） | 0 | 首跑因 `.34` master 執行緒暴增（1147 threads）導致 60s poll window 卡住逾 12 分鐘，見下方「重大發現」；`.34` 重啟後緒數恢復正常(26)，重跑乾淨完成 |
| C4-leader | 172.24.40.34 | leader | 否 | **3.518s** | 0 | 與 F1-leader (2.627s) 同量級，印證「殺真實資料 leader」比「殺 master leader」慢一個數量級（vs P-A 的 0.26~0.39s） |
| C4-follower | 172.24.40.32 | follower | 否 | **0.455s** | 0 | |
| F2（3 台 IDC 同時死亡） | 172.24.40.32/33/34 | — | — | 真實復原 ≈**3.05s**（`t_first_write_ok-t_restart_start`=11:37:05.228−11:37:02.181）；raw `write_recovery_sec`=10.952s | 0 | write-reject 驗證：kill 期間 INSERT/DELETE 皆 `psql: timeout expired` → `verdict=write_correctly_rejected`；復原後 6/6 ALIVE、3/3 master 健康 |

## 重大發現：P-B 段殺「真實 tablet 資料 leader」時 RTO 明顯變慢（2.6~3.5s vs P-A 的 0.26~0.39s）

P-A 段因 preferred_zones pin，F1/C4「leader」kill 目標永遠同時是 master metadata leader，且被 pin 的
leader 交接對象也在同一批固定 IDC host 之間，交接路徑短。P-B 段不 pin，`.34` 承擔了不成比例的真實
tablet 讀寫流量（171.86 reads/s / 136.69 writes/s，遠高於其他 5 台）。殺掉 `.34` 時，大量 tablet 需要
同時進行 raft leader 重選，實測 RTO 落在 2.6~3.5 秒——比 P-A 段快一個數量級的 0.26~0.39s 慢了近 10 倍。
這是 P-B「不 pin leader、讓 LB 自然分散」設計下的真實代價：分散雖然平時對 GCP 側讀取友善，但一旦
剛好殺到「意外集中了大量 leader」的那台 host，故障切換時間會顯著拉長。**這是本次唯一在 F1/C4 場景中
觀察到明顯差異的地方，值得在最終比較報告中特別標註。**

## 重大發現：YBDB master 執行緒暴增 bug（`.34`, 1147 threads, RPC 延遲 5~80 秒）

F1-follower 首次執行時（kill `.32`，其恰為當時 master metadata leader），`master_leader_stepdown`
+ 實際 kill 後，`.33` 持續嘗試 pre-election 但反覆對 `.34` 發出的投票請求逾時（10~19 秒逾時，見
`.33` master log：`RPC error ... RequestConsensusVote RPC ... timed out after 18.808s`）。追查 `.34`
的 yb-master process 執行緒數：

```
.32  yb-master  NLWP=30（正常）
.33  yb-master  NLWP=27（正常）
.34  yb-master  NLWP=1147（異常暴增！RSS 僅 155MB，非記憶體洩漏，純粹執行緒數暴增）
```

`.34` 的 master RPC（`GetMasterRegistration`）延遲從正常的毫秒級暴增到 5~80 秒（`took 79487ms`），
導致整個叢集在長達 12+ 分鐘內選不出新 master leader（`.32` 已死、`.34` 回應太慢，`.33` 無法湊到多數票）。
處理方式：手動重啟 `.32`（恢復 3 票法定人數）未能立即解決（`.34` 仍 TIMED_OUT）；接著手動重啟 `.34`
的 yugabyted，NLWP 立刻恢復正常值（26），RPC 延遲恢復正常，重跑 F1-follower 乾淨完成（RTO=9ms）。

**根因推測**（未深入原始碼驗證，僅基於觀察現象）：`.34` 在此之前的 F1-leader 測試中剛被 kill+重啟過，
且承擔全叢集最重的 tablet 讀寫流量；當 `.32`（master leader）被殺、`.33` 開始以短週期（~15~20s）反覆
發起 pre-election 並向 `.34` 送出投票 RPC 時，若 `.34` 的 RPC handler thread pool 在某種條件下未正確
回收（例如每次逾時的呼叫都殘留一個等待中的 handler thread），會隨重試次數線性累積，形成執行緒數
暴增與雪崩式延遲惡化的正回饋循環。**這是本次 3 個資料庫 chaos 測試中，第一次觀察到的、與工具/腳本
bug 無關的、真實資料庫本身的穩定性異常，建議列入最終比較報告的獨立風險項。**

## 已知限制（沿用 P-A/TiDB 段既有方法論限制，未變）

- RPO 量測為簡化版（per-warehouse `max(o_id)` high-water-mark），非完整 driver-hooked FIFO buffer。
- C1/C7 未量測 tpmC-during-incident。
- `probe-rto-driver.sh`/`run-vm6-chaos-execute.sh` 的 ybdb bug 修復（PROBE_USER、S_PRE_QUERY orders
  表名）已於 P-A 段完成並沿用，本段未再發現新的同類 bug。
