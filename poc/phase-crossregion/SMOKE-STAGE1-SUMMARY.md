# Stage 1 Cross-Region Smoke — 三家 DB 彙整（2026-07-08 ~ 2026-07-09）

> Stage 1 目的：驗證 TiDB/CRDB/YBDB 三家 DB 在 6-node cross-region（3 IDC + 3 GCP）
> 拓樸下，P-A（IDC leader-pin）placement + freeze/unfreeze + WAN probe 全鏈可跑通，
> 為 Win-1 正式 W=128 採樣前的健檢輪。**三家皆為 quick smoke（W=1 t16 N=1），
> tpmC 數字僅供「跑得通」驗證，非正式效能基準**——正式基準見 Win-1 W=128 章節
> （`results/x-cross/pipeline-log.md`）。

## 結論

| DB | 版本 | 狀態 | tpmC | tpmTotal | Placement gate | 交易錯誤 | Artifact TS |
|---|---|---|---|---|---|---|---|
| **TiDB** | v8.5.2 | ✅ PASS | 593.0 | 1355.9 | idc=19/19（100%） | 0 / 1370 | `20260708T160747+0800` |
| **CRDB** | v26.2.0 | ✅ PASS | 4623.5 | 10317.0 | （§CRDB 附註） | 0 / 10651 | `20260708T214141+0800` |
| **YBDB** | 2025.2.2.2-b11 | ✅ PASS | 2999.0 | 6638.0 | idc=3/3（100%） | 0 / 33185 | `20260709T140516+0800` |

三家皆 `.suite.done`、無非預期 `failed.txt`、freeze/unfreeze dump 齊、WAN probe
（chrony + netdev + iperf3）全通過。**Stage 1 三家全數完成**，可進 Win-1 W=128
正式採樣（CRDB/YBDB 尚待排；TiDB 已於 `baseline/w128/20260703T092243+0800`
完成）。

## 各家細節

### TiDB（`20260708T160747+0800`）

- Placement gate：`idc_leader_count=19 / total=19`（100% IDC，P-A 設計符合）。
- `region_routing_evidence.near_read_setup`：`tidb_replica_read=closest-replicas`、
  `pd_enable_follower_handle_region=ON` 確認 near-read 路由已生效。
- NEW_ORDER p50/p95/p99 = 637.5 / 1342.2 / 1677.7 ms（W=1 極小資料量下的參考值，
  非正式延遲基準）。
- 本輪順道驗證 S1-S8（Fable 健檢修復）+ 2 個新 bug（freeze 路徑 `$SELF/../freeze/`
  誤植、iperf3 埠+JSON error 欄位偵測）對 TiDB 實際執行路徑無破壞性影響。
  詳見 SESSION-HISTORY 2026-07-08 節。

### CRDB（`20260708T214141+0800`）

- `region_routing_evidence` 僅含 `near_read_setup`（`kv.closed_timestamp.follower_reads.enabled=t`
  確認 follower read 已開）；**無 `placement_gate` 結構化欄位**——CRDB 分支的
  `prepare.sh` 只寫 `placement-gate-P-A.txt`（原始 `SHOW RANGES` 輸出），不像
  TiDB/YBDB 寫 `.json`，`summary-from-stdout.py` 因此不解析出結構化 verdict
  （`check-static-artifacts.py` 已改為接受 `.txt`/`.json` 任一，見 S1-S8 記錄，
  非本次新發現，附註於此供彙整完整性）。原始 `.txt` 顯示所有 range
  `lease_holder_locality` 皆為 `region=idc`（人工核對通過）。
- NEW_ORDER p50/p95/p99 = 52.4 / 352.3 / 1342.2 ms。
- 本輪首次驗證新接線的 `freeze-crdb.sh`/`unfreeze-crdb.sh` 呼叫（`freeze-state/`
  有 `crdb-lease-rebal-before.tsv` + `crdb-split-load-before.tsv`），並抓出修復
  3 個從未 live 測過的 bug（缺早套 placement watcher、`--format=tsv` 布林值
  `t`/`f` 誤判、`check-static-artifacts.py` 副檔名限制）。詳見 SESSION-HISTORY
  2026-07-08（續）節。

### YBDB（`20260709T140516+0800`）

- Placement gate：`idc_leader_count=3 / total=3`（100% IDC）。
- `region_routing_evidence.near_read_setup`：`yb_read_from_followers=on`、
  `yb_follower_read_staleness_ms=30000` 確認 follower read 路由已生效。
- NEW_ORDER p50/p95/p99 = 125.8 / 570.4 / 939.5 ms。
- `freeze-state/` 有 `yb-lb-state-before.txt` + `yb-universe-before.txt`（load
  balancer freeze/unfreeze 首次 live 驗證通過）。
- YBDB 是三家中最晚完成、過程最曲折的一家——**連續 3 次 smoke 嘗試皆敗於
  master raft quorum 相關的連環 bug**，直到第 4 次才乾淨跑完整個 benchmark
  （前 3 次的失敗 artifact 未保留，VM 於診斷過程中重建數次）。根因與修法：
  1. **`prepare.sh` grep -c 在 `set -e` 下的死鎖**（`bea9ae1d` 二修仍有 bug，
     `44d95c42` 三修用 `|| true` 修正）。
  2. **yugabyted 自動 master 選舉 region-blind**：`configure data_placement
     --rf=3` 擴編時無 region 概念，GCP tserver 會搶到本該屬於 IDC 的 master
     名額（3 次全新部署 3/3 復現，證實非偶發）。修法：新增
     `phase-crossregion/scripts/ybdb-master-quorum-gate.sh`，接入
     `phase4-ybdb-fix6n`，部署後強制用 `yb-admin change_master_config` 修正
     raft membership 回 3 台 IDC-only + 校正 `yugabyted.conf` 的
     `current_masters` 快取欄位。
  3. **`current_masters` 快取只影響下次 restart**：從未重啟過的既有 process
     （`.33`/`.34`）仍帶著部署當下的殘缺 `--tserver_master_addrs`（各缺 1 台
     其他 IDC peer）——這正是本輪一度出現的「`.33` postgres 完全死鎖」懸案
     真正成因。gate 補上逐台 live flag 校驗 + 缺漏自動重啟修復。
  4. **`coldreset-ybdb.sh` 缺 catalog-wait tserver flags**（`9f3306fe` 補
     `wait_for_ysql_backends_catalog_version_client_master_rpc_{timeout,margin}_ms`，
     與 ansible 部署時的既有設定對齊）。
  5. gate 腳本自身也踩到一個經典 bash 陷阱（`while read ... | ssh` 迴圈裡
     ssh 吃掉迴圈的 stdin，讓修復迴圈少跑一輪），一併修正。

  完整根因分析、診斷過程、測試計畫見 `fable-refactor/ybdb-master-quorum-handoff.md`
  + `fable-refactor/ybdb-master-quorum-handoff-solution.md`（保留備查，未刪）。
  Master-quorum gate 已成為 `phase4-ybdb-fix6n` 的標準步驟，往後每次 YBDB
  deploy 皆會自動套用，不需再手動介入。

## 已知限制（不擋 Stage 1 結案，Win-1 前留意）

- 三家皆為 W=1（極小資料量）quick smoke，`efficiency_mean_pct` 數字（4611%/
  35953%/23320%）純粹反映「小資料量下遠超 TPCC 理論值」的統計假象，無意義，
  Win-1 W=128 才具參考價值。
- CRDB 的 `placement_gate` 結構化欄位缺失（見上）是既有格式不對稱（`prepare.sh`
  兩分支寫法不同），非本輪新增缺陷；人工核對過但機器可讀性較弱，Wave 6 report
  產出前可考慮讓 CRDB 分支也補寫 `.json`（不動 `tests/common/*`，可在
  `summary-from-stdout.py` 端補 CRDB `.txt` 解析）。
- Win-1 CRDB/YBDB 正式 W=128 前記得移除本輪 smoke 遺留的低 warehouse 測試資料
  （tpcc database 需重新 DROP+CREATE，Q11 per-cell full rebuild 本就會做，
  非額外動作）。

## Artifact 路徑

```
results/x-cross/smoke/early-runs/20260708T160747+0800/tidb-vm-6node-P-A-rc-20260708T160747+0800/
results/x-cross/smoke/early-runs/20260708T214141+0800/crdb-vm-6node-P-A-rc-20260708T214141+0800/
results/x-cross/smoke/early-runs/20260709T140516+0800/ybdb-vm-6node-P-A-rc-20260709T140516+0800/
```

各目錄下 `summary.json` 為機器可讀彙整來源；`prepare/placement-gate-P-A.{json,txt}`
為 placement 驗收原始證據；`freeze-state/` 為凍結前 config dump；
`runs/{warmup,threads-16/round-1}/wan-probe-*.txt` 為 WAN 連通性證據。

詳細踩坑過程見 `SESSION-HISTORY.md` 2026-07-08 / 2026-07-08（續）/ 2026-07-09
（含三續）各節。
