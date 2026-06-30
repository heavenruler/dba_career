-- TiDB placement P-A — leader majority in IDC, GCP follower-only.
-- Reference:
--   phase-crossregion/topology/P-A.md
--   phase-crossregion/decisions-2026-06-08.md Q9
--   1_MeetingMinutes/0630.md §5.1 (官方 PRIMARY_REGION + SCHEDULE 例)
--   https://docs.pingcap.com/zh/tidb/stable/placement-rules-in-sql
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
--
-- SCHEDULE='MAJORITY_IN_PRIMARY' 強化 P-A 語意（per 0630.md §5.1）：
--   - PRIMARY_REGION='idc' → leader 偏好 IDC（已存在）
--   - +SCHEDULE='MAJORITY_IN_PRIMARY' → 至少多數 replica（≥2/3）留 IDC，
--     非僅 leader 在 IDC
-- 這讓 P-A「IDC majority」語意對齊 §6.6 placement gate 期望（IDC ≥ 70%）。
-- 若 TiDB 版本不支援此 SCHEDULE syntax → ALTER 會 fail，fallback DDL 見下方註解。

SET @@global.tidb_enable_alter_placement = 1;

DROP PLACEMENT POLICY IF EXISTS p_a_idc_majority;

CREATE PLACEMENT POLICY p_a_idc_majority
  PRIMARY_REGION = "idc"
  REGIONS        = "idc,gcp"
  SCHEDULE       = "MAJORITY_IN_PRIMARY"
  FOLLOWERS      = 2;

-- Fallback（若 SCHEDULE syntax 在當前 TiDB 版本不支援）：
--   移除 SCHEDULE 行；leader 仍偏好 IDC，但 followers 可能落在 GCP 多於 1。
--   §6.6 placement gate 的 IDC ≥ 70% 門檻可能因 follower 分布偏差略低於目標，
--   需手動觀察 SHOW PLACEMENT 與 TIKV_REGION_PEERS leader 分布調整。

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
