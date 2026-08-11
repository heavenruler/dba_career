# YugabyteDB — vm-6node P-A×A-S — chaos/failover 實跑摘要

> **⚠️ 2026-08-11 已被真實重跑取代**：本檔案記錄的原始數字（TS=`20260808T144840+0800`）已於
> 2026-08-10 稽核（[`CHAOS-FAILOVER-AUDIT-2026-08-10.md`](../../../phase-crossregion/CHAOS-FAILOVER-AUDIT-2026-08-10.md)）
> 撤回；完整重跑已於 2026-08-10/11 完成（新 TS=`20260810T214440+0800`，WAREHOUSES=128，與原始
> campaign 建置紀錄一致）。**本檔案下方內容已完全替換為該次重跑的真實數字**。詳細方法論見
> [`XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md`](../../../phase-crossregion/XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md)。

- TS（重跑）: `20260810T214440+0800`
- Placement: P-A（2 IDC + 1 GCP voter, RF=3, preferred_zones=IDC → leader 全數固定 IDC）
- Profile: A-S（steady workload 連 GCP host `10.160.152.11:5433`，WAREHOUSES=128，載入耗時
  約 1 小時）
- 執行順序：C7 → C1 → F1(leader/follower) → C4(leader/follower) → F2
- Kill target 選擇：直接查 `list_all_masters` 確認當下真正的 master LEADER/FOLLOWER（避免重演
  原始 campaign 曾發生的角色標記錯誤）。F1-leader 用當時的 LEADER=172.24.40.34；F1-follower
  原訂 172.24.40.32，但因 F1-leader kill 後觸發重新選舉，172.24.40.32 變成新 LEADER，改用
  全程未被動過、穩定為 FOLLOWER 的 172.24.40.33。

## 本次重跑中確認的已知問題（與 8/8 原始 campaign 記錄一致，非新發現）

**YBDB `yugabyted stop` 不會像 CRDB/TiDB 的 systemd kill 一樣自動重啟**：CRDB/TiDB 的 kill 指令
走 systemd（`Restart=on-failure`），節點會在 ~10s 內自動復活；YBDB 用 `yugabyted stop`
直接停掉 supervisor，節點會維持停止狀態直到手動 `yugabyted start`。因此本段每個 F1/C4 情境
之間都手動確認並補一次 `yugabyted start` + 等待 6/6 tserver ALIVE，才進入下一情境，避免
「上一情境殺的節點還沒起來就疊加下一次 kill」污染結果。過程中曾撞到一次 `run-vm6-chaos-execute.sh`
執行逾時（懷疑與 master leader stepdown 後的短暫選舉風暴有關，與原始 campaign 記錄的
「YBDB master 執行緒暴增」屬同一類已知現象），清掉殘留 process 並確認叢集健康後重跑即恢復正常，
未再觀測到執行緒異常暴增（正常值 27-30，與 8/8 段記錄的 1147 異常值不同）。

## 結果總表

| 情境 | kill target | role | graceful resign | RTO | RPO | 備註 |
|---|---|---|---|---|---|---|
| C7 (fio 磁碟競爭 30s) | 172.24.40.34 | — | — | N/A | N/A | 30s 注入正常，6/6 tserver ALIVE 全程未受影響 |
| C1 (WAN partition 30s) | 全部 6 台 | — | — | N/A | N/A | 探測全程 ok；30s 後自動 restore，6/6 ALIVE 復原 |
| F1-leader | 172.24.40.34（當時真正的 master LEADER，已核對） | leader | 是（master_leader_stepdown 先於實際 kill） | `outage_observed=false`（ok=101, err=0） | 0 | |
| F1-follower | 172.24.40.33（全程穩定 FOLLOWER） | follower | 是 | `outage_observed=false`（ok=114, err=0） | 0 | |
| C4-leader | 172.24.40.34 | leader | 否 | `outage_observed=false`（ok=115, err=0） | 0 | |
| C4-follower | 172.24.40.32 | follower | 否 | `outage_observed=false`（ok=116, err=0） | 0 | |
| F2（3 台 IDC 同時死亡） | 172.24.40.32/33/34 | — | — | 真實復原 **≈2.99s**（15:32:36.097−15:32:33.109）；`cluster_rebuild_sec`=10.882 | 0 | write-reject：`psql: timeout expired` → `verdict=write_correctly_rejected`；復原後 6/6 ALIVE |

## 觀察

- **F1/C4 全數 `outage_observed=false`**：與 CRDB 兩個 placement 完全一致的模式——單一 IDC
  node kill（含 master leader stepdown+kill）在 100ms 探測解析度下觀測不到中斷。
- **F2 真實復原時間 ≈2.99s**：與同一 campaign 內 YBDB P-B 段（≈3.65s）同量級，也與稽核前
  8/8 原始數字（P-A≈3.2s／P-B≈3.05s）高度吻合，顯示 YBDB 的 F2 復原速度在不同 placement 間
  相當穩定，且此次真實重跑與歷史數字互相印證。
- **YBDB F2 復原（≈3s）明顯快於 CRDB F2 復原（≈7s）**：這個跨 DB 差異在本次真實重跑中再次
  重現，方向性一致，強化了「YBDB 的 quorum-loss 偵測/拒絕機制比 CRDB 更快判定失敗」這個
  跨 DB 觀察的可信度（見比較報告）。

## 已知限制

- RPO 量測為簡化版（per-warehouse `max(o_id)` high-water-mark check），非完整 driver-hooked
  FIFO buffer。
- C1/C7 未量測 tpmC-during-incident。
- F1/C4 之間需要手動介入重啟被殺節點（YBDB 特有的操作負擔，CRDB/TiDB 因 systemd 自動重啟則
  不需要）。
