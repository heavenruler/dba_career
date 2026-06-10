-- TiDB placement P-B — cross-region active-active leader spread.
-- Reference:
--   phase-crossregion/topology/P-B.md
--   phase-crossregion/decisions-2026-06-08.md Q9
--
-- Cluster: tpcc-tidb-vm6 (3 IDC + 3 GCP); RF=3.
-- PD location-labels = ["region","zone"]; tikv labels region=idc/gcp set by deploy playbook.
--
-- Apply order:
--   1. CREATE PLACEMENT POLICY p_b_spread
--   2. ALTER DATABASE tpcc + tables
--   3. SELECT verify
--
-- 套用點 (per Q9): P-A → P-B 切換時，先 DROP p_a_idc_majority 再 CREATE p_b_spread。

SET @@global.tidb_enable_alter_placement = 1;

DROP PLACEMENT POLICY IF EXISTS p_b_spread;

-- CONSTRAINTS "[+region=idc,+region=gcp]" 跨區散 voter；FOLLOWERS=2 → RF=3 (1 leader + 2 follower)
-- 不指定 PRIMARY_REGION → leader 不偏好任一 region（PD 自動 balance）
CREATE PLACEMENT POLICY p_b_spread
  CONSTRAINTS = "[+region=idc,+region=gcp]"
  FOLLOWERS   = 2;

ALTER DATABASE tpcc PLACEMENT POLICY = `p_b_spread`;

ALTER TABLE tpcc.warehouse  PLACEMENT POLICY = `p_b_spread`;
ALTER TABLE tpcc.district   PLACEMENT POLICY = `p_b_spread`;
ALTER TABLE tpcc.customer   PLACEMENT POLICY = `p_b_spread`;
ALTER TABLE tpcc.history    PLACEMENT POLICY = `p_b_spread`;
ALTER TABLE tpcc.new_order  PLACEMENT POLICY = `p_b_spread`;
ALTER TABLE tpcc.orders     PLACEMENT POLICY = `p_b_spread`;
ALTER TABLE tpcc.order_line PLACEMENT POLICY = `p_b_spread`;
ALTER TABLE tpcc.item       PLACEMENT POLICY = `p_b_spread`;
ALTER TABLE tpcc.stock      PLACEMENT POLICY = `p_b_spread`;

SHOW PLACEMENT FOR DATABASE tpcc;
