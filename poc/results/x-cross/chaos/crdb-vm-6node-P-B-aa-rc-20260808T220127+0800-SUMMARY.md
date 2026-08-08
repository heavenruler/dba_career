# CockroachDB — vm-6node P-B×A-A — chaos/failover 實跑摘要

- TS: `20260808T220127+0800`
- Placement: P-B（不 pin lease_preferences；deploy-time CONFIGURE ZONE 讓 lease 依 LB 自然分散，
  placement gate idc=8/12=66%、gcp-replica-gate idc=25/46=54%，皆符合 P-B「僅記錄不斷言」設計）
- Profile: A-A（steady workload 連 GCP host `10.160.152.11:26257`）
- 建置過程沿用 P-A 段已修復的全部 bug（Makefile host-key、run-vm6-chaos-execute.sh 的 KILL_CMD/
  post-kill 重試/LEADER_QUERY/S_PRE_QUERY、run-vm6-f2-idc-death-execute.sh 的 WRITE_PROBE/
  HEALTH_QUERY），本段**無新增 bug**——8 項修復全數沿用即可，僅需為新 VM 補一次
  `-o StrictHostKeyChecking=accept-new`（`.33` 首次連線時遇到，非既有腳本的問題，純粹新 VM 慣例動作）。
- 執行順序：C7 → C1 → F1(leader/follower) → C4(leader/follower) → F2

## Kill target 選擇（P-B 專用方法論，同 P-A/ybdb-P-B）

`order_line` lease 抽樣：node2(`.33`)=5、node5(GCP `.12`)=5、node4(GCP `.11`)=1、node1(`.32`)=1、
node3(`.34`)=0。IDC 三台中 `.33` 最忙、`.34` 最閒。選定 **leader-kill=172.24.40.33**、
**follower-kill=172.24.40.34**。

## 結果總表

| 情境 | kill target | role | graceful | RTO | RPO | 備註 |
|---|---|---|---|---|---|---|
| C7 (fio 30s) | 172.24.40.33 | — | — | N/A | N/A | 6/6 available/live 全程未受影響 |
| C1 (WAN partition 30s) | 全部 6 台 | — | — | N/A | N/A | 30s 後自動 restore，6/6 復原 |
| F1-leader | 172.24.40.33 | leader | 是 | **0.037s** | 0 | |
| F1-follower | 172.24.40.34 | follower | 是 | **0.104s** | 0 | |
| C4-leader | 172.24.40.33 | leader | 否 | **0.105s** | 0 | |
| C4-follower | 172.24.40.34 | follower | 否 | **0.105s** | 0 | |
| F2（3 台 IDC 同時死亡） | 172.24.40.32/33/34 | — | — | 真實復原 **≈7.21s**（15:22:21.201−15:22:13.992）；raw 72.621s | 0 | write-reject：真實 `lost quorum`/`waiting 62.00s for slow proposal` → `verdict=write_correctly_rejected` |

## P-A vs P-B 比較

- **F1/C4 RTO**：P-A（35~131ms）與 P-B（37~105ms）幾乎同量級，無論 leader/follower、graceful/
  ungraceful，數字都落在同一數十~百毫秒範圍。這與 YBDB 的情況不同——YBDB P-B 因 leader 分散導致殺到
  真正的 tablet 資料 leader 時 RTO 拉長到秒級（2.6~3.5s）；CRDB 兩個 placement 下都維持毫秒級，顯示
  CRDB 的 range lease failover 機制對「leader 是否被 pin」的敏感度遠低於 YBDB 的 tablet raft 選舉。
  推測原因：CRDB 的 lease 本身就是輕量、per-range 且設計為快速 timeout+重新請求（不像 YBDB 需要完整
  raft leader election 流程），因此即使 leader 分散、殺到真正忙碌的節點，重新取得 lease 的成本也不高。
- **F2 真實復原時間**：P-B（~7.21s）反而比 P-A（~12.95s）快，兩者都遠慢於 YBDB 的 ~3s。P-A/P-B 這次
  的差異（7s vs 13s）可能只是單次量測的雜訊（樣本數=1），不足以下「P-B 比 P-A 快」的結論；但兩者
  相對 YBDB 慢 2~4 倍這件事在兩個 placement 都重現，是本次真正可信的跨 DB 結論（見 P-A SUMMARY 已述
  的「CRDB raft proposal 逾時判定較保守」推測）。
- **go-tpc 容錯度**：本段同樣在每次真實 kill 後檢查 workload 存活——F1/C4 四次單一節點 kill 都存活
  下來（與 P-A 不同，P-A 段在其中一次單節點 kill 後就已提前 Finished），僅 F2 後才如預期提前結束。
  這可能表示 P-A 段的提前終止有一定隨機性（累積錯誤數的閾值判定），而非「CRDB 對單節點 kill 必定
  撐不住」的確定性行為。

## 已知限制（沿用 TiDB/YBDB/CRDB P-A 段既有方法論限制，未變）

- RPO 量測為簡化版（per-warehouse `max(o_id)` high-water-mark），非完整 driver-hooked FIFO buffer。
- C1/C7 未量測 tpmC-during-incident。
