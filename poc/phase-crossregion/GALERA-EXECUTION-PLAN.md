# Galera (Percona XtraDB Cluster 8.4) 執行計畫

狀態（2026-08-13 更新）：**Stage 0（靜態修正）、Stage 1（部署）、Stage 2（W=4
smoke）、Stage 3 情境 3/4（跨區 P-A×A-S、P-B×A-A 的 W=128 正式量測）、以及
§2.1/§3.2 同拓樸 `vm-1node`/`vm-3node-haproxy-3s3r` 的 W=128 正式量測已完成並
回填 `results/x-cross/` 與 `results/galera-tc1/`；環境已 teardown。** **MySQL
相容群組加權評分（§2.1/§4.1）已完成 #3/#4/#5（50% 權重），仍缺 #1/#6/#7/#8
（相容性/chaos-failover/PITR/Online DDL，合計 40% 權重）**——詳見
`DISTRIBUTED-DB-SCORING.md` §2.1/§3.2/§4.1/§5.1。

**2026-08-13 設計決策**：§2.1 的 #3/#4/#5 原規劃比照 §7（`S-PXC`，wsrep-off
control + single-writer + multi-writer 三個 cell）的完整設計，但實際執行時
改採**簡化版**——直接沿用 TiDB 既有的 `vm-1node`/`vm-3node-haproxy-3s3r` 命名與
拓樸，只跑 2 個 cell（無 wsrep-off control、無獨立 single-writer cell），
`vm-3node-haproxy-3s3r` 的 HAProxy round-robin 天生就是 multi-writer，等同
覆蓋 §7 的 multi-writer cell，但**沒有** wsrep-off（無法拆解「複寫本身成本」
vs「certification 衝突成本」）與 single-writer（無法對照「保守單寫」的
scaling 表現）兩個對照組——這兩者仍是本節下方「尚待人工決策的項目」。
對照文件：`DISTRIBUTED-DB-SCORING.md` §2.1/§3.6/§4.1/§5.1（MySQL 相容群組：
Percona XtraDB Cluster 8.4／PXC／Galera vs TiDB）。

本文件回應 2026-08-11 Codex review（`/tmp/pxc-fix`）§4 要求，記錄從目前狀態到
產出可比較評分數字的完整分期執行路徑；2026-08-12 依 Codex 二次 audit
（`/tmp/mysql-fix`）修正本節狀態描述過期問題。

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

## Stage 1 — 首次部署 + 基本健康檢查（已完成，2026-08-11/12）

1. ✅ `make phase-galera-deploy`（6 節點 ansible-playbook apply）——實測歷經
   9 次迭代才成功，過程中發現並修正 5 個未在 Stage 0 靜態檢查抓到的根因問題：
   PXC repo/module preflight 仍不足（`pxc-84-lts` репо 需另外 enable `pxc-84-lts`
   xtrabackup 子repo）、自訂 wsrep 埠未生效（`/etc/my.cnf.d/` 未被此套件
   include，須直接 append 進 `/etc/my.cnf`）、SST 帳號驗證失敗（`wsrep_sst_auth`
   須放 `[sst]` section 而非 `[mysqld]`）、`pxc_strict_mode=ENFORCING` 擋掉
   TPC-C `history` 表（標準 schema 無 explicit PK）、bootstrap 節點永久佔用
   `mysql@bootstrap.service`（需手動切換回 `mysql.service`）。
2. ✅ 逐台驗證通過：`wsrep_cluster_size=6`、`wsrep_cluster_status=Primary`、
   `wsrep_ready=ON`、`wsrep_local_state_comment=Synced`、6 台 `wsrep_cluster_state_uuid`
   一致。
3. SST 實際耗時：本次 6 台皆為全新初始化（無既有資料），SST 負載極小，未能
   反映 W=128 真實資料量下的 SST 耗時；F-006 的 timeout pending runtime
   validation 標記**仍未收斂**，留待未來需要重新 SST（如節點復原）時實測。
4. semanage port / firewalld preflight 在此環境下皆無實際作用（`getenforce`
   回報 SELinux 為 permissive/disabled，`systemctl is-active firewalld` 回報
   inactive）——F-007 的 fail-safe 設計正確生效（未強制假設兩者存在），但
   未實際驗證「兩者皆啟用」情境下的行為。

## Stage 2 — P-A×A-S / P-B×A-A smoke（W=4，已完成，2026-08-11/12）

1. ✅ `make phase-galera-smoke`（P-A×A-S）：gate-isolation / prepare / run /
   collect / gcp-replica-gate 全部 PASS，`galera_routing_profile=G-SW-IDC`。
2. ✅ `make phase-galera-aa-smoke`（P-B×A-A）：首次嘗試因 `run-vm6-aa.sh` 預設
   走 IAP tunnel（`localhost:12215`）而非直連 GCP 而失敗，修正
   `win-galera-w128.sh` 補上與 `_aa_smoke_recipe` 一致的直連覆寫後成功。
3. ✅ summary.json 格式與 tidb 一致，已用於 §3.6 引用。

## Stage 3 — W=128 正式量測

| # | 情境 | 狀態 | 備註 |
|---|------|------|------|
| 1 | 單機 wsrep-off control | ❌ 未執行 | 比照 §7 `S-PXC` 設計；2026-08-13 決策改跑簡化版（見上方設計決策），不含此對照組 |
| 2 | IDC-3-node 單寫 | ❌ 未執行 | 同上；`vm-3node-haproxy-3s3r` 天生是 multi-writer，沒有獨立測 single-writer |
| 2b | **`vm-1node` 單節點（簡化版，取代 #1/#2 對照組）** | ✅ **已完成**（2026-08-13） | 見 `results/galera-tc1/S-BASE/vm-1node-rc/galera-vm-1node-rc-20260813T073744+0800/`；DISTRIBUTED-DB-SCORING.md §3.2.1；tpmC_mean 35,523.8/53,791.9/51,384.2/51,527.8（t=16/32/64/128），全部 0% error，round range/mean 1.6%~8.4% |
| 2c | **`vm-3node-haproxy-3s3r` multi-writer（簡化版，覆蓋 §7 multi-writer cell）** | ✅ **已完成**（2026-08-13） | 見 `results/galera-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/galera-vm-3node-haproxy-3s3r-rc-20260813T112044+0800/`；DISTRIBUTED-DB-SCORING.md §3.2.2/§3.2.3；vs vm-1node **0.49×（負向擴展）**，round range/mean 34.5%~117.5%，唯一非零 error rate（0.037% all_txn）；`wsrep_local_cert_failures=234`／`bf_aborts=265`（post-run 單點 snapshot） |
| 3 | 6-node 跨區單寫（P-A×A-S） | ✅ **已完成**（2026-08-11） | 見 `results/x-cross/smoke/early-runs/20260812T132801+0800/galera-vm-6node-P-A-rc-20260811T201242+0800/`；DISTRIBUTED-DB-SCORING.md §3.6.1 |
| 4 | 6-node 跨區雙寫（P-B×A-A） | ✅ **已完成，但有 lineage caveat**（2026-08-12） | 沿用 P-A 的 prepare dataset，非獨立 prepare/gate/collect suite；見 `results/x-cross/README.md` 的 ⚠ 說明；DISTRIBUTED-DB-SCORING.md §3.6.2 |
| 5 | Hot-row 衝突 micro-test | ❌ 未執行 | P-B×A-A 的 PAYMENT 交易已觀測到 81.5% 失敗率（見 §3.6.2），方向上與 hot-row 衝突假說相容；`vm-3node-haproxy-3s3r`（#2c）也觀測到 certification 衝突（cert_failures=234），但同樣**未做獨立設計的 micro-test 與逐輪 wsrep counter delta**，不構成根因證實 |

情境 3/4 已對照 TiDB P-A×A-S / P-B×A-A 正式數字進 DISTRIBUTED-DB-SCORING.md
§3.6（**不計入 §2.1 加權評分**，見該節「狀態說明」）。情境 1/2/5 仍待執行；
情境 5 若要做，需獨立設計（不能沿用標準 TPC-C mix，需針對少量 warehouse 高頻
並發更新以放大衝突率，並同步擷取 workload 前後的 `wsrep_local_cert_failures`／
`wsrep_local_bf_aborts` delta，才能把 §3.6.2 目前「型態相容但根因未證實」的
PAYMENT 高失敗率觀察，收斂成可證實的因果結論）。

## Stage 4 — Teardown + 更新 DISTRIBUTED-DB-SCORING.md（已完成，2026-08-12）

- ✅ Teardown：`terraform destroy` 確認 IDC/GCP 兩邊 state 皆清空。
- ✅ 原始 artifact 已 fetch 回本機並歸戶到 `results/x-cross/` canonical
  位置（`smoke/early-runs/20260812T132801+0800/`），SHA-256 已於
  `fetch-receipt.json` 記錄。
- ✅ DISTRIBUTED-DB-SCORING.md 新增 §3.6（PXC vs TiDB 跨區穩態吞吐量對照，
  fact/inference 分層），§4.1/§5.1 同步更新現況說明。
- ❌ **§2.1 MySQL 群組加權評分表仍未填入任何星等**——§3.6 是不同測試維度
  （跨區穩態吞吐量 vs §2.1 要求的同拓樸延遲/擴展、chaos/failover），不可
  互相替代；§4.1 加權總分仍為「待測」。
- 明確標註：Galera 的 P-A/P-B 是 client routing profile，不是 server-side
  placement policy（F-009 metadata 來源），避免讀者誤解成跟 TiDB 同款機制；
  DISTRIBUTED-DB-SCORING.md §3.6 開頭已加註「比較邊界」段落重申此點。

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

- Stage 3 情境 1/2（wsrep-off control / 保守 single-writer 對照組）是否值得
  投入時間重新部署補測——2026-08-13 已用簡化版（#2b/#2c）取得 vm-1node 與
  multi-writer 的數字並填入 §2.1/§4.1，但仍缺這兩個對照組，導致 §3.2.2 的
  0.49× 負向擴展**無法拆解**「wsrep 複寫本身開銷」vs「multi-writer certification
  衝突開銷」各佔多少（見 DISTRIBUTED-DB-SCORING.md §3.2.2 的 inference 標註）。
- Stage 3 情境 5（hot-row micro-test）與補測**逐輪**（不只 post-run 單點）
  wsrep certification counter delta，是把 §3.6.2 PAYMENT 81.5% 失敗率、以及
  #2c 觀測到的 cert_failures/bf_aborts 與 tpmC 大幅震盪（range/mean 最高
  117.5%）之間的「型態相容但根因未證實」收斂成確定結論的必要步驟，若要正式
  寫入評分依據應優先排入。
- Stage 5 的具體故障注入時間窗/量測指標，需要比照 chaos_48injection_campaign
  的既有命名慣例與 3 分鐘注入上限規範重新設計，不是簡單套用 3DB 現有腳本。
- §2.1 加權評分表已完成 #3/#4/#5（50% 權重，見上方 #2b/#2c），仍缺 #1（相容性
  20%）/#6（chaos/failover 6%，見 Stage 5）/#7（PITR 4%）/#8（Online DDL 10%）
  合計 40% 權重，才能產出完整加權總分。
