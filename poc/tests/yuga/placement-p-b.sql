-- YugabyteDB placement P-B — cross-region voter spread, leader 不集中單區.
-- Reference:
--   phase-crossregion/topology/P-B.md
--   phase-crossregion/decisions-2026-06-08.md Q9
--   YugabyteDB 2025.2 doc: CREATE TABLESPACE ... WITH (replica_placement = '{...}')
--
-- Cluster: yugabyte-vm6 (3 IDC + 3 GCP); RF=3.
-- yb-tserver 啟動時帶 placement_cloud=104,placement_region=idc|gcp,placement_zone=<zone>
-- (per ansible/playbooks/yugabyte-vm6.yml Play 3)
--
-- P-B semantics (YBDB) — RF=3 constraint：
--   sum(min_num_replicas) <= num_replicas (=3); 平均 IDC=2 + GCP=2 = 4 > 3 不合法。
--   選擇：IDC zone=vlan241: min_num_replicas=1,
--         GCP zone=asia-east1-a: min_num_replicas=1,
--         GCP zone=asia-east1-b: min_num_replicas=1
--   -> 3 placement_blocks 每塊 1 副本，total 3 副本 (符合 RF=3 + 散區).
--   leader_preference 兩端對等（IDC + GCP 都給 1）-> YB master 自動 balance leader
--   (對齊 P-B.md "Leader 散區" + "WAN 互擾顯性"屬性).
--
--   NOTE: P-B.md ASCII 圖描 1-IDC + 1-GCP + 1-arbiter 形態，但 YBDB tablespace 無 arbiter 概念；
--         用 3 placement_blocks 等價表達 RF=3 散三區，leader 不集中 (Q9 P-B 「leader 不偏好任一區」
--         語意對齊).

DROP TABLESPACE IF EXISTS ts_p_b;

CREATE TABLESPACE ts_p_b WITH (
  replica_placement = '{
    "num_replicas": 3,
    "placement_blocks": [
      {"cloud": "104", "region": "idc", "zone": "vlan241",      "min_num_replicas": 1, "leader_preference": 1},
      {"cloud": "104", "region": "gcp", "zone": "asia-east1-a", "min_num_replicas": 1, "leader_preference": 1},
      {"cloud": "104", "region": "gcp", "zone": "asia-east1-b", "min_num_replicas": 1, "leader_preference": 2}
    ]
  }'
);

-- tpcc database 套用 (deploy-time 不執行；由 tests/common/prepare.sh 跑完建 tpcc tables 後執行)
-- 9 TPCC tables 顯式 SET TABLESPACE（對齊 tests/tidb/placement-p-b.sql 行 28-36）
ALTER TABLE tpcc.warehouse  SET TABLESPACE ts_p_b;
ALTER TABLE tpcc.district   SET TABLESPACE ts_p_b;
ALTER TABLE tpcc.customer   SET TABLESPACE ts_p_b;
ALTER TABLE tpcc.history    SET TABLESPACE ts_p_b;
ALTER TABLE tpcc.new_order  SET TABLESPACE ts_p_b;
ALTER TABLE tpcc.orders     SET TABLESPACE ts_p_b;
ALTER TABLE tpcc.order_line SET TABLESPACE ts_p_b;
ALTER TABLE tpcc.item       SET TABLESPACE ts_p_b;
ALTER TABLE tpcc.stock      SET TABLESPACE ts_p_b;

-- Verify tablespace placement (dry-run-confirm gate 解析；輸出 pg_tablespace 系統表)
SELECT spcname, spcoptions FROM pg_tablespace WHERE spcname = 'ts_p_b';
