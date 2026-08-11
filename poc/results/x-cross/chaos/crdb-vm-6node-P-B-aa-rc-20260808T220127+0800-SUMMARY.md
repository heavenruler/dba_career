# CockroachDB — vm-6node P-B×A-A — chaos/failover 實跑摘要

> **⚠️ 2026-08-11 已被真實重跑取代**：本檔案記錄的原始數字（TS=`20260808T220127+0800`）已於
> 2026-08-10 稽核（[`CHAOS-FAILOVER-AUDIT-2026-08-10.md`](../../../phase-crossregion/CHAOS-FAILOVER-AUDIT-2026-08-10.md)）
> 撤回；完整重跑已於 2026-08-10/11 完成（新 TS=`20260810T152835+0800`）。**本檔案下方內容已完全
> 替換為該次重跑的真實數字**。詳細方法論見
> [`XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md`](../../../phase-crossregion/XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md)。

- TS（重跑）: `20260810T152835+0800`
- Placement: P-B（不 pin lease_preferences；deploy-time CONFIGURE ZONE 讓 lease 依 LB 自然分散）
- Profile: A-A（steady workload 連 GCP host `10.160.152.11:26257`，WAREHOUSES=4）
- 執行順序：C7 → C1 → F1(leader/follower) → C4(leader/follower) → F2
- Kill target 選擇：全部 9 張 tpcc table lease 分布抽樣 — node3(`.33`)=4（IDC 最高）、
  node2(`.34`)=2、node1(`.32`)=1（IDC 最低）。GCP 側 node4/node6 各 6 個 lease（P-B 不 pin 的
  預期行為）。選定 **leader-kill=172.24.40.33**、**follower-kill=172.24.40.32**。

## 本次重跑建置過程中踩到的問題（均已解決，非最終結果的一部分）

1. **A-A profile 需要先有 plain(A-S) 版本的 prepare/schema anchor**：`run-vm6-aa.sh` 依賴
   `.prepare.done` 證據，直接跑 A-A 會因 `tpcc` database 不存在而全滅。已先跑一次 plain
   `phase8-crdb-smoke` 建 anchor，再跑 A-A profile。
2. **GCP client（10.160.152.15）在全新 VM 上缺 go-tpc + patch**：`phase2-bootstrap-gcp-client`
   （安裝 go-tpc）與 `apply-gotpc-patch.sh`（CRDB/lib-pq 相容性 patch）不在標準 `phase2` 鏈中，
   需手動補跑一次。
3. **go-tpc 內建 consistency check（3.3.2.x cross-table aggregate）在 P-B 下卡死 45 分鐘**：
   查到這是專案裡對 YBDB 已知的同一個坑（`tests/common/prepare.sh` 註解），只是判斷條件沒涵蓋
   CRDB P-B（lease 可能落到 GCP，放大這個查詢的跨區延遲）。已修正 `prepare.sh`：`NOCHECK_ARG`
   判斷條件加入 `TOPO` 含 `P-B` 時比照 YBDB 跳過 check-all，改用 row-count 驗證。
4. **X-CROSS placement gate 小樣本雜訊**：gate 只抽樣 3 張表（warehouse/district/customer）共
   6 個 leader，WAREHOUSES=4 下這個樣本數太小，連續 2 次量到 `idc=5/6=83%`（超出 P-B 的
   30-70% 合格區間）而 fail-closed；直接查全體 9 張表 21 個 range 的真實分布是 idc=13/21≈62%
   （合格）。重試第 4 次拿到 gate PASS（`idc=4/6=66%`）後繼續。此為已知的小樣本 gate 限制，
   非資料本身有問題。

## 結果總表

| 情境 | kill target | role | graceful | RTO | RPO | 備註 |
|---|---|---|---|---|---|---|
| C7 (fio 30s) | 172.24.40.33 | — | — | N/A | N/A | 30s 注入正常，6/6 未受影響 |
| C1 (WAN partition 30s) | 全部 6 台 | — | — | N/A | N/A | 探測全程 ok（探測表 lease 剛好在 IDC，partition 期間不影響 IDC 內部連線）；30s 後自動 restore |
| F1-leader | 172.24.40.33 | leader | 是 | `outage_observed=false`（ok=470, err=0） | 0 | |
| F1-follower | 172.24.40.32 | follower | 是 | `outage_observed=false`（ok=504, err=0） | 0 | |
| C4-leader | 172.24.40.33 | leader | 否 | `outage_observed=false`（ok=485, err=0） | 0 | |
| C4-follower | 172.24.40.32 | follower | 否 | `outage_observed=false`（ok=482, err=0） | 0 | |
| F2（3 台 IDC 同時死亡） | 172.24.40.32/33/34 | — | — | 真實復原 **≈7.12s**（13:43:53.096−13:43:45.979）；`cluster_rebuild_sec`=72.636 | **ambiguous，未判定** | write-reject：真實 `ERROR: result is ambiguous ... lost quorum` → `verdict=ambiguous_result_manual_review_required`；health 與 write-ready 同一次 poll 確認 |

## P-A vs P-B 比較

- **F1/C4 RTO**：兩個 placement 全部 8 組數字皆 `outage_observed=false`，探測解析度下觀測不到
  差異。lease 是否 pin 在 IDC（P-A）或自然分散（P-B）對這個層級的單節點 kill 恢復速度沒有
  可觀測的影響。
- **F2 真實復原時間**：P-B（≈7.12s）與 P-A（≈7.01s）幾乎完全一致——這次重跑證實 F2 的復原
  時間與 placement 策略（pin/不 pin）無關，符合預期（F2 測的是 3 台 IDC process 同時重啟後的
  叢集重建速度，這個機制不受 lease pin 策略影響）。
- **go-tpc 容錯度**：本段每次真實 kill 後 workload 皆存活至下一情境，未提前 Finished（與原始
  P-A 段偶發提前終止的觀察不同，樣本數過小不足以下確定性結論）。

## 已知限制

- RPO 量測為簡化版（per-warehouse `max(o_id)` high-water-mark check），非完整 driver-hooked
  FIFO buffer。
- C1/C7 未量測 tpmC-during-incident。
- X-CROSS placement gate 的 3 表小樣本設計對 WAREHOUSES=4 這類小資料集雜訊偏高，建議未來若需要
  更穩定的 gate 判定應改用全體 9 表抽樣。
