-- TiDB placement P-A — leader majority in IDC, GCP follower-only.
-- Reference:
--   phase-crossregion/topology/P-A.md
--   phase-crossregion/decisions-2026-06-08.md Q9
--
-- Cluster: tpcc-tidb-vm6 (3 IDC + 3 GCP); RF=3.
-- PD location-labels = ["region","zone"]; tikv labels region=idc/gcp set by deploy playbook.
--
-- Apply order:
--   1. CREATE PLACEMENT POLICY p_a_idc_majority
--   2. ALTER DATABASE tpcc + key TPCC tables to attach policy
--   3. SELECT verify (idempotent re-apply safe)
--
-- 套用點 (per Q9): deploy completed → run before warmup/sweep (idempotent)。

SET @@global.tidb_enable_alter_placement = 1;

DROP PLACEMENT POLICY IF EXISTS p_a_idc_majority;

CREATE PLACEMENT POLICY p_a_idc_majority
  PRIMARY_REGION = "idc"
  REGIONS        = "idc,gcp"
  FOLLOWERS      = 2;

-- tpcc database 套用 (deploy-time DB 由 prepare.sh 建立；此 SQL 假設 DB tpcc 存在)
ALTER DATABASE tpcc PLACEMENT POLICY = `p_a_idc_majority`;

-- 主要 TPCC tables 顯式 attach（避免 inheritance corner case）
ALTER TABLE tpcc.warehouse  PLACEMENT POLICY = `p_a_idc_majority`;
ALTER TABLE tpcc.district   PLACEMENT POLICY = `p_a_idc_majority`;
ALTER TABLE tpcc.customer   PLACEMENT POLICY = `p_a_idc_majority`;
ALTER TABLE tpcc.history    PLACEMENT POLICY = `p_a_idc_majority`;
ALTER TABLE tpcc.new_order  PLACEMENT POLICY = `p_a_idc_majority`;
ALTER TABLE tpcc.orders     PLACEMENT POLICY = `p_a_idc_majority`;
ALTER TABLE tpcc.order_line PLACEMENT POLICY = `p_a_idc_majority`;
ALTER TABLE tpcc.item       PLACEMENT POLICY = `p_a_idc_majority`;
ALTER TABLE tpcc.stock      PLACEMENT POLICY = `p_a_idc_majority`;

-- Verify policy attached（後續 dry-run-confirm gate 解析）
SHOW PLACEMENT FOR DATABASE tpcc;
