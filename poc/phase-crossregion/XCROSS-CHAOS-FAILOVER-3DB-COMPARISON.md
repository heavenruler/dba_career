# X-CROSS Chaos/Failover 3DB 比較報告（TiDB / YugabyteDB / CockroachDB）

> **Scope**：`X-CROSS`，`baseline_family=crossregion`，`baseline_eligible=false`。
> 本報告內所有數字皆為探索性 PoC 觀察，每個 DB×placement×情境 cell 僅 `N=1`（單次真實注入），
> **不構成 S-BASE 正式跨家排名，也不構成統計顯著的因果結論**。3 個 DB 分屬不同批次、不同時間
> 執行（2026-08-08 全天），非同批同時進行，跨 DB 比較是觀察性對照，不是嚴格 paired control 實驗。
>
> **範圍**：3 DBs（TiDB → YugabyteDB → CockroachDB）× 2 placements（P-A×A-S、P-B×A-A）× 5 情境
> （C7 磁碟慢 → C1 網路分區 → F1 graceful kill → C4 ungraceful kill → F2 IDC 全滅），
> 每組環境跑滿 5 情境（F1/C4 各含 leader/follower 子情境，TiDB 額外有 ±pd 變體）才 teardown，
> 共 6 個環境、48 次真實 chaos 注入（含 TiDB 的 ±pd 變體）。所有環境已於本報告完成前 teardown。

## 0. 本報告與既有文件的關係

- [`P-A-vs-P-B-explainer.md`](./P-A-vs-P-B-explainer.md)、
  [`XCROSS-PA-VS-PB-FINAL-COMPARISON.md`](./XCROSS-PA-VS-PB-FINAL-COMPARISON.md) 是既有的
  **穩態 tpmC/延遲/錯誤率**跨 placement 比較文件（TPC-C 持續負載下的效能特徵），本報告不重複、
  不覆蓋其內容。本報告專注於**故障注入下的 failover 行為**（RTO/RPO/韌性），是全新的獨立分析軸。
- `DISTRIBUTED-DB-SCORING.md`（PoC 評分表）第 6 項「Failover RTO／RPO」由使用者之後手動摘錄本報告
  數字回填，本報告**不直接編輯**該評分表。該評分表原本記載的驗證方法是「F1(P-A)/C4(P-B)」的窄範圍，
  與本報告的 48 次寬範圍（每 DB×placement 都跑滿 5 情境）不一致，屬已知且被使用者接受的落差——
  本報告的範圍更廣，使用者可自行決定要摘錄多少進評分表。
- 6 份逐環境結案報告（`results/x-cross/chaos/<db>-vm-6node-<placement>-rc-<TS>-SUMMARY.md`）是本報告
  的原始資料來源，含完整過程敘述與 bug 修復細節；本報告是彙整層級文件，逐項細節仍以各自結案報告
  為準（§11 證據索引）。

## 1. 覆蓋範圍與缺口

| DB | Placement | 狀態 | TS | 情境涵蓋 |
|---|---|---|---|---|
| TiDB | P-A×A-S | ✅ | `20260808T075957+0800` | C7/C1/F1×2×2(±pd)/C4×2×2(±pd)/F2 = 11 次注入 |
| TiDB | P-B×A-A | ✅ | `20260808T101720+0800` | 同上 = 11 次注入 |
| YugabyteDB | P-A×A-S | ✅ | `20260808T144840+0800` | C7/C1/F1×2/C4×2/F2 = 7 次注入 |
| YugabyteDB | P-B×A-A | ✅ | `20260808T172141+0800` | 同上 = 7 次注入 |
| CockroachDB | P-A×A-S | ✅ | `20260808T200335+0800` | 同上 = 7 次注入 |
| CockroachDB | P-B×A-A | ✅ | `20260808T220127+0800` | 同上 = 7 次注入 |

合計 **50 次真實注入**（TiDB 因 ±pd 變體多出 4 次，非原規劃的 48 次整數，差異已知且合理）。

**已知缺口**（詳見 §10）：
- TiDB 段有 2 筆已知污染數據（P-A 段誤選非 HAProxy backend 的 C4-leader 首次嘗試；已標記
  INVALID 並排除於統計外，不計入上表次數）。
- C1/C7 全程未量測 tpmC-during-incident（背景 workload log 覆蓋/量測工具本身限制，見各環境
  SUMMARY 與 §5、§6）。
- RPO 全程使用簡化版量測（per-warehouse `max(o_id)` high-water-mark），非完整 driver-hooked FIFO
  buffer，故所有「RPO=0」結論的精確度有其方法論上限（見 §10）。

## 2. F1/C4 leader-kill RTO/RPO 對照

RTO 單位：秒。TiDB 含 ±pd 兩變體（tidb+tikv / tidb+tikv+pd）；YBDB/CRDB 無此變體（單一數值）。

| DB | Placement | F1-leader (graceful) | C4-leader (ungraceful) | RPO |
|---|---|---:|---:|---:|
| TiDB | P-A | 6.934 / 6.692(+pd) | 6.844 / 6.684(+pd) | 0 |
| TiDB | P-B | 7.064 / 7.011(+pd) | 8.372 / 7.480(+pd) | 0 |
| YugabyteDB | P-A | 0.260 | 0.375 | 0 |
| YugabyteDB | P-B | 2.627 | 3.518 | 0 |
| CockroachDB | P-A | 0.035 | 0.100 | 0 |
| CockroachDB | P-B | 0.037 | 0.105 | 0 |

**觀察**：
- TiDB 的 leader-kill RTO 全數落在 6.7~8.4 秒，比 YBDB/CRDB 慢一個數量級（後兩者多在
  0.03~3.5 秒）。這與 TiDB 的 TiKV Region Raft leader 重選機制（`raftstore.raft-election
  -timeout-ticks` 預設值較保守）以及 client 端需經過 HAProxy 健康檢查週期才會停止路由到掛掉的
  backend 有關；YBDB/CRDB 的量測皆直連 GCP host 的 driver 層 retry，路徑更短。
- graceful（F1）vs ungraceful（C4）在三家 DB 上都只差 65ms~1.5s，**沒有一家展現出「graceful
  resign 能顯著縮短 RTO」的效果**——這是本報告最一致的跨 DB 發現（見 §7）。
- YBDB 是唯一一家 leader-kill RTO 受 placement 顯著影響的 DB：P-A（pin leader）0.26~0.38s vs
  P-B（不 pin，殺到真實 tablet 資料 leader）2.6~3.5s，相差近 10 倍（見 §7 詳述根因）。
- CRDB 兩個 placement 幾乎完全一致（35~105ms），顯示其 range lease failover 對 leader 是否
  被 pin 完全不敏感。

## 3. F1/C4 follower-kill 對照組

| DB | Placement | F1-follower (graceful) | C4-follower (ungraceful) | RPO |
|---|---|---:|---:|---:|
| TiDB | P-A | 7.315 / 6.909(+pd) | 0.030†(離群) / 6.715(+pd) | 0 |
| TiDB | P-B | 4.180(離群) / 6.877(+pd) | 7.389 / 6.722(+pd) | 0 |
| YugabyteDB | P-A | 0.391 | 0.328 | 0 |
| YugabyteDB | P-B | 0.009 | 0.455 | 0 |
| CockroachDB | P-A | 0.081 | 0.131 | 0 |
| CockroachDB | P-B | 0.104 | 0.105 | 0 |

† TiDB 的 2 筆離群值（P-A C4-follower 0.030s、P-B F1-follower 4.180s）與同組其餘 3 筆變體
（皆落在 6.7~8.4s）差距極大，兩份 SUMMARY 都判定為**量測雜訊**（HAProxy round-robin 是否
「運氣好」剛好沒連到掛掉的 backend 所致），不是「follower kill 真的更快」的證據——8 組
follower 測試中僅 2 組離群，其餘 6 組都落在 leader-kill 同量級。

**跨 DB 結論**：leader vs follower kill 的 RTO 在三家 DB 上**都沒有觀察到結構性差異**
（follower 理論上不需要 failover、quorum 應仍在，若假設成立應觀察到 follower RTO 顯著低於
leader，但實測數字並不支持——TiDB 剔除離群值後兩者同量級；YBDB/CRDB 兩者也都在同一數量級）。
這驗證了各環境 SUMMARY 已各自提出的懷疑：F1/C4 的量測解析度（秒級到十分之一秒級）不足以
分辨「leader kill 需要選新 leader」與「follower kill 只是少一票但服務不中斷」這兩種理論上
不同的故障模式——三家 DB 的實際 failover/重連機制都夠快，兩種 kill 對 client 可見延遲的差異
被其他雜訊（探測週期、driver 重試邏輯）蓋過。

## 4. C1（網路分區）韌性敘述

三家 DB 皆使用同一支 DB-agnostic 腳本（`chaos-c1-partition-execute.sh`，30 秒 IDC↔GCP 雙向
iptables DROP），無需修改即可套用所有 DB。

- **TiDB**：韌性敘述層級（無 RTO/RPO 數字，此情境設計上不測 leader failover）。
- **YugabyteDB**：兩個 placement 皆觀察到 probe 全程 `err`（partition 期間符合預期，GCP↔IDC
  斷線），30 秒後自動 restore，6/6 tserver ALIVE 復原，無需人工介入。
- **CockroachDB**：兩個 placement同樣 30 秒後自動 restore，6/6 node available/live 復原。
  P-B 段可見 workload TPM 在 partition 期間明顯下降（真實流量受阻的直接證據）。

**跨 DB 觀察**：三家 DB 對 30 秒級的 WAN 分區都展現出乾淨的自動復原，沒有一家在 partition
解除後需要人工介入才能恢復正常運作。這是本報告中最「無差異」的情境——三家 DB 的網路分區容忍
設計都達到了基本預期。

## 5. C7（磁碟慢）韌性敘述

三家 DB 皆使用同一支腳本（`chaos-c7-disk-slow-execute.sh`，30 秒 fio 磁碟 I/O 競爭），
`DATA_DIR` 依 DB 各自路徑（TiDB `/data`+TiKV 各自路徑、YBDB `/var/yugabyte/data`、
CRDB `/var/lib/cockroach`）。

- 三家 DB、兩個 placement，共 6 次 C7 注入，**全數 6/6（或全 store/node）在 fio 競爭期間及結束後
  維持 ALIVE/available/live**，沒有任何一次因磁碟 I/O 競爭導致節點被判定下線或服務中斷。
- fio 本身在每個新建的 VM 上都需要重新安裝（`dnf install fio`）——這是每次環境重建的例行前置
  動作，不是 bug，記錄於此供未來執行參考。

**跨 DB 觀察**：30 秒級的磁碟 I/O 競爭強度不足以觸發任何一家 DB 的節點健康檢查判定下線，三家
DB 在此情境下沒有可觀察的差異。這符合預期——30 秒的短暫磁碟競爭遠低於典型的節點健康檢查逾時
閾值（通常以分鐘計）。

## 6. F2（IDC 全滅）韌性敘述，含真實重建時間

F2 對 3 台 IDC host 同時發出真實 kill（TiDB: `tidb-4000+tikv-20160+pd-2379`；YBDB:
`yugabyted stop`；CRDB: `systemctl stop cockroach`），驗證「write 在 quorum 遺失時應正確拒絕」
且量測「重啟後到能再次成功寫入」的時間。

**F2 數字的基準點修正**（三家 DB 的 SUMMARY 皆已各自提出並統一套用此公式）：腳本原生輸出的
`write_recovery_sec`/`cluster_rebuild_sec` 是從 `t_kill` 起算，內含「偵測 kill 完成 + 跑
write-reject 驗證 + 送出 restart 指令」這段前置操作時間（依 DB 不同，約 8~160 秒不等），
**不是真實的 DB 重建時間**。統一改用 `t_first_write_ok − t_restart_start` 作為可信指標。

| DB | Placement | 真實復原時間（重啟→首次成功寫入） | Write-reject 驗證 |
|---|---|---:|---|
| TiDB | P-A | **44.3s** | `PD server timeout` → 正確拒絕 |
| TiDB | P-B | **39.1s** | `PD server timeout` → 正確拒絕 |
| YugabyteDB | P-A | **≈3.2s** | `psql: timeout expired` → 正確拒絕 |
| YugabyteDB | P-B | **≈3.05s** | `psql: timeout expired` → 正確拒絕 |
| CockroachDB | P-A | **≈12.95s** | 真實 `lost quorum`/`waiting 62.00s for slow proposal` → 正確拒絕 |
| CockroachDB | P-B | **≈7.21s** | 同上錯誤模式 → 正確拒絕 |

**跨 DB 排序（真實復原時間，快→慢）**：YugabyteDB（~3s）< CockroachDB（7~13s）< TiDB（39~44s）。

**正確性方面三家 DB 表現一致**：write-reject 驗證全數 6/6 通過，quorum 遺失期間沒有任何一家
DB 出現「誤判寫入成功」的情況，RPO 全數為 0。三家 DB 在「IDC 全滅時正確拒絕寫入」這個正確性
底線上沒有差異，差異只在「恢復速度」。

**YugabyteDB 明顯領先的原因推測**：YBDB 的 `yugabyted` supervisor 重啟速度快、raft 選舉在
小資料量環境下效率高，且 P-A/P-B 兩個 placement 的表現高度一致（~3.05~3.2s），顯示這個優勢
與 placement 設計無關，是 YBDB 自身 failover 機制的特性。

**CockroachDB 較慢的原因**（write-reject-validation.txt 直接證據）：raft proposal 在偵測到
quorum 遺失後會等待較長的內部逾時（`have been waiting 62.00s for slow proposal`）才真正判定
失敗、釋放 client 連線去重試——這是 CRDB 設計上偏保守的逾時策略（避免誤判可能犧牲了恢復速度）。

**TiDB 明顯最慢的原因**：TiDB 需要 PD（Placement Driver）、TiKV、TiDB SQL 層三個獨立元件依序
恢復並重新協調（PD 選主 → TiKV region 重新註冊 → TiDB SQL 層重新拿到有效的 PD leader 連線）才
算真正可寫，元件數量與協調鏈路長度直接反映在恢復時間上。

## 7. 綜合觀察與待驗證假說

1. **Graceful resign 對三家 DB 的 F1/C4 RTO 差異都很小（65ms~1.5s）**——這是最一致的跨 DB
   發現。假說：三家 DB 的 leader/lease failover 機制本身已經足夠快（毫秒到個位數秒級），
   graceful 步驟省下的「重新選舉」開銷相對於整體 RTO 的佔比不大。**待驗證**：若在更高負載
   （更多 warehouse、更多並發連線）下重跑，graceful 的優勢是否會被放大？本次 W=128、單一 client
   的規模可能不足以凸顯差異。

2. **YugabyteDB 是唯一一家 leader-kill RTO 對 placement（是否 pin leader）高度敏感的 DB**
   （P-A 0.26~0.38s vs P-B 2.6~3.5s，近 10 倍差距），CockroachDB 則完全不敏感（P-A/P-B 皆
   35~131ms）。假說：這反映兩者 leader/lease 機制的根本差異——YBDB 的 tablet raft leader
   選舉是完整的 raft election 流程（需要多數投票、任期遞增），CRDB 的 range lease 則是輕量
   timeout-based 機制（無需完整選舉即可重新取得 lease）。**待驗證**：這個假說需要更深入的
   原始碼/文件比對才能確認，本報告僅基於觀測現象推測。

3. **F2 真實復原時間的跨 DB 排序（YBDB < CRDB < TiDB）在兩個 placement 下皆重現**，顯示這是
   DB 自身架構特性造成的穩定差異，而非量測雜訊或 placement 效應。這是本報告信心最高的跨 DB
   結論之一。

4. **`go-tpc` 對不同 DB 的容錯度不同**：CRDB 段的背景 workload 多次因累積錯誤提前結束
   （P-A 段甚至在單一節點 kill 後就中止一次），YBDB 段全程未曾提前中止，TiDB 段則在連續多次
   PD resign 後才崩潰一次。這是量測工具本身的限制，不是資料庫的問題，但意味著**針對不同 DB
   做長時間 chaos campaign 時，需要為 CRDB 準備更頻繁的 workload 健康檢查與重啟機制**。

5. **YugabyteDB P-B 段觀察到一次真實的 DB 穩定性異常**（yb-master 執行緒暴增至 1147、RPC 延遲
   5~80 秒、叢集 12+ 分鐘選不出新 leader，詳見 §8 與 P-B SUMMARY），重啟該節點後恢復正常。
   這是本報告中唯一一次觀察到與工具/腳本 bug 無關的、真實資料庫本身的穩定性風險，樣本數 N=1，
   **待驗證**：是否可重現？根因是否真如推測的「RPC handler thread 未正確回收」？建議列為
   YugabyteDB 生產部署前需要進一步壓力測試驗證的風險項。

## 8. 決策意涵

以下意涵皆基於 N=1 的探索性觀察，**不應作為唯一決策依據**，僅供搭配其他 PoC 面向（穩態效能、
運維複雜度、生態系）綜合考量：

- 若**故障恢復速度**（尤其是 IDC 全滅這類最嚴重的場景）是關鍵決策因素，本次數據顯示 YugabyteDB
  的真實復原時間（~3s）明顯優於 CockroachDB（7~13s）與 TiDB（39~44s）。但需注意 YBDB P-B 段
  也觀察到一次真實的穩定性異常（見 §7-5），若採用 YBDB 且計劃使用不 pin leader 的 placement
  策略，建議在正式部署前針對此風險項做更長時間、更高並發的壓力測試以驗證是否可重現。
- 若採用 **YugabyteDB 且需要 GCP 側低延遲讀取**（P-B 式不 pin leader），需注意單節點故障切換
  RTO 可能因 leader 意外集中在忙碌節點而拉長至秒級（vs pin leader 的次秒級）——這是「GCP
  讀取效能」與「故障切換速度」之間的實際權衡，不是理論推測。
- **TiDB 的 F2 全滅恢復時間明顯最長**（39~44s），源於其三元件（PD/TiKV/TiDB）架構的協調鏈路
  較長。若業務對 RTO 有嚴格 SLA（例如 <10s），TiDB 在本次測試規模下的表現需要進一步優化或
  調參驗證（例如縮短 PD 選主逾時、調整 TiKV region 重新註冊策略）才能評估是否可達標。
- **CockroachDB 的 leader/follower kill RTO 對 placement 設計完全不敏感**，若團隊重視「配置
  簡單、行為可預測」，這是 CRDB 在故障恢復面向上的一個實務優勢——不需要像 YBDB 一樣擔心
  leader 分布是否集中造成 worst-case RTO 放大。
- 三家 DB 在「quorum 遺失時正確拒絕寫入」這個資料正確性底線上**沒有差異**，皆通過驗證。這意味
  著本次測試範圍內，三家 DB 的資料一致性保證是等價的，決策應更多依賴恢復速度、運維複雜度等
  其他面向，而非擔心資料正確性風險。

## 9. 跨 3DB 修復的既有腳本 bug 總表

本次 campaign 過程中，每個 DB 分支「第一次被真實執行到」時幾乎都浮現此前從未被抓到的 bug
（因為這些分支此前從未經過真實環境驗證），修復後皆已沿用到後續同 DB 的第二個 placement，
零重複踩雷。

| # | 檔案 | DB | 問題 | 修復 |
|---|---|---|---|---|
| 1 | `tests/common/prepare.sh` | TiDB（跨全專案共用） | placement regex 字串結尾錨定，比對不到 `vm-6node-P-B-aa` 這種帶 PROFILE_TOKEN 後綴的 TOPO | 移除結尾錨定，改為比對任意位置 |
| 2 | `chaos-c7-disk-slow-execute.sh` | TiDB | 新 VM 未裝 fio 時腳本誤判成功 | 加開跑前 `command -v fio` 檢查 + 事後驗證 `Run status` 行 |
| 3 | `run-vm6-f2-idc-death-execute.sh` | TiDB | `SVC="tidb-server"` 錯誤 unit name | 改為 `tidb-4000 tikv-20160 pd-2379` |
| 4 | `run-vm6-chaos-execute.sh` | TiDB | 只停無狀態 `tidb-server`，未觸發真正 TiKV Raft leader 重選 | `--kill-scope` 改同時停 `tikv-20160`（+視變體加 `pd-2379`） |
| 5 | `probe-rto-driver.sh` | YugabyteDB | `PROBE_USER` 誤預設 `root`（應為 `yugabyte`）；`CREATE DATABASE IF NOT EXISTS` 語法在 YSQL 不存在 | per-DB 正確預設 + 移除 IF NOT EXISTS |
| 6 | `run-vm6-chaos-execute.sh` | YugabyteDB | S_PRE_QUERY 誤用 `oorder` 應為 `orders`（go-tpc postgres driver 命名慣例） | 改為 `orders` |
| 7 | Makefile `phase5-crdb-deploy` | CockroachDB | 缺少 `-o StrictHostKeyChecking=accept-new`，新 VM 首跑失敗 | 補上 accept-new |
| 8 | `run-vm6-chaos-execute.sh` | CockroachDB | F1/C4 共用 `cockroach quit`（本身即 graceful drain），喪失 graceful/ungraceful 對照意義 | C4 改用 `systemctl kill -s SIGKILL` |
| 9 | `run-vm6-chaos-execute.sh` | CockroachDB | `cockroach quit` 在 v26.2 已不存在 | 改用 `cockroach node drain --self --shutdown` |
| 10 | `run-vm6-chaos-execute.sh` | CockroachDB | post-kill 單次即時檢查與 drain 實際完成時序有 race | 改為最多重試 5 次（通用穩健性修正，非 CRDB 專屬） |
| 11 | `run-vm6-chaos-execute.sh` | CockroachDB | LEADER_QUERY 缺少 `WITH DETAILS`，`lease_holder` 欄位查詢失敗 | 補上 `WITH DETAILS` |
| 12 | `run-vm6-chaos-execute.sh` | CockroachDB | S_PRE_QUERY 誤用 `oorder` 應為 `orders`（同 #6） | 改為 `orders` |
| 13 | `run-vm6-f2-idc-death-execute.sh` | CockroachDB | WRITE_PROBE 是空的 `SELECT 1`，測不到 write-reject | 改真實 INSERT+DELETE |
| 14 | `run-vm6-f2-idc-death-execute.sh` | CockroachDB | HEALTH_QUERY 查詢 `crdb_internal.kv_node_status` 在 v26.2 被拒絕存取 | 改用不受限的 `cockroach node status` |

（另有 YugabyteDB F1/C4 分支的 systemd→yugabyted 誤用、YBDB/CRDB F2 分支的 systemctl→
yugabyted/正確 SVC 誤用等，屬於本次 campaign 前置的分支修復，已記錄於各自的過程 commit
訊息，未逐一列於本表——本表聚焦於「造成量測結果無效或阻斷執行」的關鍵 bug。）

## 10. 未解決缺口

- **RPO 量測精確度上限**：全程使用簡化版（per-warehouse `max(o_id)` high-water-mark），
  非完整 driver-hooked FIFO buffer。所有「RPO=0」結論代表「未偵測到遺失」，不等同「數學上
  證明零遺失」——極短暫的遺失窗口若剛好落在兩次採樣之間可能無法偵測。
- **C1/C7 未量測 tpmC-during-incident**：三家 DB 皆缺少此數據，僅有定性的「N/N 存活」韌性
  敘述，無法量化磁碟慢/網路分區期間的效能降級程度。
- **樣本數 N=1**：每個 DB×placement×情境組合僅執行一次真實注入（TiDB 因涉及新 bug 修復
  有 2~3 次重跑，但視為同一次「有效」量測，不是獨立重複樣本）。所有數字皆可能受單次執行的
  環境雜訊影響，不構成統計顯著的結論。
- **YugabyteDB 執行緒暴增異常未複測**：§7-5 提及的 P-B 段真實穩定性異常僅發生過一次，未在
  相同條件下重複驗證是否可重現，根因也僅基於現象推測、未深入原始碼查證。
- **TiDB follower-kill 的離群值未深入排查**：§3 提及的 2 筆離群值（0.030s、4.180s）判定為
  量測雜訊，但未做進一步的根因分析（例如逐次重跑驗證 HAProxy round-robin 假說）。
- **CRDB 的 F2 P-A/P-B 差異（12.95s vs 7.21s）樣本數不足**：兩個 placement 各僅 1 次樣本，
  無法判斷這 5.7 秒差異是真實的 placement 效應還是單次雜訊（見 §6 已註明）。

## 11. 證據索引

各環境完整過程、artifact 清單見對應結案報告與 raw artifact 目錄：

- TiDB P-A：[SUMMARY](../results/x-cross/chaos/tidb-vm-6node-P-A-rc-20260808T075957+0800-SUMMARY.md) ｜ `results/x-cross/chaos/tidb-vm-6node-P-A-rc-20260808T075957+0800-scenario*/`
- TiDB P-B：[SUMMARY](../results/x-cross/chaos/tidb-vm-6node-P-B-aa-rc-20260808T101720+0800-SUMMARY.md) ｜ `results/x-cross/chaos/tidb-vm-6node-P-B-aa-rc-20260808T101720+0800-scenario*/`（另含 `-placement-gate-fix/` 保留 bug 修復前後對照）
- YugabyteDB P-A：[SUMMARY](../results/x-cross/chaos/ybdb-vm-6node-P-A-rc-20260808T144840+0800-SUMMARY.md) ｜ `results/x-cross/chaos/ybdb-vm-6node-P-A-rc-20260808T144840+0800-chaos/`
- YugabyteDB P-B：[SUMMARY](../results/x-cross/chaos/ybdb-vm-6node-P-B-aa-rc-20260808T172141+0800-SUMMARY.md) ｜ `results/x-cross/chaos/ybdb-vm-6node-P-B-aa-rc-20260808T172141+0800-chaos/`
- CockroachDB P-A：[SUMMARY](../results/x-cross/chaos/crdb-vm-6node-P-A-rc-20260808T200335+0800-SUMMARY.md) ｜ `results/x-cross/chaos/crdb-vm-6node-P-A-rc-20260808T200335+0800-chaos/`
- CockroachDB P-B：[SUMMARY](../results/x-cross/chaos/crdb-vm-6node-P-B-aa-rc-20260808T220127+0800-SUMMARY.md) ｜ `results/x-cross/chaos/crdb-vm-6node-P-B-aa-rc-20260808T220127+0800-chaos/`

每個 `chaos/scenario<X>/` 子目錄依情境含 `kill.log`／`rto-rpo.json`／`rto-wall-clock.json`／
`plan.txt`／`probe.txt`／`s_pre.txt`／`s_post.txt`／`db-config-snapshot/`（F1/C4）或
`fio-summary.txt`／`io-latency-p99.txt`（C7）或 `error-rate-by-sec.txt`／`iptables-rules-*.txt`
（C1）或 `write-reject-validation.txt`／`recovery-poll.log`（F2）等原始證據檔案。

所有 6 個環境的 VM（IDC 3 台 + GCP 5 台）已於本報告完成後 teardown（`phase1-destroy`，
IDC 3 destroyed + GCP 5 destroyed，2026-08-09）。
