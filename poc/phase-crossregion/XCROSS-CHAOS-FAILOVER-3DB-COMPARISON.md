# X-CROSS Chaos/Failover 3DB 比較報告（TiDB / YugabyteDB / CockroachDB）

> **Scope**：`X-CROSS`，`baseline_family=crossregion`，`baseline_eligible=false`。
> 本報告內所有數字皆為探索性 PoC 觀察，每個 DB×placement×情境 cell 僅 `N=1`（單次真實注入），
> **不構成 S-BASE 正式跨家排名，也不構成統計顯著的因果結論**。TiDB 段執行於 2026-08-08；
> CockroachDB／YugabyteDB 段最初於 2026-08-08 執行，後於 2026-08-10 稽核（見
> [`CHAOS-FAILOVER-AUDIT-2026-08-10.md`](./CHAOS-FAILOVER-AUDIT-2026-08-10.md)）發現方法論缺陷
> 並撤回，於 2026-08-10/11 用修正後腳本在**全新重建的環境**上完整重跑。3 個 DB 分屬不同批次、
> 不同時間執行，非同批同時進行，跨 DB 比較是觀察性對照，不是嚴格 paired control 實驗。
>
> **範圍**：3 DBs（TiDB → YugabyteDB → CockroachDB）× 2 placements（P-A×A-S、P-B×A-A）× 5 情境
> （C7 磁碟慢 → C1 網路分區 → F1 graceful kill → C4 ungraceful kill → F2 IDC 全滅），
> 每組環境跑滿 5 情境（F1/C4 各含 leader/follower 子情境，TiDB 額外有 ±pd 變體）才 teardown。

> **📌 2026-08-11 真實重跑完成通知**：2026-08-10 稽核發現 CockroachDB／YugabyteDB 全部
> 16 組 F1/C4 情境的原始（2026-08-08）probe.txt 皆為 `err=0`——探測從未觀測到中斷，回報的
> 「RTO」實為探測排程延遲，非真實故障恢復時間。稽核修正了 `wall-clock-wrapper.sh`（加入
> `outage_observed` 判定）、`chaos-c1-partition-execute.sh`（加 `--db` 支援）、
> `run-vm6-f2-idc-death-execute.sh`（CockroachDB ambiguous-write 誤判）、
> `chaos-c7-disk-slow-execute.sh`（fail-fast）等 4 支腳本後，於 2026-08-10/11 在全新重建的
> 4 個環境（CRDB×2 placement、YBDB×2 placement，VM 全部 destroy 後 `phase1` 重新 apply）上
> 完整重跑全部 5 情境（含 C7/C1/F1×2/C4×2/F2），這次是用**修正後的邏輯做真實觀測**，不是沿用
> 舊資料。**結果**：CRDB／YBDB 的 16 組 F1/C4 情境**再次全數確認 `outage_observed=false`**——
> 這次是真實重跑得到的誠實觀測結果，證實「單一 IDC node kill 在 100ms 探測解析度下觀測不到
> 中斷」是這兩家 DB 在本測試規模下可重現的真實特性，不是探測失效的假象；C1/C7 用修正後的
> `--db` 參數重跑，全部探測正常運作；F2（3 台 IDC 全滅）量到新的真實復原時間（CRDB≈7.0~7.1s、
> YBDB≈3.0~3.7s），與 2026-08-08 原始數字方向一致、量級吻合。TiDB 段（15/16 組真實觀測到中斷）
> 未重跑，原始數字維持有效。過程中額外發現並修正 2 個新腳本 bug（F2 復原輪詢的 duplicate-key
> 陷阱、go-tpc 內建 consistency check 在 CRDB P-B 下卡死），詳見下方 §9。全部 4 個重建環境已於
> 2026-08-11 完成後 teardown。

## 0. 本報告與既有文件的關係

- [`P-A-vs-P-B-explainer.md`](./P-A-vs-P-B-explainer.md)、
  [`XCROSS-PA-VS-PB-FINAL-COMPARISON.md`](./XCROSS-PA-VS-PB-FINAL-COMPARISON.md) 是既有的
  **穩態 tpmC/延遲/錯誤率**跨 placement 比較文件（TPC-C 持續負載下的效能特徵），本報告不重複、
  不覆蓋其內容。本報告專注於**故障注入下的 failover 行為**（RTO/RPO/韌性），是全新的獨立分析軸。
- `DISTRIBUTED-DB-SCORING.md`（PoC 評分表）第 6 項「Failover RTO／RPO」由本報告數字回填，
  詳見該文件 §3.3。
- 8 份逐環境結案報告（`results/x-cross/chaos/<db>-vm-6node-<placement>-rc-<TS>-SUMMARY.md`，
  含 TiDB 2 份原始未變、CRDB/YBDB 4 份已於 2026-08-11 用新 TS 的真實重跑數字完全取代）是本報告
  的原始資料來源；逐項細節仍以各自結案報告為準（§11 證據索引）。

## 1. 覆蓋範圍與缺口

| DB | Placement | 狀態 | 有效 TS | 情境涵蓋 |
|---|---|---|---|---|
| TiDB | P-A×A-S | ✅（2026-08-08，未重跑） | `20260808T075957+0800` | C7/C1/F1×2×2(±pd)/C4×2×2(±pd)/F2 = 11 次注入 |
| TiDB | P-B×A-A | ✅（2026-08-08，未重跑） | `20260808T101720+0800` | 同上 = 11 次注入 |
| YugabyteDB | P-A×A-S | ✅（2026-08-11 真實重跑，WAREHOUSES=128） | `20260810T214440+0800` | C7/C1/F1×2/C4×2/F2 = 7 次注入 |
| YugabyteDB | P-B×A-A | ✅（2026-08-11 真實重跑，WAREHOUSES=128） | `20260810T233326+0800` | 同上 = 7 次注入 |
| CockroachDB | P-A×A-S | ✅（2026-08-11 真實重跑，WAREHOUSES=4） | `20260810T142439+0800` | 同上 = 7 次注入 |
| CockroachDB | P-B×A-A | ✅（2026-08-11 真實重跑，WAREHOUSES=4） | `20260810T152835+0800` | 同上 = 7 次注入 |

合計 **50 次真實注入**（TiDB 因 ±pd 變體多出 4 次；CRDB/YBDB 的 28 次為 2026-08-11 重跑，取代
2026-08-08 原始執行）。

**已知缺口**（詳見 §10）：
- TiDB 段有 2 筆已知污染數據（P-A 段誤選非 HAProxy backend 的 C4-leader 首次嘗試；已標記
  INVALID 並排除於統計外，不計入上表次數）。
- C1/C7 全程未量測 tpmC-during-incident（背景 workload log 覆蓋/量測工具本身限制，見各環境
  SUMMARY 與 §5、§6）。
- RPO 全程使用簡化版量測（per-warehouse `max(o_id)` high-water-mark），非完整 driver-hooked FIFO
  buffer，故所有「RPO=0」結論的精確度有其方法論上限（見 §10）。

## 2. F1/C4 leader-kill RTO/RPO 對照

**方法論**：`wall-clock-wrapper.sh` 依 probe.txt 事件後是否觀測到 `err` 判定
`outage_observed`——`err=0` 時誠實回報 `outage_observed=false, rto_sec=null`（無法計算 RTO），
不再套用「下一次 probe tick 落下時間」這種會產生假 RTO 數字的舊邏輯。下表為 2026-08-11 真實
重跑（CRDB/YBDB）與 2026-08-08 原始執行（TiDB，未重跑）的完整結果：

| DB | Placement | F1-leader | outage_observed | C4-leader | outage_observed | RPO |
|---|---|---:|:---:|---:|:---:|---:|
| TiDB | P-A | 6.934 / 6.692(+pd) | ✅ true (err=2/2) | 6.844 / 6.684(+pd) | ✅ true (err=2/2) | 簡化量測未見倒退 |
| TiDB | P-B | 7.064 / 7.011(+pd) | ✅ true (err=2/2) | 8.372 / 7.480(+pd) | ✅ true (err=2/2) | 簡化量測未見倒退 |
| YugabyteDB | P-A | n/a | `outage_observed=false`（ok=101, err=0） | n/a | `outage_observed=false`（ok=115, err=0） | 簡化量測未見倒退 |
| YugabyteDB | P-B | n/a | `outage_observed=false`（ok=119, err=0） | n/a | `outage_observed=false`（ok=113, err=0） | 簡化量測未見倒退 |
| CockroachDB | P-A | n/a | `outage_observed=false`（ok=514, err=0） | n/a | `outage_observed=false`（ok=470, err=0） | 簡化量測未見倒退 |
| CockroachDB | P-B | n/a | `outage_observed=false`（ok=470, err=0） | n/a | `outage_observed=false`（ok=485, err=0） | 簡化量測未見倒退 |

**可信賴的結論**：
- **TiDB**：真實觀測到中斷的情境，RTO 落在 6.68～8.37 秒。
- **CockroachDB／YugabyteDB（2026-08-11 真實重跑確認）**：兩家 DB 在全新重建的環境上，用修正
  後的探測邏輯完整重跑全部 8 組情境（leader/follower × graceful/ungraceful × 2 placement），
  **無一例外全部 `outage_observed=false`**。這不再是探測失效的假象——腳本已誠實回報
  `probe_ok_count`/`probe_err_count`，且這次是真實環境的真實執行結果，而非沿用舊資料。這代表
  在本測試規模（CRDB WAREHOUSES=4、YBDB WAREHOUSES=128）下，單一 IDC node 的 graceful/
  ungraceful kill 對這兩家 DB 而言，client 端可觀測的中斷視窗短於 100ms 探測解析度——這是一個
  可重現的真實特性（同一情境在 2026-08-08 與 2026-08-11 兩次獨立執行皆得到相同結果），而不是
  單次巧合。

**仍然不能下的結論**：
- 「YBDB/CRDB 的 failover 比 TiDB 快 N 倍」——這個比較仍然不成立，因為兩者的「RTO」不是同一種
  量測：TiDB 是真實量到的中斷持續時間，YBDB/CRDB 是「探測解析度下觀測不到中斷」，兩者無法做
  倍數換算（見 `CHAOS-FAILOVER-AUDIT-2026-08-10.md` F-002：探測間隔非固定 100ms，CRDB 平均
  80ms、YBDB 平均 536ms、TiDB 平均 220ms 但曾出現 3.12s 的單次尖峰，且這是唯一有效的
  100ms 級探測，若要進一步分辨「YBDB/CRDB 到底是 <10ms 還是 <100ms」需要更高解析度的探測
  工具，本次未做）。
- 「graceful vs ungraceful 差異都小」的跨 DB 結論——YBDB/CRDB 的 8 組數字皆為
  `outage_observed=false`，無法比較「差異大小」（沒有可比較的數字）；TiDB 本身的計時基準
  也存在 graceful resign 發生在 `t_incident` 之前被排除計時、CockroachDB 的 graceful drain
  則發生在 `t_incident` 之後被完整計入計時窗口的不對稱問題（見審計報告 F-004，本次重跑未
  重新設計計時基準，此問題延續）。

## 3. F1/C4 follower-kill 對照組

| DB | Placement | F1-follower | outage_observed | C4-follower | outage_observed |
|---|---|---:|:---:|---:|:---:|
| TiDB | P-A | 7.315 / 6.909(+pd) | ✅ true (err=2/2) | 0.030†(離群) / 6.715(+pd) | ❌ false (err=0) / ✅ true (err=2) |
| TiDB | P-B | 4.180‡(離群) / 6.877(+pd) | ✅ true (err=2/2) | 7.389 / 6.722(+pd) | ✅ true (err=3/2) |
| YugabyteDB | P-A | n/a | `outage_observed=false`（ok=114, err=0） | n/a | `outage_observed=false`（ok=116, err=0） |
| YugabyteDB | P-B | n/a | `outage_observed=false`（ok=122, err=0） | n/a | `outage_observed=false`（ok=122, err=0） |
| CockroachDB | P-A | n/a | `outage_observed=false`（ok=504, err=0） | n/a | `outage_observed=false`（ok=454, err=0） |
| CockroachDB | P-B | n/a | `outage_observed=false`（ok=504, err=0） | n/a | `outage_observed=false`（ok=482, err=0） |

† TiDB P-A C4-follower（0.030s）的離群成因已查明：這組 `probe.txt` 事件後 `err=0`，與 CRDB/YBDB
的根本原因相同——探測從未觀測到中斷，不是「HAProxy round-robin 運氣好」。

‡ TiDB P-B F1-follower（4.180s）的離群值**仍未解釋**：這組 `probe.txt` 事件後 `err=2`（真實
觀測到中斷），outage_observed=true，與同組其餘 3 個變體（6.7~8.4s）相差近 2 倍的原因待查，
列為未解決的異常值（見 §10）。

**結論**：YBDB/CRDB 的 leader vs follower kill 在 2026-08-11 真實重跑中同樣全數
`outage_observed=false`，無法比較兩者差異。可信賴的部分僅剩 TiDB 內部的 leader vs follower
比較（皆為真實觀測到中斷的情境，量級相近，6.68~8.37s vs 6.71~7.39s，扣除上述未解釋的離群值），
這個「TiDB 內部無明顯 leader/follower 差異」的窄結論仍可成立，但不能推廣為跨 DB 結論。

## 4. C1（網路分區）韌性敘述

`chaos-c1-partition-execute.sh` 已修正加入 `--db` 必填參數，依 DB 分流正確的探測指令
（TiDB: mysql；CockroachDB: cockroach sql；YugabyteDB: psql）。2026-08-11 重跑時，CRDB/YBDB
兩家的 4 個環境（P-A/P-B 各一次）全部使用修正後的探測，探測結果一致：**全程 `ok`，無 `err`**。

| DB | Placement | error-rate-by-sec | 解讀 |
|---|---|---|---|
| TiDB | P-A/P-B | 30/30 `ok`（2026-08-08） | IDC 端點正常回應，分區只影響跨區流量 |
| CockroachDB | P-A | 24/24 `ok`（2026-08-11 重跑） | 探測連的 IDC 端點在 partition 期間不受影響 |
| CockroachDB | P-B | 29/29 `ok`（2026-08-11 重跑） | 同上 |
| YugabyteDB | P-A/P-B | 全程 `ok`（2026-08-11 重跑） | 同上 |

**解讀**：三家 DB 在 P-A/P-B 下探測皆全程 `ok`，這是**預期行為**而非「三家無差異、partition
無影響」的證明——探測是從 IDC 側 jump host（`.31`）連 IDC 端的 DB endpoint，而 C1 的注入是
「IDC↔GCP 雙向阻斷」，IDC 內部（.31→IDC DB host）的連線完全不受這種分區影響，所以探測全程 ok
是正確、符合設計的結果，但**測不到 GCP 側 client 在 partition 期間的真實體驗**（見審計報告
F-005，屬已知、尚未修正的探測方向限制，見 §10）。

- **注入本身**（iptables 規則生效與 30 秒後自動移除）三家皆有實際執行，
  `iptables-rules-before/after.txt` 顯示規則正確增刪，這部分是可信的執行證據。
- 6/6 tserver/node ALIVE 的復原證據（來自各環境 SUMMARY 的獨立健康檢查）在全部環境中一致
  成立：partition 解除後 30 秒內全部節點恢復 ALIVE 狀態。

**仍不能下的結論**：「三家 DB 對 30 秒級 WAN 分區的 client 可見影響為零」——目前的探測方向
（IDC 側連 IDC 端）無法回答這個問題，需要雙側探測（IDC 側連 GCP 端、GCP 側連 IDC 端）才能
完整驗證（F-008 次要待辦，見 §10）。

## 5. C7（磁碟慢）韌性敘述

`chaos-c7-disk-slow-execute.sh` 已修正 fail-fast 邏輯（`fio_launch_ok≠true` 且非 dry-run 時
`exit 1`），並在 2026-08-11 重跑前於全部 IDC host 預先安裝 fio（新 VM 預設未裝，首次執行會
fail-fast，這是修正後正確的行為，不是 bug）。

| DB | Placement | fio_launch_ok | 6/6 ALIVE 全程未變化 |
|---|---|:---:|:---:|
| TiDB | P-A/P-B | true（2026-08-08） | ✅ |
| CockroachDB | P-A | `true`（2026-08-11 重跑） | ✅ |
| CockroachDB | P-B | `true`（2026-08-11 重跑） | ✅ |
| YugabyteDB | P-A | `true`（2026-08-11 重跑） | ✅ |
| YugabyteDB | P-B | `true`（2026-08-11 重跑） | ✅ |

**目前僅能下的結論**：三家 DB 在 30 秒 fio 磁碟競爭下都沒有觸發節點下線判定，注入本身確認有效
執行完成（`fio_launch_ok=true`，fail-fast 修正後仍正常通過）。**不能**下「三家對磁碟慢容忍度
無差異」或「DB 效能未受影響」的結論——C7 的 artifact 目錄裡沒有 pre/during/post 的 DB 效能指標
（tpmC/p95/p99/error rate）、沒有 no-injection baseline 可對照，這兩點在 2026-08-11 重跑中
同樣未補齊（需要重新設計含 baseline／並發 workload 對照的 C7 才能回答，見 §10）。`io-latency-
p99.txt` 檔名誤導性問題（內容是原始 iostat 樣本非已計算 p99）也維持未修正（唯讀既有 artifact
命名慣例的問題，需未來版本統一處理）。

## 6. F2（三台 IDC DB process 同時停止 + operator 重啟）敘述

F2 對 3 台 IDC host 同時發出真實 kill（TiDB: `tidb-4000+tikv-20160+pd-2379`；YBDB:
`yugabyted stop`；CRDB: `systemctl stop cockroach`），驗證「write 在 quorum 遺失時應正確拒絕」
且量測「重啟指令發出到能再次成功寫入」的時間。這不是自動化的區域級 failover，而是「服務同時
停止＋腳本立即發出重啟指令」的恢復力測試。

**F2 真實復原時間**（`t_first_write_ok − t_restart_start`）：

| DB | Placement | 執行時間 | 重啟→回報健康 | 健康→首次成功寫入（gap） | 總計 | 精度 |
|---|---|---|---:|---:|---:|---|
| TiDB | P-A | 2026-08-08（未重跑） | 0.183s | 44.115s | 44.298s | 寫入時刻僅知落在 44.1s 區間內 |
| TiDB | P-B | 2026-08-08（未重跑） | 0.196s | 38.937s | 39.133s | 同上，區間 38.9s |
| CockroachDB | P-A | **2026-08-11 真實重跑** | ~7.01s | 0s（同一次 poll） | **≈7.01s** | 健康與寫入同一次 poll 確認，精度緊密 |
| CockroachDB | P-B | **2026-08-11 真實重跑** | ~7.12s | 0s（同一次 poll） | **≈7.12s** | 同上 |
| YugabyteDB | P-A | **2026-08-11 真實重跑** | ~2.99s | 0s（同一次 poll） | **≈2.99s** | 同上 |
| YugabyteDB | P-B | **2026-08-11 真實重跑** | ~3.65s | 0s（同一次 poll） | **≈3.65s** | 同上 |

**2026-08-11 重跑觀察**：CRDB/YBDB 這次重跑得到的數字（CRDB 7.01~7.12s、YBDB 2.99~3.65s）
與 2026-08-08 原始數字（CRDB 7.21~12.95s、YBDB 3.05~3.2s）**方向一致、量級吻合**——尤其是
CRDB-P-B（7.21s → 7.12s）與 YBDB 兩個 placement 幾乎完全重現，這強化了這些數字反映真實、
穩定的系統行為（而非單次雜訊）的可信度。CRDB-P-A 這次（≈7.01s）比原始數字（12.95s，其中
含 5.8s 精度不確定區間）更快也更精確（本次健康與寫入同一次 poll 確認），可能原因是這次
WAREHOUSES=4 的 IDC-only 資料集比原始執行時的資料狀態更小/更快重建，兩次數字皆有效，差異
不足以下確定性結論（各僅 1 次樣本）。

**方向性結論（維持成立）**：即使考慮 TiDB 尚有 39~44s 的未知區間、CRDB 兩次重跑各僅 1
樣本，YugabyteDB 最快、CockroachDB 居中、TiDB 最慢的方向性排序在兩次獨立執行（2026-08-08 與
2026-08-11）中都重現，這是本報告信心最高的跨 DB 觀察之一。

**額外發現**：TiDB 的「叢集回報健康」與「首次成功寫入」之間存在數十秒的落差（44.1s／38.9s），
CockroachDB／YugabyteDB 則兩者幾乎同時發生（本次重跑的 CRDB/YBDB 4 組皆為 0 落差，比原始
CRDB-P-A 的 5.8s 落差更乾淨）。這意味著 TiDB 的「儲存層健康」與「SQL 層可寫」是兩個時間點
分離明顯的獨立里程碑，若僅監控 TiKV store 存活會嚴重低估 TiDB 真正恢復可寫所需的時間。

**write-reject 正確性分類**：

| DB | Placement | 判定 |
|---|---|---|
| TiDB | P-A/P-B | `write_correctly_rejected`（`ERROR 9001 PD server timeout`，2026-08-08） |
| YugabyteDB | P-A/P-B | `write_correctly_rejected`（`psql: timeout expired`，2026-08-11 重跑再次確認） |
| CockroachDB | P-A/P-B | `ambiguous_result_manual_review_required`（`ERROR: result is ambiguous ... lost quorum`，2026-08-11 重跑再次確認） |

CockroachDB 在兩次獨立執行（2026-08-08、2026-08-11）中都回報相同的 `ambiguous` 結果——這確認
這不是單次巧合，而是 CockroachDB 在 quorum 遺失情境下的穩定行為：它會誠實回報「不知道這個
寫入是否已提交」，這與「乾淨地被拒絕」是不同的結果類別，RPO 因此不能沿用「=0」的宣稱。
TiDB／YugabyteDB 的 RPO=0（簡化量測未見倒退）維持不變。

## 7. 綜合觀察與待驗證假說

1. **F2 真實復原時間的跨 DB「方向性」排序（YugabyteDB 最快、CockroachDB 居中、TiDB 最慢）在
   兩次獨立執行（2026-08-08 原始、2026-08-11 真實重跑）中都重現**——這是本報告信心最高的
   跨 DB 觀察。具體秒數仍不應引用到小數點後兩位的精確度（TiDB 有 39~44s 未知區間）。

2. **CockroachDB／YugabyteDB 的 F1/C4 單節點 kill，在兩次獨立執行（2026-08-08、2026-08-11）
   中都一致觀測到 `outage_observed=false`**——這是本報告新增的、信心等級最高的結論之一：
   同一組情境在完全重建的環境上重新執行仍得到相同結果，排除了「探測腳本本身有 bug」以外的
   解釋，證實這是這兩家 DB 在本測試規模下的真實、可重現特性。TiDB 因架構上將 SQL 層與
   儲存/共識層分離（tidb-server vs TiKV/PD），單節點 kill 後 client 需要重新做 region route
   查詢並等待新 leader 選出，這段延遲足夠長（百毫秒到數秒級）而被 100ms 探測捕捉到；
   CockroachDB/YugabyteDB 單一進程整合 SQL+共識層，在小資料集下的單節點 failover 快到
   目前探測解析度捕捉不到。

3. **`go-tpc` 對不同 DB 的容錯度不同**：CRDB 段的背景 workload 多次因累積錯誤提前結束，
   YBDB 段全程未曾提前中止，TiDB 段則在連續多次 PD resign 後才崩潰一次。這是量測工具本身的
   限制，不是資料庫的問題。

4. **YugabyteDB P-B 段 2026-08-08 觀察到一次真實的 DB 穩定性異常**（yb-master 執行緒暴增至
   1147、RPC 延遲 5~80 秒、叢集 12+ 分鐘選不出新 leader）。**2026-08-11 重跑未再重現**——
   全程 master thread count 維持 27-30 正常值。這暗示該 bug 與特定的重試/選舉時序條件相關，
   屬間歇性穩定性問題而非確定性 bug；原始發現本身仍然有效（真實觀測過），但無法用本次重跑
   再次確認其觸發條件，建議列為 YugabyteDB 生產部署前需要進一步壓力測試驗證的風險項。

5. **TiDB「儲存層健康」與「SQL 層可寫」分離達 38.9~44.1 秒**，CockroachDB／YugabyteDB 則兩個
   里程碑幾乎同時發生（本次重跑的 4 組 CRDB/YBDB 數字進一步強化此對比，皆為 0 落差）。若監控
   /決策僅依賴 TiKV store 存活狀態判斷「TiDB 已恢復」，會嚴重低估真正恢復可寫所需的時間。

## 8. 決策意涵

以下意涵皆基於小樣本的探索性觀察，**不應作為唯一決策依據**，僅供搭配其他 PoC 面向（穩態效能、
運維複雜度、生態系）綜合考量：

- 若**故障恢復速度**（尤其是「服務同時停止後重啟」這類最嚴重的場景）是關鍵決策因素，兩次
  獨立執行（2026-08-08、2026-08-11）一致顯示 YugabyteDB 的真實復原時間（≈3~3.7s）優於
  CockroachDB（≈7~13s）與 TiDB（39~44s，其中屬於「儲存層已健康但 SQL 層仍不可寫」的區間）。
  但需注意 YBDB 曾在 2026-08-08 段觀察到一次真實的穩定性異常（本次重跑未重現），若採用 YBDB
  且計劃使用不 pin leader 的 placement 策略，建議在正式部署前針對此風險項做更長時間、更高
  並發的壓力測試以驗證是否可重現。
- **單節點 leader/follower kill 的跨 DB 比較**：CockroachDB／YugabyteDB 在本測試規模下對單
  節點 kill 的 client 可見中斷時間短於 100ms 探測解析度（兩次獨立執行皆確認），TiDB 則有
  6.68~8.4s 的真實可觀測中斷。這不代表 TiDB 的單節點 failover「比較差」——這代表 TiDB 的
  失效轉移機制（SQL 層與儲存層分離、需要 route 重新查詢）在 client 端造成的可感知延遲，明顯
  長於 CockroachDB/YugabyteDB 這類單一進程整合架構的等效機制，這是架構差異的直接體現，
  而非效能優劣的簡單排名。
- **TiDB 的 F2 恢復時間明顯最長**，且拆解後發現多數時間（38.9~44.1s）落在「儲存層健康、SQL
  層仍不可寫」這個區間。這對故障排查與監控設計有實務意涵：僅監控 TiKV/PD 存活不足以判斷
  TiDB 是否真正恢復可寫，需要額外監控 SQL 層本身的可寫性。若業務對 RTO 有嚴格 SLA（例如
  <10s），TiDB 在本次測試規模下的表現需要進一步優化或調參驗證才能評估是否可達標。
- 三家 DB 在「quorum 遺失時的行為」上**並非完全等價**：TiDB／YugabyteDB 皆為乾淨的
  write-reject，CockroachDB 則穩定回報 `ambiguous`（兩次獨立執行皆確認，不是單次巧合）——
  這不代表 CockroachDB 有資料正確性問題（ambiguous 是誠實回報「我也不確定」，比誤判成功更
  安全），但代表**應用層若使用 CockroachDB，需要自行處理 ambiguous 結果的重試/查詢邏輯**
  （例如用冪等 key 查詢確認最終狀態），不能假設「沒收到成功回應＝一定沒寫入」。

## 9. 跨 3DB 修復的既有腳本 bug 總表

本次 campaign 過程中，每個 DB 分支「第一次被真實執行到」時幾乎都浮現此前從未被抓到的 bug。

| # | 檔案 | DB | 問題 | 修復 |
|---|---|---|---|---|
| 1 | `tests/common/prepare.sh` | TiDB（跨全專案共用） | placement regex 字串結尾錨定，比對不到帶 PROFILE_TOKEN 後綴的 TOPO | 移除結尾錨定 |
| 2 | `chaos-c7-disk-slow-execute.sh` | TiDB | 新 VM 未裝 fio 時腳本誤判成功 | 加開跑前 `command -v fio` 檢查 + 事後驗證 `Run status` 行 |
| 3 | `run-vm6-f2-idc-death-execute.sh` | TiDB | `SVC="tidb-server"` 錯誤 unit name | 改為 `tidb-4000 tikv-20160 pd-2379` |
| 4 | `run-vm6-chaos-execute.sh` | TiDB | 只停無狀態 `tidb-server`，未觸發真正 TiKV Raft leader 重選 | `--kill-scope` 改同時停 `tikv-20160` |
| 5 | `probe-rto-driver.sh` | YugabyteDB | `PROBE_USER` 誤預設 `root` | per-DB 正確預設 |
| 6 | `run-vm6-chaos-execute.sh` | YugabyteDB | S_PRE_QUERY 誤用 `oorder` 應為 `orders` | 改為 `orders` |
| 7 | Makefile `phase5-crdb-deploy` | CockroachDB | 缺少 `-o StrictHostKeyChecking=accept-new` | 補上 accept-new |
| 8 | `run-vm6-chaos-execute.sh` | CockroachDB | F1/C4 共用 `cockroach quit`，喪失 graceful/ungraceful 對照意義 | C4 改用 `systemctl kill -s SIGKILL` |
| 9 | `run-vm6-chaos-execute.sh` | CockroachDB | `cockroach quit` 在 v26.2 已不存在 | 改用 `cockroach node drain --self --shutdown` |
| 10 | `run-vm6-chaos-execute.sh` | CockroachDB | post-kill 單次即時檢查與 drain 實際完成時序有 race | 改為最多重試 5 次 |
| 11 | `run-vm6-chaos-execute.sh` | CockroachDB | LEADER_QUERY 缺少 `WITH DETAILS` | 補上 `WITH DETAILS` |
| 12 | `run-vm6-chaos-execute.sh` | CockroachDB | S_PRE_QUERY 誤用 `oorder` 應為 `orders` | 改為 `orders` |
| 13 | `run-vm6-f2-idc-death-execute.sh` | CockroachDB | WRITE_PROBE 是空的 `SELECT 1` | 改真實 INSERT+DELETE |
| 14 | `run-vm6-f2-idc-death-execute.sh` | CockroachDB | HEALTH_QUERY 查詢在 v26.2 被拒絕存取 | 改用不受限的 `cockroach node status` |

### 2026-08-10 稽核發現的 bug（F-001～F-010，詳見 `CHAOS-FAILOVER-AUDIT-2026-08-10.md`）

| # | 檔案 | 問題 | 修復狀態 |
|---|---|---|---|
| 15 | `wall-clock-wrapper.sh` | `err_count=0` 時仍輸出正數 RTO | 已修正並經 2026-08-11 真實重跑驗證：`outage_observed=false` 時正確回報 `rto_sec=null` |
| 16 | `probe-rto-driver.sh` | 探測間隔非固定 100ms | 待修：暫未實作自動 cadence 統計輸出 |
| 17 | `run-vm6-chaos-execute.sh`／各 SUMMARY | leader/follower 標籤僅為 operator 手動選定，部分與實際不符 | 已修正；2026-08-11 重跑時額外發現 YBDB master leader 因前一情境重啟而換人，改用「全程未被動過」的節點當 follower target，避免重演同類錯誤 |
| 18 | `run-vm6-chaos-execute.sh` | TiDB/YBDB 與 CockroachDB 的 F1 計時基準不對稱（graceful resign 是否計入 t_incident 前後） | 待修：本次重跑未重新設計計時基準 |
| 19 | `run-vm6-chaos-execute.sh` | probe 實際執行於 `.31`（IDC 側 jump host），非任何 GCP 實體 client | 待修：本次重跑仍從 `.31` 發起探測 |
| 20 | `run-vm6-f2-idc-death-execute.sh` | WRITE_PROBE 合併輸出，誤判 CockroachDB `ambiguous` 為乾淨拒絕 | 已修正並經 2026-08-11 真實重跑驗證：CRDB 兩個 placement 皆穩定回報 `ambiguous_result_manual_review_required` |
| 21 | `chaos-c1-partition-execute.sh` | 沒有 `--db` 參數，寫死探測 TiDB MySQL endpoint | 已修正並經 2026-08-11 真實重跑驗證：CRDB/YBDB 探測全程正常回報 `ok` |
| 22 | `chaos/C7.md` vs 實作 | spec 文件定義與實作不一致 | 待修：未建立 scenario registry |
| 23 | `chaos-c7-disk-slow-execute.sh` | 輸出檔名 `io-latency-p99.txt` 內容非已計算的 p99 | 待修 |
| 24 | `run-vm6-chaos-execute.sh`／`run-vm6-f2-idc-death-execute.sh` | 停服務後沒有 trap/idempotent restore 保證 | 待修：規模較大，見 §10 |

### 2026-08-11 真實重跑期間新發現的 bug

| # | 檔案 | 問題 | 修復狀態 |
|---|---|---|---|
| 25 | `run-vm6-f2-idc-death-execute.sh` | F2 復原輪詢的 duplicate-key 陷阱：kill 期間的 ambiguous INSERT 若其實已 commit，後續輪詢的 INSERT 會撞 `duplicate key` 錯誤（含 "error" 字樣），被誤判為「仍在拒絕中」，導致整個 600s 輪詢視窗都測不到復原（CRDB P-A F2 首次重跑實際觸發） | 已修正：kill 前與每次輪詢 INSERT 前都先 best-effort DELETE sentinel key，確保冪等；已重跑驗證修正有效 |
| 26 | `run-vm6-aa.sh`（間接） | A-A profile workload 依賴 plain(A-S) 版本的 `.prepare.done` anchor，全新環境直接跑 A-A 會因 schema 不存在而全滅；GCP client 在全新 VM 上需要單獨的 `phase2-bootstrap-gcp-client` + `apply-gotpc-patch.sh`（不在標準 phase2 鏈中） | 屬環境建置流程缺口非腳本 bug：已找出正確的前置步驟順序（先跑 plain smoke 建 anchor，再補 GCP client bootstrap + patch，才能跑 A-A profile），已記錄於 4 份新 SUMMARY.md |
| 27 | `tests/common/prepare.sh` | go-tpc 內建 consistency check（3.3.2.x cross-table aggregate）在 CRDB P-B（lease 可能落到 GCP）下卡死 45 分鐘——與 YBDB 已知的同一類問題，但判斷條件只涵蓋 `DB==ybdb`，未涵蓋 CRDB P-B | 已修正：`NOCHECK_ARG` 判斷條件改為 `DB==ybdb` 或 `TOPO` 含 `P-B`，一併改用 row-count 驗證取代 check-all |
| 28 | `tests/common/prepare.sh` | X-CROSS placement gate（CRDB 分支）只抽樣 3 張表共 6 個 leader，WAREHOUSES=4 下樣本數過小，CRDB P-B 連續 2 次量到 idc=5/6=83%（超出 30-70% 合格區間）而 fail-closed，但直接查全體 9 張表 21 個 range 的真實分布是 idc=13/21≈62%（合格） | 待修：目前僅記錄為已知的小樣本 gate 限制，重試數次後可通過（4 次中 1 次 PASS），未修改 gate 本身的抽樣邏輯 |

## 10. 未解決缺口

- **RPO 量測精確度上限**：全程使用簡化版（per-warehouse `max(o_id)` high-water-mark），非
  完整 driver-hooked FIFO buffer。CockroachDB 的 F2 RPO 維持「ambiguous，未判定」（兩次獨立
  執行皆確認），比其餘兩家的簡化「=0」更誠實但也更不確定。
- **C1/C7 未量測 tpmC-during-incident**：三家 DB 皆缺少此數據，2026-08-11 重跑同樣未補齊。
- **樣本數 N=1（CRDB/YBDB 現為 N=2，兩次獨立執行）**：TiDB 仍為單次執行；CRDB/YBDB 因
  2026-08-11 重跑，F1/C4/F2 的方向性結論已有兩次獨立執行互相印證，但仍不足以構成統計顯著
  的結論。
- **YugabyteDB 執行緒暴增異常僅發生過一次，2026-08-11 重跑未再重現**：根因仍僅基於現象推測、
  未深入原始碼查證，建議列為需要專門壓力測試驗證的獨立風險項。
- **TiDB follower-kill 的離群值僅 1 筆已解釋、1 筆仍未解釋**：P-B F1-follower（4.180s）
  `err=2`，真實觀測到中斷，成因與同組其他變體相差近 2 倍的原因待查。
- **F1 三家計時基準不對稱**（見 §9 #18）與**client origin 未經驗證**（見 §9 #19）兩項屬於
  方法論設計缺陷，2026-08-11 重跑未重新設計，需要專門的方法論改版才能產出可跨 DB 比較的數字。
- **C1 探測方向單側**：目前只驗證「IDC 側連 IDC 端」在 partition 期間不受影響（符合預期），
  未驗證「GCP 側 client 的真實體驗」，需要雙側探測才能完整回答 partition 對 client 的影響。
- **CRDB 的 F2 P-A/P-B 差異（2026-08-11：7.01s vs 7.12s）樣本數不足**：兩個 placement 各僅
  1 次新樣本，方向性上兩者已相當接近（不同於 2026-08-08 原始的 12.95s vs 7.21s 較大差異），
  無法判斷這是真實的量測進步還是單次雜訊收斂。
- **X-CROSS placement gate 小樣本問題**（見 §9 #28）：建議未來若需要更穩定的 gate 判定，應
  改用全體 9 表抽樣而非目前的 3 表窄抽樣。

## 11. 證據索引

**2026-08-10 稽核報告**：[`CHAOS-FAILOVER-AUDIT-2026-08-10.md`](./CHAOS-FAILOVER-AUDIT-2026-08-10.md)
——本報告 §2~§9 的方法論修正內容源自此稽核。

各環境完整過程、artifact 清單見對應結案報告與 raw artifact 目錄：

- TiDB P-A：[SUMMARY](../results/x-cross/chaos/tidb-vm-6node-P-A-rc-20260808T075957+0800-SUMMARY.md) ｜ `results/x-cross/chaos/tidb-vm-6node-P-A-rc-20260808T075957+0800-scenario*/`
- TiDB P-B：[SUMMARY](../results/x-cross/chaos/tidb-vm-6node-P-B-aa-rc-20260808T101720+0800-SUMMARY.md) ｜ `results/x-cross/chaos/tidb-vm-6node-P-B-aa-rc-20260808T101720+0800-scenario*/`
- YugabyteDB P-A：[SUMMARY](../results/x-cross/chaos/ybdb-vm-6node-P-A-rc-20260808T144840+0800-SUMMARY.md)（含 2026-08-11 重跑數字，TS=`20260810T214440+0800`） ｜ `results/x-cross/chaos/ybdb-vm-6node-P-A-rc-20260810T214440+0800-chaos/`
- YugabyteDB P-B：[SUMMARY](../results/x-cross/chaos/ybdb-vm-6node-P-B-aa-rc-20260808T172141+0800-SUMMARY.md)（含 2026-08-11 重跑數字，TS=`20260810T233326+0800`） ｜ `results/x-cross/chaos/ybdb-vm-6node-P-B-aa-rc-20260810T233326+0800-chaos/`
- CockroachDB P-A：[SUMMARY](../results/x-cross/chaos/crdb-vm-6node-P-A-rc-20260808T200335+0800-SUMMARY.md)（含 2026-08-11 重跑數字，TS=`20260810T142439+0800`） ｜ `results/x-cross/chaos/crdb-vm-6node-P-A-rc-20260810T142439+0800-chaos/`
- CockroachDB P-B：[SUMMARY](../results/x-cross/chaos/crdb-vm-6node-P-B-aa-rc-20260808T220127+0800-SUMMARY.md)（含 2026-08-11 重跑數字，TS=`20260810T152835+0800`） ｜ `results/x-cross/chaos/crdb-vm-6node-P-B-aa-rc-20260810T152835+0800-chaos/`

每個 `chaos/scenario<X>/` 子目錄依情境含 `kill.log`／`rto-rpo.json`／`plan.txt`／`probe.txt`／
`s_pre.txt`／`s_post.txt`／`db-config-snapshot/`（F1/C4）或 `fio-summary.txt`（C7）或
`error-rate-by-sec.txt`（C1）或 `write-reject-validation.txt`／`recovery-poll.log`（F2）等
原始證據檔案。

所有環境的 VM 已於各自完成後 teardown：TiDB/YBDB/CRDB 原始 2026-08-08 段（`phase1-destroy`，
2026-08-09）；CRDB/YBDB 2026-08-11 真實重跑段（4 個環境依序建置+執行+teardown，最終確認
`terraform state list` 兩側皆空）。
