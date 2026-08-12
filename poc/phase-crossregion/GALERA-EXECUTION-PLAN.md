# Galera (Percona XtraDB Cluster 8.4) 執行計畫

狀態：**Stage 0（靜態修正 + preflight）已完成，尚未實跑部署/benchmark。**
對照文件：`DISTRIBUTED-DB-SCORING.md` §2.1/§4.1/§5.1（MySQL 相容群組：Galera vs TiDB）。

本文件回應 2026-08-11 Codex review（`/tmp/pxc-fix`）§4 要求，記錄從目前狀態到
產出可比較評分數字的完整分期執行路徑。Stage 0 之後每個 stage 都需要真的碰
機器（SSH/部署/benchmark），依現有流程須先經過人工核准才能執行——本文件
只是計畫，不代表已獲執行授權。

## 設計前提（勿與 TiDB/CRDB/YBDB 混淆）

Galera 是同步多主複寫，沒有 leader/lease/placement policy 概念；P-A/P-B 差異
完全收斂成 **client 連線目標**（routing profile），伺服器端叢集部署本身不變。
見 `ansible/playbooks/galera-vm6.yml` 開頭設計說明、`tests/common/run.sh` 內
`galera_routing_profile`（`G-SW-IDC` / `G-DW-XR`，F-009）。**這與 tidb/crdb/ybdb
的 P-A/P-B（server 端 placement policy 差異）不是同一種語意，比較時不可假設
等價。**

## Stage 0 — 靜態修正 + preflight（本輪，已完成）

範圍：不碰機器，只修 script/playbook/Makefile 正確性與可觀測性。

- F-001 PXC repo/package preflight（`pxc84`→`pxc-84-lts`、`dnf module disable
  mysql`、NEVRA 存證）
- F-002 移除明碼密碼與 passwordless root（三帳號模型：root@localhost /
  sstuser@localhost / tpcc_bench@'%'，全部走 env var + no_log）
- F-003 `gate-isolation.sh` driver-side case 補 galera 分支
- F-004 `prepare.sh` P-B row-count 驗證改用 DB-conditional client（不誤用 psql）
- F-005 `gcp-replica-gate.sh` 改逐台查 GCP 節點（不再誤查 IDC 自己）+ sentinel
  causal-read + cluster UUID 一致性檢查
- F-006 bootstrap/SST idempotency（enabled:false、datadir-exists guard、
  throttle:1 序列化 joiner SST、log 存證、timeout pending runtime validation）
- F-007 SELinux port labeling（semanage，非 blanket disable）+ firewalld
  preflight + port 佔用 preflight
- F-008 Makefile `PLACEMENT` target-specific 固定（P-A/P-B），避免全域預設值
  污染 A-A smoke 目標
- F-009 P-A/P-B 語意不假等價：`galera_routing_profile` + `placement_semantics_note`
  metadata 注入 run.done
- F-010 wsrep 執行指標補強（`db-config-dump.sh` 逐台 `SHOW GLOBAL STATUS LIKE
  'wsrep_%'`；`gcp-replica-gate.sh` 額外記錄 flow-control/repl-latency 等）

驗證：`bash -n` × 10 個 script、`ansible-playbook --syntax-check`、`make -n` ×
3 個 target（含 PLACEMENT 解析正確性）、`git diff --check` 全部通過。**未跑過
任何 ansible-playbook apply、未 SSH 進 .31/.32-.34/GCP、未跑過任何 W=4/W=128
workload。**

## Stage 1 — 首次部署 + 基本健康檢查（下一步，需人工核准後執行）

1. `make phase-galera-deploy`（6 節點 ansible-playbook apply）
2. 逐台驗證：`wsrep_cluster_size=6`、`wsrep_cluster_status=Primary`、
   `wsrep_ready=ON`、`wsrep_local_state_comment=Synced`、6 台 `wsrep_cluster_state_uuid`
   一致
3. 首次觀察 SST 實際耗時（F-006 標記為 pending runtime validation 的項目在此
   收斂成具體數字，回填 wait_for timeout）
4. 驗證 semanage port / firewalld preflight 在真實環境的行為（F-007 假設是否
   成立：SELinux 是否真的 enforcing、firewalld 是否真的在跑）

失敗處置：任何一步 fail-closed 就停下來修，不重跑「帶著已知失敗繼續往下」。

## Stage 2 — P-A×A-S / P-B×A-A smoke（W=4，驗證 pipeline 正確性）

1. `make phase-galera-smoke`（P-A×A-S，IDC client 單寫 idc-dbhost-1）
2. `make phase-galera-aa-smoke`（P-B×A-A，IDC+GCP 同時寫）
3. 確認 gate-isolation / prepare / gcp-replica-gate 全部 PASS，run.done 內
   `galera_routing_profile` 正確標記（G-SW-IDC / G-DW-XR）
4. 確認 summary.json 產出格式與 tidb 一致（供 DISTRIBUTED-DB-SCORING.md 引用）

## Stage 3 — W=128 正式量測（產出可比較評分數字）

與 TiDB 對照口徑一致：P-A×A-S、P-B×A-A 各一組完整 5 round × 4 threads-level
sweep。額外拆分 cost breakdown（Codex 明確要求）：

| # | 情境 | 目的 |
|---|------|------|
| 1 | 單機 wsrep-off control（單節點、不開 Galera） | 量測「同步多主複寫本身」的固定開銷 baseline |
| 2 | IDC-3-node 單寫（3 台 IDC 節點組叢集，client 只連 1 台） | 純同區同步複寫開銷，排除跨區延遲干擾 |
| 3 | 6-node 跨區單寫（P-A×A-S 正式數字） | 對照 TiDB P-A×A-S |
| 4 | 6-node 跨區雙寫（P-B×A-A 正式數字） | 對照 TiDB P-B×A-A |
| 5 | Hot-row 衝突 micro-test（IDC+GCP 同時高頻更新同一批 warehouse row） | 獨立測項：Galera 是樂觀憑證複寫，跨區同 row 衝突會觸發
  `wsrep_local_cert_failures` 上升、交易被迫 rollback-retry——這是 leader-based
  架構（TiDB/CRDB/YBDB）不會出現的失敗模式，須獨立量測 abort rate/retry
  latency，不能用標準 TPC-C mix 掩蓋掉 |

情境 1/2 不進 DISTRIBUTED-DB-SCORING.md 主表（那是分層拆解開銷用的診斷數據），
只有情境 3/4 對照 TiDB P-A×A-S / P-B×A-A 正式數字進主表。情境 5 獨立成一個
新的比較項目（Galera 特有的樂觀複寫衝突特徵），不與 TiDB 的悲觀鎖模式直接
比大小，而是各自說明各自的衝突處理機制與代價。

## Stage 4 — Teardown + 更新 DISTRIBUTED-DB-SCORING.md

Stage 3 全部完成、數字經人工覆核後才動評分表：

- §2.1 MySQL 群組表格填入 Galera 實測數字
- §3.x 星等改為 Galera vs TiDB 2-way 比較（比照現有 YBDB vs CRDB 2-way 模式）
- §4.1 補上 MySQL 群組加權總分
- §5.1 補上 MySQL 群組結論
- 明確標註：Galera 的 P-A/P-B 是 client routing profile，不是 server-side
  placement policy（F-009 metadata 來源），避免讀者誤解成跟 TiDB 同款機制

## Stage 5 — Galera 專屬 chaos/failover 設計（獨立於既有 3DB F1-C4 框架）

**明確不直接套用既有 leader-based F1（leader kill）/ C4（leader-follower 對照）
框架**——Galera 沒有 leader 可以 kill，也沒有 follower 可以對照（每個節點都是
對等的 writer）。需要獨立設計的故障情境（本輪不實作，只列出設計方向）：

- **節點 kill（非 leader 概念，任一節點）**：kill 一個 IDC 節點 vs kill 一個
  GCP 節點，觀察 client 端行為差異（wsrep_cluster_size 降到 5、quorum 是否
  維持、in-flight 交易處理）
- **Split-brain / quorum loss**：kill 到只剩 3 台（quorum 邊界，6 節點 majority
  = 4），驗證 Galera 的 quorum 演算法是否正確拒絕繼續接受寫入（避免真正
  split-brain）
- **雙寫衝突風暴**：P-B×A-A 情境下人為製造高衝突率負載，觀察
  `wsrep_local_cert_failures`/`wsrep_local_bf_aborts` 飆升時的降級行為（這是
  Galera 特有、TiDB/CRDB/YBDB 用悲觀鎖或 leader 序列化寫入所以不會出現的
  故障模式）
- **跨區網路分斷（GCP 3 台整體失聯）**：驗證剩餘 IDC 3 台（majority）能否
  繼續服務，GCP 3 台恢復連線後能否自動 IST/SST 追上而不需要人工介入

## 尚待人工決策的項目

- Stage 1 是否現在就開始執行（需要使用者明確核准部署）
- Stage 3 情境 1/2（wsrep-off / IDC-3-node）是否值得投入時間跑，或是否可以
  用文獻/官方 benchmark 數字替代（避免重複造輪子）
- Stage 5 的具體故障注入時間窗/量測指標，需要比照 chaos_48injection_campaign
  的既有命名慣例與 3 分鐘注入上限規範重新設計，不是簡單套用 3DB 現有腳本
