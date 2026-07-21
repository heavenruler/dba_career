# X-CROSS A-A-RO 結案報告（雛形）— IDC↔GCP Cross-Region 3-DB W=128 A-A-RO 正式測試

> 狀態：**雛形（draft）**。所有數字取自實際執行的 W=128 採樣，無任何模擬/示範資料。
> 產出日：2026-07-21。範圍：A-A-RO（IDC 讀寫＋GCP read-only）profile，
> P-A placement，三家（TiDB／CockroachDB／YugabyteDB）。
>
> **⚠ 證據可及性注意**：本批原始 artifact（`results/x-cross/baseline/w128/20260720T101928+0800/`，
> 121M）依 2026-07-21 拍板暫不進 repo（`.gitignore` 排除，避免肥大）。本報告連結指向
> 該本地路徑，**在未持有此份本地 artifact 的環境（如重新 clone 的 repo）連結會失效**；
> 若後續決議留存，移除 `.gitignore` 該行即可正常 commit、連結即恢復可解析。
>
> 本文標籤同 [XCROSS-CLOSING-REPORT-DRAFT.md](XCROSS-CLOSING-REPORT-DRAFT.md)：`實測事實`／
> `觀察`／`機制推論`／`根因未確認`／`採用決策`／`後續驗證`。

## 1. 執行摘要

1. `採用決策`：正式採用三個 cell——**TiDB／CRDB／YBDB 的 A-A-RO W=128 全輪**（同批
   `TPCC_TS=20260720T101928+0800`，單一 detached driver `win-aaro-w128.sh` 依序
   TiDB→YBDB→CRDB；定義見 §3）。
2. `實測事實`：**三家 IDC 側與 GCP 側全程 0 錯誤**（IDC 逐檔位 `_ERR` 計數與 GCP
   `execute run failed` 計數雙口徑皆為 0；總交易數 TiDB 2,955,895／YBDB 2,124,346／
   CRDB 2,338,604）。
3. `實測事實`：t128 IDC 主水位 tpmC——TiDB **15,182.5**、YBDB **12,882.5**、CRDB
   **11,331.1**；GCP 側 read_tpmTotal——TiDB **31,571.3**、YBDB **56,787.9**、CRDB
   **41,056.3**（§5）。
4. `採用決策`：X-CROSS 於 phase registry 為 `baseline_eligible=false`——本報告數字供
   cross-region A-A-RO 能力與相對量級判讀，不作正式跨家排名（同 §2、§8 O5 慣例）。
5. `後續驗證`：本輪為 A-A-RO 首次真實 W=128 全輪（此前僅 W=4 t16 smoke，見
   [SMOKE-AARO-SUMMARY.md](SMOKE-AARO-SUMMARY.md)）；過程中發現並修復一個新根因
   （`merge-gcp-stdout.sh` stdin 陷阱，§7），修復後 YBDB/CRDB 兩家全程零人工介入
   （TiDB 因觸發此 bug 而人工補救一次，非重跑）。
6. `實測事實`（07-21 補查，§5.5）：**GCP 就近讀本輪（07-20 批）確實未生效**——
   三家各有一個實際阻擋點（TiDB zone 標籤不完全相同、CRDB 缺 session 層開關、
   YBDB 交易未標記 read-only），已逐一定位並修復，用各 DB 決定性方法（CRDB
   `EXPLAIN ANALYZE`、YBDB 執行時間對照、TiDB 大規模流量測試）驗證生效。
   **僅在 smoke 規模驗證，尚未重跑完整 W=128 批次**；本報告 §1-§6 的採用數字
   仍是修法前的 07-20 批，`read_tpmTotal` 吞吐數字本身不受影響。

## 2. 測試目的與範圍

驗證 TiDB / CockroachDB / YugabyteDB 三家分散式 SQL 在 6-node cross-region
（3 IDC + 3 GCP）拓樸、P-A placement 下，**A-A-RO profile**（IDC 端標準 TPCC
讀寫＋GCP 端同時對副本打 read-only workload）的正式 W=128 吞吐與延遲，作為
X-CROSS 階段 A-A-RO 分項的結案數據。

不在本報告範圍：P-B placement、A-A（雙端 RW）profile、failover 演練、跨家
正式排名。P-A×A-S 的結案數據見 [XCROSS-CLOSING-REPORT-DRAFT.md](XCROSS-CLOSING-REPORT-DRAFT.md)。

## 3. 採用 Suite

| 縮寫 | 狀態 | Suite 目錄（本地，見頂部證據可及性注意） |
|---|---|---|
| **TiDB A-A-RO** | ✅ 採用 | `results/x-cross/baseline/w128/20260720T101928+0800/tidb-vm-6node-P-A-aaro-rc-20260720T101928+0800/` |
| **YBDB A-A-RO** | ✅ 採用 | `results/x-cross/baseline/w128/20260720T101928+0800/ybdb-vm-6node-P-A-aaro-rc-20260720T101928+0800/` |
| **CRDB A-A-RO** | ✅ 採用 | `results/x-cross/baseline/w128/20260720T101928+0800/crdb-vm-6node-P-A-aaro-rc-20260720T101928+0800/` |
| TiDB／YBDB／CRDB plain anchor | 備查（prepare-bridge 來源，非正式數據） | 同批 `*-vm-6node-P-A-rc-20260720T101928+0800/`（`ANCHOR_ONLY=1`：僅 prepare+gate，無 workload，§7） |

三家均通過 `check-aaro-artifacts.py`（fail-closed）：`gcp_side` 頂層區塊存在、
`tpmC_mean=null`（G2，RO mix 無 NEW_ORDER）、`read_tpmTotal_mean` 四檔位齊全、
雙側每輪 raw stdout 含 `[Summary]`/`tpmC` 結算行。placement gate 三家皆 idc
majority PASS。

## 4. 測試環境與共同口徑

### 4.1 環境

| 項目 | 值 |
|---|---|
| 拓樸 | 6 DB node = 3 IDC（172.24.40.32-34）+ 3 GCP（10.160.152.11-13）；IDC client = .31；GCP client = .15（g-test-poc-5） |
| Placement | P-A（leader/lease pin IDC） |
| VM 潔淨度 | 全新 `phase1+phase2` 重建，三家依序共用同一批 VM（軟體逐家部署/拆除，非重建 VM，見 §7） |

### 4.2 量測口徑

| 參數 | 值 |
|---|---|
| Workload | go-tpc TPC-C；IDC 端 standard mix；GCP 端 read-only mix（ORDER_STATUS/STOCK_LEVEL 各 50%） |
| WAREHOUSES | 128 |
| Threads 檔位 | 16 / 32 / 64 / 128 |
| Rounds | 每檔 5 輪 × 300s；Warmup 1200s |
| GCP 主指標 | `read_tpmTotal`（G2：非 tpmC，唯讀 mix 下 tpmC 無定義） |
| 雙端合併規則 | G1-G6（[decisions-2026-06-08.md](decisions-2026-06-08.md) 2026-07-15 附錄）：兩地永不合併，GCP 自成 `gcp_side` 頂層區塊 |
| 執行入口 | [`make win-aaro-detach`](Makefile)（driver：[win-aaro-w128.sh](scripts/win-aaro-w128.sh)），TiDB→YBDB→CRDB |

## 5. 主結果

口徑：tpmC/read_tpmTotal 為 R1-R5 mean；range% = (max−min)/mean（非統計 CV，
見 [XCROSS-CLOSING-REPORT-DRAFT.md §5](XCROSS-CLOSING-REPORT-DRAFT.md) 口徑說明）。

### 5.1 IDC 側吞吐（標準 TPCC mix）

| threads | TiDB tpmC (range%) | YBDB tpmC (range%) | CRDB tpmC (range%) |
|---:|---:|---:|---:|
| 16 | 9,439.1 (16.1%) | 6,002.6 (18.6%) | 9,347.7 (13.8%) |
| 32 | 12,833.2 (23.5%) | 7,276.9 (17.8%) | 9,906.0 (18.9%) |
| 64 | 15,702.7 (7.3%) | 12,247.1 (2.6%) | 11,501.7 (8.8%) |
| **128（主水位）** | **15,182.5 (23.6%)** | **12,882.5 (3.1%)** | **11,331.1 (4.0%)** |

`觀察`：TiDB t64→t128 微降（15,702.7→15,182.5）且 t128 range% 偏高（23.6%）；
YBDB/CRDB 皆單調遞增、t128 range% 收斂良好（3.1%/4.0%）。三家全檔位、全輪
**0 錯誤**（IDC `_ERR` 計數與 GCP `execute run failed` 計數雙口徑核實，§1.2）。

### 5.2 GCP 側吞吐（read-only mix）

| threads | TiDB read_tpmTotal | YBDB read_tpmTotal | CRDB read_tpmTotal |
|---:|---:|---:|---:|
| 16 | 8,151.6 | 19,883.7 | 8,831.6 |
| 32 | 14,518.1 | 36,802.0 | 19,320.5 |
| 64 | 26,475.5 | 50,640.1 | 42,095.6 |
| **128** | **31,571.3** | **56,787.9** | **41,056.3** |

`觀察`：三家 GCP 側 read_tpmTotal 皆隨 threads 單調遞增、未見平頂（128 檔位
仍在成長），與 IDC 側同檔位相比：YBDB GCP 吞吐（56,787.9）遠高於其 IDC 側
（12,882.5，約 4.4×）；TiDB／CRDB 的 GCP／IDC 比值分別約 2.1×／3.6×。
`機制推論`：唯讀 mix（僅 ORDER_STATUS/STOCK_LEVEL，無寫入/鎖競爭）本質上
比標準 TPCC mix 輕量，GCP 側單筆延遲更短、同硬體可撐更高吞吐；未以逐筆延遲
分解證實。**GCP 與 IDC 兩側數值不可直接比較大小（G2）**——不同 workload、
不同副本角色，此處僅供觀察兩側量級差異，非效能對比。

### 5.3 結果判讀

| 資料庫 | IDC t128 | GCP t128 read_tpmTotal | 錯誤 | 可引用結論 |
|---|---|---:|---|---|
| TiDB | 15,182.5 tpmC | 31,571.3 | 0 / 2,955,895 | 首次 A-A-RO W=128 全輪，執行鏈驗證成功（近讀狀態見 §5.5，本批未修法） |
| YBDB | 12,882.5 tpmC | 56,787.9 | 0 / 2,124,346 | 同上；range% 收斂最佳（3.1%） |
| CRDB | 11,331.1 tpmC | 41,056.3 | 0 / 2,338,604 | 同上；range% 收斂良好（4.0%） |

### 5.4 GCP 就近讀「執行面」證據（2026-07-21 補查）

`實測事實`（設定面）：三家近讀設定確實下達——TiDB
`tidb_replica_read=closest-replicas`（但 `tidb_enable_tso_follower_proxy=OFF`）、
CRDB `kv.closed_timestamp.follower_reads.enabled=t`、YBDB
`yb_read_from_followers=on`（`staleness_ms=30000`）。三家的 `gcp-replica-gate`
亦確認 GCP 節點持有 tpcc 資料副本（§3）。**但設定套用不等於讀取執行時真的
只在本地服務**（同本報告 §7、[XCROSS-CLOSING-REPORT-DRAFT.md](XCROSS-CLOSING-REPORT-DRAFT.md)
§8 C1 同款教訓）——本節嘗試以「執行面」證據驗證，結果**三家不一致，且多數
不支持「已證實就近讀」**。

**證據 1（延遲對照，`觀察`，證據力弱）**：t16 round-1 同交易型別（ORDER_STATUS/
STOCK_LEVEL）比較 GCP 側 vs IDC 側 p50：TiDB 125.8ms vs 17.8ms（7.1×）、
YBDB 60.8ms vs 11.5ms（5.3×）、CRDB 88.1ms vs 10.5ms（8.4×）——GCP 側均
明顯偏高，方向與「本地服務應更快」的預期相反。`根因未確認`：候選解釋包含
(a) TiDB TSO 仍需回打 IDC PD（`tso_follower_proxy=OFF`）、(b) GCP 側唯讀
mix 把 100% thread 集中在這兩種型別（IDC 標準 mix 每種僅 ~4% 權重），
併發競爭型態不同、非路由造成。此項證據力弱，**不單獨採信**。

**證據 2（GCP DB 節點跨區網路流量趨勢，`實測事實`＋`機制推論`，證據力較強）**：
以 GCP client 實際連線節點（10.160.152.11）逐檔位 netflow pre/post-run
delta 計算「對 IDC 流量／對 GCP 流量」比值：

| threads | TiDB | YBDB | CRDB |
|---:|---:|---:|---:|
| 16 | 53.0% | 151.0% | 11.4% |
| 32 | 63.1% | 154.8% | 9.2% |
| 64 | 75.0% | 48.4%\* | 8.7%\* |
| 128 | 94.8% | 47.5%\* | 20.1%\* |

\* YBDB／CRDB t64/t128 的絕對位元組數（159-165MB／422MB）遠低於 t16/t32
（775-2,063MB），量級不連續，`機制推論`：可能是量測時間窗（netflow pre/post
snapshot）與該輪實際起訖對不齊的採樣偽影，非真實流量驟降；此兩格**數字本身
可信度存疑**，不用於下方判讀。

`機制推論`（採信 t16/t32，趨勢方向）：
- **TiDB**：比值隨 threads 遞增（53%→63%），對 IDC 流量成長速度快於對 GCP
  流量——方向**不支持**「讀隨併發增加更多走本地」，較符合「部分讀持續依賴
  IDC（可能與 TSO 往返或未完全生效的 closest-read 有關）」。
- **YBDB**：比值恆高於 100%（對 IDC 流量反而**大於**對 GCP 流量）——**明確
  不支持**本地服務為主；候選解釋包含 YBDB 的 transaction status tablet
  跨區協調成本（§6.3 同款機制，[XCROSS-CLOSING-REPORT-DRAFT.md](XCROSS-CLOSING-REPORT-DRAFT.md)）
  疊加在唯讀查詢路徑上，未證實。
- **CRDB**：比值最低（9-11%）且相對三家最穩定——三家中**唯一方向上與「多數
  流量留在 GCP 本地」一致**的資料庫，但仍不足以排除背景複寫流量的混淆（見下）。

**核心限制（`根因未確認`，適用於證據 2 全部）**：A-A-RO 下 IDC 端同時在寫、
GCP 端同時在讀，netflow 的「對 IDC 流量」**無法區分**是（a）讀請求被轉發回
IDC，還是（b）IDC 寫入正常複寫到 GCP replica 的背景流量（不論讀有沒有走
本地都會發生）——現有探測工具無法拆解這兩種來源。**因此無法將任何一家判定
為「就近讀已證實生效」**，CRDB 的低比值僅是三家中方向較一致，非確認。

**結論（07-21 §5.5 起已更新——見下）**：本節（§5.4）記載的是 07-20 批**修法前**
的查核結果，當時證據不足以支持「已驗證」。§5.5 記載 07-21 找到並修復三家的
實際根因並重新驗證——**三家機制根因判斷正確、修法方向正確，但三家的執行面
證據強度不同（CRDB 近乎決定性；TiDB／YBDB 為強支持證據，非決定性）**，且
07-22 獨立審查（codex，見 §5.6）指出 `check-nearread.sh` 尚未真正
fail-closed、部分措辭過度宣稱。僅在 smoke 規模（W=4/單筆查詢）驗證，
**尚未在完整 W=128 批次重跑確認**，本報告 §1-§6 的 W=128 數字仍是 07-20 批
（修法前）的結果——這些原始量測值本身未被竄改或失真，但**不代表修法後
（intended near-read 生效）配置下的真實效能**，不可用來回答「近讀生效後
吞吐/延遲/IDC 負載會是多少」。

### 5.5 根因定位與修復（2026-07-21，07-22 依 codex 審查修正信心等級）

`實測事實`：深入排查後找到三家個別的實際阻擋點，機制診斷經 codex 獨立審查
確認與官方文件一致，逐一修復並用各家最適合的方法重新驗證：

| DB | 根因 | 修法 | 證據與信心等級 |
|---|---|---|---|
| TiDB | `tidb_replica_read=closest-replicas` 要求 zone 標籤**完全相同**才判定「近」（[PingCAP docs](https://docs.pingcap.com/tidb/stable/three-dc-local-read/)）；GCP 三台原本各自不同 zone（-a/-b/-c），只有落在 zone=a 的節點算近 | GCP 三台統一為單一 zone `gcp-asia-east1`（[ansible/playbooks/tidb-vm6.yml](../ansible/playbooks/tidb-vm6.yml)） | `強支持證據，非決定性`：500 筆讀取的 netflow byte delta，GCP 入口節點對 IDC 流量佔比 **5.7%**（79.9MB→GCP vs 4.6MB→IDC）。**修前值未實測**（僅推定與強制 leader 相同），故嚴格而言不構成同方法 before/after 對照；亦未排除 cache 命中、查詢集中於本地 replica、背景 raft/PD/TSO 流量等混淆 |
| CRDB | `kv.closed_timestamp.follower_reads.enabled=t` 只開「能力」，plain SELECT（無 `AS OF SYSTEM TIME`）不會自動用（[CockroachDB docs](https://www.cockroachlabs.com/docs/stable/follower-reads)） | GCP 側連線加 session 層 `default_transaction_use_follower_reads=on`（[run-vm6-aa.sh](scripts/run-vm6-aa.sh) `GCP_CONN_PARAMS`，僅 GCP 側，IDC 寫入路徑不受影響） | `近乎決定性`（對受測查詢本身）：`EXPLAIN ANALYZE` 8/8 一致顯示 `used follower read`＋`regions: gcp`＋`sql nodes`/`kv nodes` 皆為 GCP 節點（n4）、KV time 600-960µs。**範圍限制**：僅測 `SELECT ... FROM stock LIMIT 1` 單一查詢型態，未涵蓋完整 ORDER_STATUS/STOCK_LEVEL 交易；不排除 closed-timestamp 傳播、catalog/system range 存取等背景跨區流量 |
| YBDB | `yb_read_from_followers=on` 只在交易本身 **read-only** 才生效（[YugabyteDB docs](https://docs.yugabyte.com/preview/develop/build-global-apps/follower-reads/)），go-tpc plain SELECT 預設走一般交易模式 | GCP 側連線加 `default_transaction_read_only=on`（同上，僅 GCP 側；不改變預期唯讀 workload 語義，若程式意外發出寫入會直接失敗——本身也是有益的 fail-closed 行為） | `強支持證據，非決定性`：`EXPLAIN (ANALYZE, DIST)` 對照，follower-read 穩態 ~2.5ms vs 強制 leader-read ~9-13ms（量級吻合 WAN RTT ~8.4ms）。未排除 cache/warmup 順序偏差、tablet 差異、單次樣本抖動；本腳本 docstring 已自陳「非決定性但為次佳證據」 |

**TiDB 修法的額外代價（codex 審查發現，未在 07-21 初版揭露）**：PD 用
`replication.location-labels: ["region", "zone"]` 排程副本、辨識故障域
（[ansible/playbooks/tidb-vm6.yml](../ansible/playbooks/tidb-vm6.yml) 可見）。
把 GCP 三個實體 AZ（asia-east1-a/b/c）壓成同一邏輯 zone 後，**PD 不再能用
zone 區分 GCP 內部故障域**——目前 P-A、RF=3、每 region 通常僅 1 份 GCP
replica，此代價有限；但（a）未來若提高 GCP replica 數，GCP 內跨 AZ 隔離
能力會下降；（b）P-B 或其他依賴 zone diversity 的 placement 需重新驗證
gate。**不可宣稱此修法「無副作用」**，正確定性為「用 routing 需求換
failure-domain 標籤精度的工程取捨」。

**方法論修正**：07-20 批（§5.4）用「延遲對照」與「netflow 流量比值」推論就近讀
是否生效，兩者證據力皆弱——延遲對照被 TiDB 的 TSO 往返（`tso_follower_proxy=OFF`）
與併發競爭型態混淆；netflow 比值在小資料量（W=4）下被叢集背景流量（raft
heartbeat/gossip/rangefeed）淹沒，即使放大 10 倍 burst 比值仍不變也可能只是
訊噪比問題（CRDB 即為此例：EXPLAIN ANALYZE 近乎決定性證實生效，但同批
netflow 比值仍達 74-85%）。07-21 改用各 DB 較強的執行面證據並落成腳本
[check-nearread.sh](scripts/check-nearread.sh)，但該腳本本身尚未真正
fail-closed（見 §5.6），**不可宣稱三家已用「決定性方法」全數確認**——
CRDB 證據力最強，TiDB／YBDB 為強支持證據。

`後續驗證`：三家修法僅在 W=4/單筆查詢規模驗證，**尚未重跑完整 W=128 A-A-RO
批次確認修法後的正式吞吐數字**（本報告 §1-§6 的採用數字仍是修法前的 07-20
批）。是否重跑、以及重跑後是否要更新 §1-§6 的採用數字，待下一輪拍板；補做
項目清單見 §5.6 D 與 §8。

### 5.6 獨立審查（codex，2026-07-22）

`後續驗證`：用 `codex exec --sandbox read-only` 對本節（§5.4/§5.5）與相關
檔案（`ansible/playbooks/tidb-vm6.yml`、`run-vm6-aa.sh`、
`check-nearread.sh`）做無背景脈絡的獨立審查，總評 **PASS WITH CAVEATS**。
核心發現已併入上方表格與段落；額外指出並經 parent 逐一驗證屬實的問題：

- **`check-nearread.sh` 未真正 fail-closed**：TiDB 分支算出 GCP TiKV store
  的 zone 集合（`STORE_ZONES`）後**從未拿去跟 `OWN_ZONE` 比對**，實際只驗
  「zone label 存在」，不驗「近讀條件是否成立」；CRDB 分支 region 非 gcp
  時只印 `WARN`、**不 `exit 1`**，也未驗 `sql nodes`/`kv nodes` 是否皆為
  GCP；YBDB 僅單次取樣、`<70%` 門檻易受抖動影響。**三項已於 07-22 修正**
  （見 commit，腳本內註解同步更新）。
- 建議的後續補做（依優先序）：(1) 用真實 ORDER_STATUS/STOCK_LEVEL 完整交易
  取代 `LIMIT 1` 單筆查詢重新驗證；(2) TiDB 做嚴格 A/B（同資料/查詢/順序，
  leader／舊 zone／統一 zone 三組對照，扣除背景複寫 baseline）；(3) 補做
  staleness/freshness 驗證（三家近讀皆涉及過期讀取語義，需實測寫入後多久
  在 GCP 可見，核對是否符合 A-A-RO 測試定義）；(4) 至少重跑一個高併發檔位
  （W=128 t128 數輪）並在執行期間採集近讀證據，而非僅測單筆查詢；(5) 統一
  zone 生效前應補做 P-A/P-B placement gate 與故障域評估；(6) 07-21 的原始
  驗證 artifact（8 次 CRDB EXPLAIN、YBDB on/off samples、TiDB netflow
  pre/post 原始輸出）未存入 repo，第三方無法獨立重算，應補存。

  **(6) 已於 07-22 補存**：原始輸出存入
  [nearread-verify-evidence-20260721/](nearread-verify-evidence-20260721/README.md)
  （含 `tidb-zone-labels.txt`、`crdb-explain-analyze-8x.txt`、
  `ybdb-explain-analyze-on-off.txt`、netflow pre/post JSON 共 5 輪）。
  `check-nearread.sh` 的三項 fail-closed 缺口（見上方項目一）亦已修正：
  TiDB 分支改為實際比對 `OWN_ZONE` 與每一台 GCP TiKV store 的 zone，任一
  不符即 `exit 1`；CRDB 分支 region 非純 gcp 或 sql/kv nodes 出現 idc 節點
  皆改為 `exit 1`（原本只 `WARN`）；YBDB 分支改為 5 次交錯取樣取中位數，
  降低單次抖動誤判機率。(1)-(5) 均未執行，仍列入 §8 未竟事項。

## 6. 各資料庫觀察

- `觀察`：TiDB t128 range% 23.6% 為三家最高，且 t64→t128 tpmC 微降——與
  [XCROSS-CLOSING-REPORT-DRAFT.md §6.1](XCROSS-CLOSING-REPORT-DRAFT.md) 記載的
  P-A×A-S 下 TiDB 低併發延遲敏感、高併發近線性的形狀不同（此處是 A-A-RO 雙端
  並發下的新場景，GCP 側同時打流量可能改變 IDC 側資源競爭型態）。`根因未確認`
  ——本輪未收集逐輪 mpstat 對照，留待下一輪補強。
- `觀察`：YBDB／CRDB 在 A-A-RO 下的 IDC 側 t128 tpmC（12,882.5／11,331.1）與
  P-A×A-S #3 批（12,769.5／10,163.4，見 [XCROSS-CLOSING-REPORT-DRAFT.md §5.1](XCROSS-CLOSING-REPORT-DRAFT.md)）
  量級相近——`機制推論`：GCP 側的 read-only 流量對 IDC 側寫入路徑影響有限（副本
  同步是既有 raft/paxos 背景成本）；跨批比較，未做同批對照實驗，僅供參考。
  **本批（07-20，修法前）「read-only 查詢多數走 GCP 本地副本」假設不成立**
  ——§5.4 執行面查核顯示證據不足，TiDB／YBDB 甚至傾向反方向；07-21 已定位
  三家根因並修復（§5.5），但**修法後尚未重跑 W=128**，本節數字仍受修法前
  的近讀失效狀態影響，勿沿用「已修復」的假設回頭解讀本批（07-20）數據。

## 7. 執行紀錄與問題

- `實測事實`：`ANCHOR_ONLY=1` 機制（跳過 freeze/run/collect，僅 prepare+gate）
  首次在真實 W=128 場景驗證有效——TiDB anchor prepare 耗時 ~57 分鐘（資料載入
  本身固定成本，無法省），省下的是後續若整段重跑一次 baseline 才能拿到
  anchor 證據的時間（原設計動機見 [scripts/win-aaro-w128.sh](scripts/win-aaro-w128.sh) 註解）。
- `實測事實`（根因＋修復）：TiDB cell 首次驗證 FAIL——`merge-gcp-stdout.sh` 的
  `while read` 迴圈內 `ssh ... cat ...` 未將 stdin 導向 `/dev/null`，偷走了
  迴圈自身 here-string 輸入，導致 20 筆待合併檔案只處理 1 筆
  （`threads-128/round-1`）。與 SESSION-HISTORY 記載過的 `ybdb-master-quorum-gate.sh`
  同一種陷阱重演。`check-aaro-artifacts.py` 正確 fail-closed 攔下（未讓半套
  artifact 靜默通過）。修復：`< /dev/null`（commit `78796957`）。修復後手動
  補救 TiDB 既有 20/20 raw stdout（IDC/GCP 兩側皆已正確落地，僅合併步驟有誤），
  重生 `summary.json`、重驗 PASS，未重跑 workload；YBDB/CRDB 兩家沿用修好的
  版本，全程零人工介入。
- `實測事實`：三家依序共用同一批 VM（`teardown-{db}` 僅移除 DB 軟體，不動
  terraform/VM），符合 `win-aaro-w128.sh` 設計；VM 僅在批次開始前 `phase1+phase2`
  建一次、批次結束後 `phase9-destroy` 拆一次。

## 8. 效度邊界與未竟事項

| ID | 缺口 | 對結果影響 | 下一步 |
|---|---|---|---|
| A1 | TiDB t128 range% 偏高（23.6%）、t64→t128 微降之機制未確認 | 不影響「0 錯誤、機制可行」的核心判定 | 下一輪加 per-round mpstat/iostat 對照 |
| A2 | 本批僅 N=1（單輪），無同參數重跑驗證重現性 | 數字為單次觀察，不作跨輪穩定性宣稱 | 視排程需要決定是否重跑 |
| A3 | GCP／IDC 兩側量級比較僅為觀察，無 workload-normalized 對照設計 | 不影響本報告範圍內結論 | 若需要「等效負載換算」需獨立設計 |
| A4 | 原始 artifact（121M）依拍板未進 repo（`.gitignore`），report 連結在無本地副本環境會失效 | 不影響本機使用；影響外部可重現性 | 待留存決策；決議保留時移除 `.gitignore` 該行即可 |
| A5 | X-CROSS `baseline_eligible=false` | 數字不得進正式跨家排名 | 恆定約束（同 P-A×A-S 報告 O5） |
| A6 | GCP 就近讀在 07-20 批確實未生效（三家各有實際根因，§5.5），07-21 已修復並在 smoke 規模驗證生效，**但尚未在完整 W=128 批次重跑確認** | 07-20 批 `read_tpmTotal` 吞吐數字本身有效，但該批的「近讀」不可宣稱已驗證（修法前）；§1-§6 採用數字未更新（仍是修法前批次） | 重跑完整 A-A-RO W=128 批次（三家修法已落地：TiDB zone 統一、CRDB/YBDB GCP_CONN_PARAMS），用 [check-nearread.sh](scripts/check-nearread.sh) 驗證後更新 §1-§6 採用數字 |
| A7 | codex 獨立審查（§5.6）指出的 5 項補做（真實交易取代 LIMIT 1、TiDB 嚴格 A/B、staleness/freshness 驗證、高併發檔位在執行期間採集證據、統一 zone 前的 placement/故障域評估）尚未執行，僅第 6 項（原始 artifact 補存）已完成 | 現有 07-21 驗證結果僅為「強支持證據，非決定性」（CRDB 除外，近乎決定性但範圍限於單一查詢型態）；不足以作為重跑 W=128 前的充分把關 | 依 §5.6 優先序執行，至少完成 (1)(4) 後再決定是否重跑完整 W=128 批次 |

## 9. 追溯紀錄

- 執行歷史：[SESSION-HISTORY.md](SESSION-HISTORY.md) 2026-07-18（A-A-RO smoke
  四根因修復）、2026-07-20/21（本輪全跑＋merge-gcp-stdout.sh 修復）
- Smoke 前置：[SMOKE-AARO-SUMMARY.md](SMOKE-AARO-SUMMARY.md)（W=4 t16，07-18）
- Commits：`e2cae9a2`（4 根因修復＋smoke）、`f92d2491`（ANCHOR_ONLY／win-aaro-w128
  driver）、`78796957`（merge-gcp-stdout.sh stdin 修復）、`836d655f`（就近讀
  三家根因修復＋驗證）
- 就近讀驗證原始輸出：[nearread-verify-evidence-20260721/](nearread-verify-evidence-20260721/README.md)
- codex 獨立審查對象：本文件 §5.4/§5.5/§5.6、[ansible/playbooks/tidb-vm6.yml](../ansible/playbooks/tidb-vm6.yml)、[run-vm6-aa.sh](scripts/run-vm6-aa.sh)、[check-nearread.sh](scripts/check-nearread.sh)
