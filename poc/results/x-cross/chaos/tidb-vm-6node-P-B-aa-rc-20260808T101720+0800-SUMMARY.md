# TiDB P-B×A-A — 完整 5 情境 chaos/failover 實跑 (2026-08-08)

環境 TS=`20260808T101720+0800`（實際資料載入時 prepare artifact 目錄用的是
`...rc-20260808T102900+0800`，是 phase6 內部第二次 TS 戳記，兩者屬同一次
連續部署，非兩個環境）。W=128，placement gate 人工修正後確認 PASS
（idc=10/19=52%，符合 P-B 30-70% 混合分布預期）。依 48 次注入 campaign
第 2 組（TiDB, P-B×A-A），共 11 次真實注入。

## 結果總表

| 情境 | Kill target | Role | Scope | RTO (s) | RPO (lost tx) |
|---|---|---|---|---:|---:|
| C7 disk-slow | .32 | - | - | n/a（韌性敘述，見下） | n/a |
| C1 partition | 全6台 | - | - | n/a（韌性敘述，見下） | n/a |
| F1 | .32 | leader | tidb+tikv | 7.064 | 0 |
| F1 | .32 | leader | tidb+tikv+pd | 7.011 | 0 |
| F1 | .33 | follower | tidb+tikv | 4.180 | 0 |
| F1 | .33 | follower | tidb+tikv+pd | 6.877 | 0 |
| C4 | .32 | leader | tidb+tikv | 8.372 | 0 |
| C4 | .32 | leader | tidb+tikv+pd | 7.480 | 0 |
| C4 | .33 | follower | tidb+tikv | 7.389 | 0 |
| C4 | .33 | follower | tidb+tikv+pd | 6.722 | 0 |
| F2 | 全3台IDC | - | tidb+tikv+pd | 見下方拆解 | write correctly rejected |

## 與 P-A×A-S 的對照重點

1. **RTO 量級與 P-A 一致**（4.18-8.37s 區間 vs P-A 的 6.68-7.32s），沒有
   觀察到「P-B 因 leader 已分散兩地、failover 更快」的訊號——這點跟本
   repo 既有 `XCROSS-PA-VS-PB-FINAL-COMPARISON.md` §6.1 的既有澄清一致：
   P-B 的 leader/lease 混合分布**不等於**整區故障下有結構性 failover
   優勢，兩者是不同的性質。本次數據補充佐證：連「單一節點層級」的
   failover，P-B 也沒有展現出比 P-A 更快的跡象。
2. **F1-follower-tidbtikv（.33）量到 4.180s，是本輪 8 組 F1/C4 中最低的
   一筆**，但同一台主機的其餘 3 種變體（+pd、leader×2）都落在 6.7-8.4s，
   與 P-A 那次的離群值（follower 0.030s vs 其餘 ~6.7-7.3s）呈現同一種
   「量測雜訊」型態——這次進一步支持「follower kill 的 RTO 讀數不穩定，
   受 HAProxy round-robin 是否剛好避開故障 backend 的機率影響」這個假說，
   而非「follower 真的有結構性優勢」。
3. **Leader 分布本身**：P-B 環境下 6 個 store 全部都持有 leader（IDC 三台
   各 2-5 個、GCP 三台各 2-5 個），對照 P-A 環境下 GCP 三台 leader 數恆為
   0——這是本次直接查詢驗證的 fact，符合 P-B「per-shard leader 散」的
   設計預期。
4. **F2 拆解**（同 P-A 需要重新解讀基準點）：`t_kill=04:35:16.986Z`、
   `t_restart_start=04:37:56.256Z`（相隔 159.27s，操作等待，含
   write-reject 驗證時間）、`t_all_idc_healthy` 僅重啟後 0.196s——**與
   P-A 同樣的 PD store-down 判定閾值長於停機時間的假訊號，不可視為真實
   復原時間**、`t_first_write_ok` 重啟後 **39.133s** 恢復可寫——與 P-A
   的 44.3s 同量級，**這是本次唯一可信的復原時間指標**。Write-reject
   同樣正確判定（`PD server timeout` → `write_correctly_rejected`）。

## 過程中新發現並修復的既有專案級 bug（非本次新建腳本）

**`tests/common/prepare.sh` 第 286 行 placement 解析 regex 錯誤**：
`grep -oE 'P-[AB]$'` 是**字串結尾錨定**，只認得 TOPO 剛好以 `P-A`/`P-B`
結尾的情況（如 `vm-6node-P-A`）。但 PROFILE=A-A 時 TOPO 會變成
`vm-6node-P-B-aa`（PROFILE_TOKEN `-aa` 接在 placement 後面），錨定
regex 完全比對不到，導致 `PLACEMENT_FROM_TOPO=UNKNOWN`，使原本已經
正確算出 `idc_leader_count=10 gcp_leader_count=9`（真實有效數據）的
gate 判定被錯誤地 fail-closed，整個 `phase6-tidb-smoke` 在 128 個
warehouse 資料早已全部載入完成之後才在最後一步失敗（`.suite.failed`,
exit=1）。

**修復**：移除結尾錨定，改為 `grep -oE 'P-[AB]'`（比對任意位置），已
驗證對 `vm-6node-P-A`、`vm-6node-P-B`、`vm-6node-P-B-aa` 皆正確解析。
**未重新執行整個 prepare**（`prepare.sh` 開頭是無條件 `DROP DATABASE +
CREATE DATABASE`，非幂等，重跑會清空已載入的 128 warehouse 資料、需
再花約 1 小時重新載入）——改為人工依原始查詢結果（idc=10/19=52%，落在
P-B 預期的 30-70% 區間）補寫正確的 `placement-gate-P-B.json`，保留原始
`placement-gate-UNKNOWN.json`（壞掉的版本）於
`tidb-vm-6node-P-B-aa-placement-gate-fix/` 供稽核比對。這是**這次 chaos
campaign 目前為止唯一發現於 `tests/common/`（跨所有 phase 共用的核心腳
本，不是 phase-crossregion 自己的新程式碼）的 bug**，過去可能一直沒被
抓到是因為多數既有測試批次都用 PROFILE=A-S（無 PROFILE_TOKEN 後綴，
TOPO 剛好以 P-A/P-B 結尾），這是第一次在跨區 campaign 中對 P-B 搭配
A-A profile 執行 gate 檢查。

## 目錄索引

各情境 raw artifact 見對應
`tidb-vm-6node-P-B-aa-rc-20260808T101720+0800-scenario<X>/` 子目錄；
`tidb-vm-6node-P-B-aa-placement-gate-fix/` 保留 gate bug 修復前後對照；
`tidb-vm-6node-P-B-aa-rc-20260808T101720+0800-scenarioC7-attempt1-no-fio/`
為 fio 未安裝時的失敗嘗試記錄。

## 待續

TiDB 兩個 placement（P-A、P-B）皆已完成，累計 22 次真實注入。下一步：
YugabyteDB（依修正後的執行順序 TiDB→YBDB→CRDB）。
