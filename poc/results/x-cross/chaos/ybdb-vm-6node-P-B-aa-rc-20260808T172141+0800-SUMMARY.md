# YugabyteDB — vm-6node P-B×A-A — chaos/failover 實跑摘要

> **⚠️ 2026-08-11 已被真實重跑取代**：本檔案記錄的原始數字（TS=`20260808T172141+0800`，含
> 已撤回的「殺真實 tablet 資料 leader 導致 RTO 變慢 10 倍」推論）已於 2026-08-10 稽核
> （[`CHAOS-FAILOVER-AUDIT-2026-08-10.md`](../../../phase-crossregion/CHAOS-FAILOVER-AUDIT-2026-08-10.md)）
> 撤回；完整重跑已於 2026-08-10/11 完成（新 TS=`20260810T233326+0800`，WAREHOUSES=128）。
> **本檔案下方內容已完全替換為該次重跑的真實數字**。「YBDB master 執行緒暴增 bug」這項獨立
> 發現（與 RTO 方法論問題無關）在本次重跑中**未再重現**（thread count 正常，見下方觀察）。
> 詳細方法論見
> [`XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md`](../../../phase-crossregion/XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md)。

- TS（重跑）: `20260810T233326+0800`
- Placement: P-B（2 IDC + 1 GCP voter, RF=3, **不 pin preferred_zones**）
- Profile: A-A（steady workload 連 GCP host `10.160.152.11:5433`，WAREHOUSES=128）
- 執行順序：C7 → C1 → F1(leader/follower) → C4(leader/follower) → F2
- Kill target 選擇：P-B 不 pin，`list_all_tablet_servers` 即時流量在測試當下皆接近 0（無即時
  workload），改用 SST 累積資料量作活躍度代理指標——IDC 側 `.33`=8.65GB（最高）、
  `.34`=6.88GB、`.32`=2.53GB（最低）。選定 **leader-kill=172.24.40.33**、
  **follower-kill=172.24.40.32**。

## 本次重跑中的操作细節

同 P-A 段，YBDB 的 `yugabyted stop` 不會自動重啟，每個 F1/C4 情境之間手動確認 6/6 ALIVE 後才
進入下一情境。F1-leader 情境執行時曾遇到一次逾時（清掉殘留 process、確認叢集健康、重試後正常
完成，master thread count 全程維持 27-30 正常值，未觀測到 8/8 原始記錄的執行緒暴增現象）。

## 結果總表

| 情境 | kill target | role | graceful resign | RTO | RPO | 備註 |
|---|---|---|---|---|---|---|
| C7 (fio 磁碟競爭 30s) | 172.24.40.33 | — | — | N/A | N/A | 30s 注入正常，6/6 tserver ALIVE 全程未受影響 |
| C1 (WAN partition 30s) | 全部 6 台 | — | — | N/A | N/A | 探測全程 ok；30s 後自動 restore，6/6 ALIVE 復原 |
| F1-leader | 172.24.40.33 | leader | 是 | `outage_observed=false`（ok=119, err=0） | 0 | |
| F1-follower | 172.24.40.32 | follower | 是 | `outage_observed=false`（ok=122, err=0） | 0 | |
| C4-leader | 172.24.40.33 | leader | 否 | `outage_observed=false`（ok=113, err=0） | 0 | |
| C4-follower | 172.24.40.32 | follower | 否 | `outage_observed=false`（ok=122, err=0） | 0 | |
| F2（3 台 IDC 同時死亡） | 172.24.40.32/33/34 | — | — | 真實復原 **≈3.65s**（17:57:21.207−17:57:17.554）；`cluster_rebuild_sec`=11.536 | 0 | write-reject：`psql: timeout expired` → `verdict=write_correctly_rejected`；復原後 6/6 ALIVE |

## P-A vs P-B 比較

- **F1/C4 RTO**：兩個 placement 全部 8 組數字皆 `outage_observed=false`，探測解析度下觀測不到
  「殺 master leader」vs「殺高流量 tablet host」之間的差異。8/8 原始 campaign 曾推論「殺真實
  tablet 資料 leader 導致 RTO 變慢 10 倍」，本次重跑再次確認**這個推論不成立**——兩種 kill
  目標選擇方式在這個探測解析度下結果完全一致。
- **F2 真實復原時間**：P-B（≈3.65s）與 P-A（≈2.99s）同量級，兩次重跑皆與 8/8 原始數字
  （P-A≈3.2s／P-B≈3.05s）方向一致，強化 YBDB F2 復原時間穩定在 ~3s 左右這個結論的可信度。
- **master 執行緒暴增問題未再重現**：這是本次重跑與原始 campaign 的一個重要差異——8/8 原始
  campaign 在 P-B 段真實觀測到 `.34` yb-master 執行緒暴增至 1147（NLWP），本次重跑全程維持
  27-30 正常值。這暗示該 bug可能與特定的重試/選舉時序條件相關，不是每次 kill 都會觸發，
  屬於間歇性穩定性問題而非確定性 bug——原始發現本身仍然有效（真實觀測過），但無法用本次
  重跑再次確認其觸發條件。

## 已知限制

- RPO 量測為簡化版（per-warehouse `max(o_id)` high-water-mark check），非完整 driver-hooked
  FIFO buffer。
- C1/C7 未量測 tpmC-during-incident。
- Kill target 選擇本次用 SST 累積量作活躍度代理（測試當下無即時 workload 可採樣 Reads/s，
  與 P-A 段 kill target 選擇方式略有出入，但兩者在 F1/C4 上都得到相同的 `outage_observed=false`
  結果，不影響結論）。
