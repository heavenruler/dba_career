# X-CROSS P-B×A-S 結案報告（雛形）— IDC↔GCP Cross-Region 3-DB W=128 P-B Placement 正式測試

> 目的：驗證 TiDB/YBDB/CRDB 三家 DB 在 6-node cross-region 拓樸下、**P-B
> placement（散置 RF=3 全 voter、leader 跨區混合分佈 30-70%；GCP 端
> DB 節點與 IDC 端一樣是全 RF voter，非 standby DB）**於 A-S（**GCP
> client 端不發負載**，只有 IDC client 打標準 TPCC）profile 的 W=128
> 執行結果。TS=`20260727T223650+0800`，執行順序 TiDB→YBDB→CRDB，
> 三家皆 PASS 並已歸檔，VM 已 destroy。

## 1. 執行摘要

| DB | tpmC@128 | tpmTotal@128 | NEW_ORDER p99@128 | 錯誤率 | Placement gate（§6.6 抽樣） | Artifact |
|---|---:|---:|---:|---:|---|---|
| **TiDB** | [15,107.4](../results/x-cross/smoke/early-runs/20260727T223650+0800/tidb-vm-6node-P-B-rc-20260727T223650+0800/summary.json) | 33,505.6 | 664.4ms | 0% | idc=10/19（52%）PASS | [`tidb-vm-6node-P-B-rc-20260727T223650+0800`](../results/x-cross/smoke/early-runs/20260727T223650+0800/tidb-vm-6node-P-B-rc-20260727T223650+0800/) |
| **YBDB** | [2,485.6](../results/x-cross/smoke/early-runs/20260727T223650+0800/ybdb-vm-6node-P-B-rc-20260727T223650+0800/summary.json) | 5,498.9 | 6,227.7ms | 0% | idc=1/3（33%）PASS | [`ybdb-vm-6node-P-B-rc-20260727T223650+0800`](../results/x-cross/smoke/early-runs/20260727T223650+0800/ybdb-vm-6node-P-B-rc-20260727T223650+0800/) |
| **CRDB** | [11,640.0](../results/x-cross/smoke/early-runs/20260727T223650+0800/crdb-vm-6node-P-B-rc-20260727T223650+0800/summary.json) | 25,903.4 | 1,301.9ms | 0% | idc=7/12（58%）PASS | [`crdb-vm-6node-P-B-rc-20260727T223650+0800`](../results/x-cross/smoke/early-runs/20260727T223650+0800/crdb-vm-6node-P-B-rc-20260727T223650+0800/) |

三家全程 0 error（16/32/64/128 四檔位、每檔 5 輪皆無交易錯誤）。P-B
placement gate（`prepare.sh` §6.6 抽樣 warehouse/district/customer 3 表）
三家皆落在 30-70% 窗口內通過；workload 結束後全體 9 表的
`gcp-replica-gate.sh` 判準（CRDB 實測 idc/gcp lease holder 各 24/48=50%，
見 §5）亦通過。

## 2. 測試目的與範圍

- 驗證 P-B（散置 RF=3、leader 混合分佈）在單一資料庫/whole-table
  placement policy 下**無法**表達機率式跨區混合分佈這一設計缺口，並驗證
  三家資料庫個別修復方案（TiDB 雙 `PRIMARY_REGION` policy／YBDB 雙
  tablespace + 主動 leader_stepdown enforcer／CRDB 雙 `lease_preferences`
  + `PARTITION BY RANGE`）在正式 W=128 規模下仍然有效、不因資料量放大
  （customer/order_line/stock 的 range 自動切分）而失效。
- 產出 P-B×A-S 的正式效能基準數字，供後續 P-B 其他 workload
  （A-A、A-A-RO）比較基線。
- Profile：A-S＝單邊（僅 IDC 端）標準 TPCC read-write mix，warehouses=128，
  執行緒檔位 16/32/64/128，各檔位 5 輪。

## 3. 測試環境與共同口徑

- 拓樸：`vm-6node-P-B`（IDC 3 節點 + GCP 3 節點，6 節點皆為 RF=3 全
  voter，無 arbiter-only 角色）。
- 量測口徑：`tests/common/summary-from-stdout.py v1` 由
  `runs/threads-*/round-*/go-tpc-stdout.txt` 彙整；`tpmC_mean`/`tpmTotal_mean`
  為該檔位 5 輪算術平均；延遲 p50/p95/p99 為 5 輪平均。
- 三家 `manifest_sha256` 一致（`b7256b824aa884207205a045a74c9c1e8da8c3465a5244eb7a4220a58f61d858`），
  確認同一批設定產出。

## 4. 主結果（各執行緒檔位）

### TiDB

| 執行緒 | tpmC | tpmTotal | 效率% | NEW_ORDER p50/p95/p99 (ms) | 錯誤率 |
|---:|---:|---:|---:|---|---:|
| 16 | 6,642.6 | 14,831.7 | 403.5 | 88.1 / 151.0 / 204.7 | 0% |
| 32 | 10,828.2 | 24,062.3 | 657.8 | 107.4 / 179.5 / 239.9 | 0% |
| 64 | 14,203.0 | 31,559.6 | 862.8 | 159.4 / 251.7 / 325.5 | 0% |
| 128 | 15,107.4 | 33,505.6 | 917.8 | 286.9 / 503.3 / 664.4 | 0% |

### YBDB

| 執行緒 | tpmC | tpmTotal | 效率% | NEW_ORDER p50/p95/p99 (ms) | 錯誤率 |
|---:|---:|---:|---:|---|---:|
| 16 | 1,297.2 | 2,885.7 | 78.8 | 506.7 / 697.9 / 818.7 | 0% |
| 32 | 1,901.8 | 4,215.9 | 115.5 | 671.1 / 1,295.2 / 1,704.5 | 0% |
| 64 | 1,558.8 | 3,477.4 | 94.7 | 1,570.3 / 3,597.0 / 4,885.5 | 0% |
| 128 | 2,485.6 | 5,498.9 | 151.0 | 2,026.7 / 4,536.6 / 6,227.7 | 0% |

YBDB 在 th=32→64 出現 tpmC 反常下滑（1,901.8→1,558.8，同時
`tpmC_range_mean_pct` 從 38.7% 升到 61.9%，5 輪間變異度已相當大），
th=128 才回升到全程最高值；延遲亦是三家中最高（p99@128 達 6.2s）。
與既有 GCP 側吞吐調查（`XCROSS-AARO-CLOSING-REPORT-DRAFT.md` §5.2/§6
判定 YBDB 磁碟 I/O 經 `pd-standard` 為瓶頸之一）方向一致，判斷仍是
YBDB 在此硬體規格下的既有瓶頸特徵，非本輪新增問題；不影響
placement gate 判定與流程結案，留待後續 YBDB 專項優化評估。

### CRDB

| 執行緒 | tpmC | tpmTotal | 效率% | NEW_ORDER p50/p95/p99 (ms) | 錯誤率 |
|---:|---:|---:|---:|---|---:|
| 16 | 4,494.1 | 9,987.1 | 273.0 | 82.2 / 338.9 / 439.6 | 0% |
| 32 | 8,109.7 | 18,040.2 | 492.7 | 113.2 / 362.4 / 446.3 | 0% |
| 64 | 11,227.6 | 24,963.3 | 682.1 | 196.3 / 476.5 / 644.2 | 0% |
| 128 | 11,640.0 | 25,903.4 | 707.1 | 365.7 / 906.0 / 1,301.9 | 0% |

CRDB th=64→128 tpmC 幾乎打平（11,227.6→11,640.0，僅 +3.7%）但 p99
延遲翻倍（644→1,302ms），且 `tpmC_range_mean_pct` 升到 25.5%（5 輪中
最高一輪 12,995 vs 最低 10,024），顯示 th=128 已接近本拓樸下 CRDB
的併發飽和點。

## 5. Placement Gate 驗證

`prepare.sh` §6.6 抽樣（僅 warehouse/district/customer 3 表）：

- TiDB：idc=10/19（52%）PASS
- YBDB：idc=1/3（33%）PASS
- CRDB：idc=7/12（58%）PASS

workload 結束後 CRDB 實測 lease holder 分佈（全體 9 表，
`gcp-replica-gate.sh` 判準）：

```
lease_holder  locality                    range_count
3             region=idc,zone=idc-vlan241  10
1             region=idc,zone=idc-vlan241  10
2             region=idc,zone=idc-vlan241   4
4             region=gcp,zone=gcp-asia-east1-a  10
6             region=gcp,zone=gcp-asia-east1-c   7
5             region=gcp,zone=gcp-asia-east1-b   7
```

idc=24、gcp=24，共 48，idc 佔比 50%——三家最終落點中最貼近理論中點，
反映 CRDB 修復方案（`customer`/`order_line`/`stock` 三張大表改用
`PARTITION BY RANGE` 分攤大表 range 主導效應）收斂效果良好。

## 6. 各資料庫觀察（設計缺口與修復）

三家皆撞上同一個跨資料庫共通的設計缺口：**單一 database-wide 或
whole-table 的 placement policy（TiDB `PRIMARY_REGION`、YBDB
`leader_preference`、CRDB `lease_preferences`）表達的是「優先順序」，
不是「機率混合」**——套用同一份 policy 給全部資料，必然收斂到單一
極端（0% 或 100%），無法自然產生 30-70% 混合分佈。三家修復手段各異
但原理一致：把資料拆成兩組，各自套用方向相反的 policy。

- **TiDB**：9 張 TPCC 表拆兩組 `PRIMARY_REGION` policy（idc 優先 5 表 /
  gcp 優先 4 表），抽樣 3 表跨兩組確保抽樣結果不同質。
- **YBDB**：新增雙 tablespace（`ts_p_b_leader_idc`/`ts_p_b_leader_gcp`）+
  `run-vm6-suite.sh` 內主動 `leader_stepdown` enforcer（passive `SET
  TABLESPACE` 不會搬動已落地的 tablet leader，需主動踢動）。
- **CRDB**：歷經 8 次嘗試，除了同款雙 `lease_preferences` 設計外，另撞上
  W=128 資料量放大特有的問題——`customer`/`order_line`/`stock` 三張大表
  在 W=128 下 auto-split 出多個 range，整表分單一方向會被大表的 range
  數量主導抽樣/全體判準，改用 `PARTITION BY RANGE`（依各表 warehouse-id
  攔腰切兩半、各自掛相反方向 zone config）解決；另修復 CRDB v26.2
  `num_voters` 缺漏、enforcer 與 partition zone config 互搶的自我衝突、
  以及 2 次 systemd 啟動競態（`daemon-reload` 未完全 settle 即
  `start` 導致命令消失）。完整踩坑細節見 `SESSION-HISTORY.md`
  2026-07-27~29 節。

## 7. 已知限制

- 本報告涵蓋 P-B×A-S 單一 workload（本輪截稿時 P-B×A-A、P-B×A-A-RO
  尚未執行；兩者已於 2026-07-30/08-01 完成，數字見
  `XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md`／
  `XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md`，橫向彙總見
  `XCROSS-PB-ALL-WORKLOADS-SUMMARY.md`）。
  `check-nearread.sh`/`check-nearread-realtxn.sh`/`sample-nearread-loop.sh`
  已補上 `--placement P-B` 分支（task #44，2026-07-30，見
  `SESSION-HISTORY.md` 同期節），P-B×A-A-RO 執行前置已就緒。
- YBDB th=32→64 的 tpmC 反常下滑與高延遲，判斷與既有磁碟 I/O 瓶頸
  同源，但未做專項隔離驗證（例如換用 pd-ssd 重跑對照）確認根因，
  留待後續 YBDB 專項優化排程。
- CRDB th=128 已接近飽和（p99 翻倍、tpmC 打平），若後續要拉高
  warehouses 或執行緒數，建議先評估是否需要調整 range 大小或增加
  分區數量。

## 8. Artifact 路徑

```
results/x-cross/smoke/early-runs/20260727T223650+0800/tidb-vm-6node-P-B-rc-20260727T223650+0800/
results/x-cross/smoke/early-runs/20260727T223650+0800/ybdb-vm-6node-P-B-rc-20260727T223650+0800/
results/x-cross/smoke/early-runs/20260727T223650+0800/crdb-vm-6node-P-B-rc-20260727T223650+0800/
results/x-cross/smoke/early-runs/20260727T223650+0800/vm-rebuild-proof-20260727T223650+0800.json
results/x-cross/smoke/early-runs/20260727T223650+0800/win-3db-driver-console-20260727T223650+0800.log
results/x-cross/smoke/early-runs/20260727T223650+0800/fetch-receipt.json
```

各 DB suite 目錄下 `summary.json` 為機器可讀彙整來源（含
`region_routing_evidence.placement_gate`）；三個 DB suite 原始
artifact（各 ~40M）依既有慣例 gitignore，僅上述 metadata 檔案入 repo。
VM 已於採證後依拍板紀律 `terraform destroy`，兩側 state 歸零。

`fetch-receipt.json` 一併記錄本次 fetch 附帶撈回的 32 個歷史 run
（本機他處查無其他副本，判定為孤兒、暫不刪除；其餘 86 個歷史 run
副本在本機他處已有收錄，屬冗餘但同樣暫不刪除，皆已 gitignore
不影響 repo 大小）。

詳細踩坑過程見 `SESSION-HISTORY.md` 2026-07-27~29 節。
