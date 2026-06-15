-- YugabyteDB placement P-A — leader majority in IDC, GCP follower-only.
-- Reference:
--   phase-crossregion/topology/P-A.md
--   phase-crossregion/decisions-2026-06-08.md Q9
--   YugabyteDB 2025.2 doc: CREATE TABLESPACE ... WITH (replica_placement = '{...}')
--                          (Tablespaces / Row-level geo-partitioning)
--
-- Cluster: yugabyte-vm6 (3 IDC + 3 GCP); RF=3.
-- yb-tserver 啟動時帶 placement_cloud=104,placement_region=idc|gcp,placement_zone=<zone>
-- (per ansible/playbooks/yugabyte-vm6.yml Play 3)
--
-- Apply order (B0-3 two-stage, mirror tidb/placement-p-a.sql):
--   Stage 1 (deploy-time)   : CREATE TABLESPACE ts_p_a            <- "-- tpcc database 套用" 上半段
--   Stage 2 (post-prepare)  : ALTER TABLE ... SET TABLESPACE       <- "-- tpcc database 套用" 下半段
--                             (tests/common/prepare.sh 建完 tpcc tables 後才執行)
--
-- P-A semantics (YBDB):
--   replica_placement: 3 副本 = 2 in IDC (region=idc, zone=vlan241) + 1 in GCP (region=gcp, zone=asia-east1-a)
--   leader_preference=1 給 IDC zone -> leader 集中 IDC (= P-A.md "LEADER preferred @ IDC")
--   raft quorum = ceil(3/2) = 2 -> IDC 兩副本 ACK 即可 commit，不必等 GCP follower (per P-A.md 屬性)

DROP TABLESPACE IF EXISTS ts_p_a;

CREATE TABLESPACE ts_p_a WITH (
  replica_placement = '{
    "num_replicas": 3,
    "placement_blocks": [
      {"cloud": "104", "region": "idc", "zone": "vlan241",      "min_num_replicas": 2, "leader_preference": 1},
      {"cloud": "104", "region": "gcp", "zone": "asia-east1-a", "min_num_replicas": 1, "leader_preference": 2}
    ]
  }'
);

-- tpcc database 套用 (deploy-time 不執行；由 tests/common/prepare.sh 跑完建 tpcc tables 後執行)
-- 9 TPCC tables 顯式 SET TABLESPACE（避免 inheritance corner case；對齊 tests/tidb/placement-p-a.sql 行 28-37）
ALTER TABLE tpcc.warehouse  SET TABLESPACE ts_p_a;
ALTER TABLE tpcc.district   SET TABLESPACE ts_p_a;
ALTER TABLE tpcc.customer   SET TABLESPACE ts_p_a;
ALTER TABLE tpcc.history    SET TABLESPACE ts_p_a;
ALTER TABLE tpcc.new_order  SET TABLESPACE ts_p_a;
ALTER TABLE tpcc.orders     SET TABLESPACE ts_p_a;
ALTER TABLE tpcc.order_line SET TABLESPACE ts_p_a;
ALTER TABLE tpcc.item       SET TABLESPACE ts_p_a;
ALTER TABLE tpcc.stock      SET TABLESPACE ts_p_a;

-- Verify tablespace placement (dry-run-confirm gate 解析；輸出 pg_tablespace 系統表)
SELECT spcname, spcoptions FROM pg_tablespace WHERE spcname = 'ts_p_a';
