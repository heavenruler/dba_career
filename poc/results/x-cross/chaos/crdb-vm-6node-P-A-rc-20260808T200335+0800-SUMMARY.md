# CockroachDB — vm-6node P-A×A-S — chaos/failover 實跑摘要

> **⚠️ 2026-08-11 已被真實重跑取代**：本檔案記錄的原始數字（TS=`20260808T200335+0800`）已於
> 2026-08-10 稽核（[`CHAOS-FAILOVER-AUDIT-2026-08-10.md`](../../../phase-crossregion/CHAOS-FAILOVER-AUDIT-2026-08-10.md)）
> 確認 F1/C4 全部 4 組 RTO 數字 `outage_observed=false`（探測從未觀測到中斷）而撤回；F2 write-reject
> 判定重新分類為 `ambiguous_result_manual_review_required`。
>
> 完整重跑已於 2026-08-10/11 完成，環境全新重建（TS=`20260810T142439+0800`），使用稽核修正後的
> 4 支腳本（`wall-clock-wrapper.sh`／`chaos-c1-partition-execute.sh`／
> `run-vm6-f2-idc-death-execute.sh`／`chaos-c7-disk-slow-execute.sh`）。**本檔案下方內容已完全
> 替換為該次重跑的真實數字**，舊 TS 的 artifact 保留於
> `results/x-cross/chaos/crdb-vm-6node-P-A-rc-20260808T200335+0800-chaos/` 供追溯，但不再作為
> 引用依據。詳細方法論與跨 DB 比較見
> [`XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md`](../../../phase-crossregion/XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md)。

- TS（重跑）: `20260810T142439+0800`
- Placement: P-A（2 IDC + 1 GCP voter, RF=3；deploy-time CONFIGURE ZONE 使 lease holder 100% 落 IDC）
- Profile: A-S（steady workload 連 GCP host `10.160.152.11:26257`，WAREHOUSES=4）
- CRDB v26.2.0。與 TiDB/YBDB 不同：單一 `cockroach` process（無元件拆分問題），per-range leaseholder
  貫穿全域
- 執行順序：C7 → C1 → F1(leader/follower) → C4(leader/follower) → F2
- Kill target 選擇：`SHOW RANGES FROM DATABASE tpcc WITH TABLES, DETAILS` 對全部 9 張 tpcc table
  抽樣 lease 分布 — node1(`.32`)=6（全 IDC 最高）、node3(`.34`)=5、node2(`.33`)=2（全 IDC 最低）。
  選定 **leader-kill=172.24.40.32**、**follower-kill=172.24.40.33**。

## 本次重跑中發現並修正的 2 個新 bug

1. **F2 復原輪詢的 duplicate-key 陷阱**：kill 期間的 ambiguous INSERT 若其實已 commit，後續
   輪詢的 INSERT 會撞 `duplicate key` 錯誤——該錯誤字串含 `error`，會被舊版判定邏輯誤判為
   「仍在拒絕中」而非「已復原」，導致整個 600s 輪詢視窗都測不到復原。已修正
   `run-vm6-f2-idc-death-execute.sh`：kill 前與每次輪詢 INSERT 前都先 best-effort DELETE
   sentinel key，確保冪等。
2. **`chaos-c7-disk-slow-execute.sh` 需要 fio 已安裝**：全新 VM 預設未裝 fio，首次執行
   fail-fast（F-009 稽核修正後的正確行為）。已對全部 IDC host 手動 `dnf install fio`。

## 結果總表

| 情境 | kill target | role | graceful | RTO | RPO | 備註 |
|---|---|---|---|---|---|---|
| C7 (fio 30s) | 172.24.40.32 | — | — | N/A | N/A | `fio_launch_ok=true`；6/6 node available/live 全程未受影響 |
| C1 (WAN partition 30s) | 全部 6 台 | — | — | N/A | N/A | 探測全程 ok（P-A 下 lease 100% 在 IDC，探測從 IDC 側連 IDC 端點，partition 只切斷 IDC↔GCP，不影響此連線；30s 後自動 restore，6/6 復原） |
| F1-leader | 172.24.40.32 | leader | 是（`node drain --shutdown`） | `outage_observed=false`（ok=514, err=0） | 0 | 探測全程未偵測到任何寫入失敗；RTO 無法計算 |
| F1-follower | 172.24.40.33 | follower | 是 | `outage_observed=false`（ok=504, err=0） | 0 | 同上 |
| C4-leader | 172.24.40.32 | leader | 否（`systemctl kill -s SIGKILL`） | `outage_observed=false`（ok=470, err=0） | 0 | 同上 |
| C4-follower | 172.24.40.33 | follower | 否 | `outage_observed=false`（ok=454, err=0） | 0 | 同上 |
| F2（3 台 IDC 同時死亡） | 172.24.40.32/33/34 | — | — | 真實復原 **≈7.01s**（07:26:10.800−07:26:03.787）；`cluster_rebuild_sec`=74.876 | **ambiguous，未判定** | write-reject：真實 `ERROR: result is ambiguous ... lost quorum` → `verdict=ambiguous_result_manual_review_required`；health 與 write-ready 同一次 poll 確認（精度緊密） |

## 觀察

- **F1/C4 全數 `outage_observed=false`**：4 組獨立情境（leader/follower × graceful/ungraceful）
  皆一致重現「單一 IDC node kill 在 100ms 探測解析度下觀測不到中斷」——這是用稽核修正後、
  誠實回報 `outage_observed`/`rto_sec:null` 的邏輯得到的**真實觀測結果**，不是探測失效的假象。
  可能原因：CRDB 單一 range 的 lease 重新選舉在此資料規模（WAREHOUSES=4，13 個 range）下速度
  快過 100ms 探測週期，或探測本身連的固定 probe table 剛好不受影響。這個限制本身已記錄在
  比較報告的方法論章節。
- **F2 真實復原時間 ≈7.01s**：與同一 campaign 內 CockroachDB P-B 段（≈7.12s）高度一致，顯示
  P-A/P-B 兩種 placement 下 F2（IDC 全滅）復原時間本身相當穩定，不受 lease pin 與否影響
  （這符合預期：F2 測的是 3 台 IDC process 同時重啟後的叢集重建時間，與哪個 node 曾經是
  leader 較無關）。
- **write-reject 判定**：CockroachDB 在 quorum 遺失時回報 `result is ambiguous`（而非乾淨拒絕），
  代表 CockroachDB 自己也無法確認寫入是否已提交——這與 TiDB/YBDB 的乾淨逾時拒絕是不同等級的
  正確性保證，已在跨 DB 比較報告中特別標註。

## 已知限制

- RPO 量測為簡化版（per-warehouse `max(o_id)` high-water-mark check），非完整 driver-hooked
  FIFO buffer。
- C1/C7 未量測 tpmC-during-incident。
- F1/C4 的 100ms 探測解析度不足以判定「單節點 kill 是否真的零延遲」——只能確認「延遲短於可觀測
  下限」。
