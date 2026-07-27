-- YugabyteDB placement P-B — cross-region voter spread, leader 跨區混合分佈.
-- Reference:
--   phase-crossregion/topology/P-B.md
--   phase-crossregion/decisions-2026-06-08.md Q9
--   YugabyteDB 2025.2 doc: CREATE TABLESPACE ... WITH (replica_placement = '{...}')
--
-- Cluster: yugabyte-vm6 (3 IDC + 3 GCP); RF=3.
-- 基礎 replica 分佈（2 idc + 1 gcp）已由 Makefile phase4-ybdb-fix6n 的
-- universe 層 modify_placement_info 設定好，本檔只負責 leader 混合分佈
-- （universe 層設定無法表達「部分 tablet leader 在 idc、部分在 gcp」，
-- 只能全域 pin 一個 preferred zone 或完全不 pin）。
--
-- 2026-07-27 第一版（已刪除）教訓：原本假設 GCP 有兩個獨立 zone
-- （asia-east1-a / asia-east1-b），但 ansible/playbooks/yugabyte-vm6.yml
-- Play 3 實際把所有 GCP tserver 攤平成單一 zone="asia-east1"；且 post-prepare
-- 的 ALTER TABLE SET TABLESPACE 從未被任何腳本執行（宣稱由 prepare.sh 執行
-- 但其實沒有）。P-B smoke dry-run 實測：不做任何 per-table 差異化時，
-- YBDB load balancer 把 tablet leader 全部集中單一 region（本次是 100% GCP，
-- 0% IDC），與 TiDB 遇到的「CONSTRAINTS-only 不影響 leader 選在哪」同一種
-- 設計缺口——leader_preference 是優先順序（priority），不是機率混合，
-- 全庫套同一組設定只會導致 leader 全部倒向優先區，不會自然分成 30/70。
--
-- 本版修正：比照 tests/tidb/placement-p-b.sql 的雙 policy 設計，改用
-- 兩個 tablespace，9 個 TPCC table 拆 5:4 兩組（同 TiDB 分組，方便跨庫比對）：
--   ts_p_b_leader_idc（leader_preference: idc=1, gcp=2）：
--     warehouse, district, customer, history, item
--   ts_p_b_leader_gcp（leader_preference: gcp=1, idc=2）：
--     new_order, orders, order_line, stock
-- 兩個 tablespace 的 replica_placement 皆為 2 idc + 1 gcp（RF=3，與
-- modify_placement_info 的 universe 預設一致，只有 leader_preference 方向不同，
-- 不影響 voter 分佈）。GCP zone 統一用實際生效的 "asia-east1"（非 -a/-b 分裂）。
--
-- Apply order (two-stage)：
--   Stage 1 (deploy-time)  : CREATE TABLESPACE ts_p_b_leader_idc / ts_p_b_leader_gcp
--                            <- "-- tpcc database 套用" 上半段
--   Stage 2 (post-prepare) : ALTER TABLE ... SET TABLESPACE
--                            <- "-- tpcc database 套用" 下半段，由
--                            phase-crossregion/scripts/run-vm6-suite.sh 新增的
--                            ybdb placement watcher（比照既有 tidb/crdb 分支）
--                            在 prepare 建完 tpcc tables 後執行（本次一併補上，
--                            舊版從未接線）。

DROP TABLESPACE IF EXISTS ts_p_b;
DROP TABLESPACE IF EXISTS ts_p_b_leader_idc;
DROP TABLESPACE IF EXISTS ts_p_b_leader_gcp;

CREATE TABLESPACE ts_p_b_leader_idc WITH (
  replica_placement = '{
    "num_replicas": 3,
    "placement_blocks": [
      {"cloud": "104", "region": "idc", "zone": "vlan241",    "min_num_replicas": 2, "leader_preference": 1},
      {"cloud": "104", "region": "gcp", "zone": "asia-east1", "min_num_replicas": 1, "leader_preference": 2}
    ]
  }'
);

CREATE TABLESPACE ts_p_b_leader_gcp WITH (
  replica_placement = '{
    "num_replicas": 3,
    "placement_blocks": [
      {"cloud": "104", "region": "gcp", "zone": "asia-east1", "min_num_replicas": 1, "leader_preference": 1},
      {"cloud": "104", "region": "idc", "zone": "vlan241",    "min_num_replicas": 2, "leader_preference": 2}
    ]
  }'
);

-- tpcc database 套用 (deploy-time 不執行；由 run-vm6-suite.sh 的 ybdb placement
-- watcher 在 prepare 建完 tpcc tables 後才執行；標記行本身供 awk 切段用)
ALTER TABLE tpcc.warehouse  SET TABLESPACE ts_p_b_leader_idc;
ALTER TABLE tpcc.district   SET TABLESPACE ts_p_b_leader_idc;
ALTER TABLE tpcc.customer   SET TABLESPACE ts_p_b_leader_idc;
ALTER TABLE tpcc.history    SET TABLESPACE ts_p_b_leader_idc;
ALTER TABLE tpcc.item       SET TABLESPACE ts_p_b_leader_idc;
ALTER TABLE tpcc.new_order  SET TABLESPACE ts_p_b_leader_gcp;
ALTER TABLE tpcc.orders     SET TABLESPACE ts_p_b_leader_gcp;
ALTER TABLE tpcc.order_line SET TABLESPACE ts_p_b_leader_gcp;
ALTER TABLE tpcc.stock      SET TABLESPACE ts_p_b_leader_gcp;

-- Verify tablespace placement (dry-run-confirm gate 解析；輸出 pg_tablespace 系統表)
SELECT spcname, spcoptions FROM pg_tablespace WHERE spcname IN ('ts_p_b_leader_idc', 'ts_p_b_leader_gcp');
