-- CockroachDB placement P-A — voter majority in IDC, leaseholder pinned to IDC.
-- Reference:
--   phase-crossregion/topology/P-A.md
--   phase-crossregion/decisions-2026-06-08.md Q9
--   CockroachDB v26.2 doc: CONFIGURE ZONE USING constraints / voter_constraints / lease_preferences
--
-- Cluster: cockroach-vm6 (3 IDC + 3 GCP); replication factor = 3 voters.
-- cockroach start 啟動時帶 --locality=region=idc|gcp,zone=<zone>（per ansible/playbooks/cockroach-vm6.yml Play 3）
--
-- Apply order:
--   1. DATABASE-level CONFIGURE ZONE (本 SQL 前段；deploy 階段套用)
--   2. ALTER TABLE per-table CONFIGURE ZONE (本 SQL 後段；prepare 完成 tpcc tables 後才套，由 run-vm6-suite.sh post-prepare 觸發)
--   3. SELECT verify (idempotent re-apply safe)
--
-- 套用點 (per Q9 / REPLAN-2026-06-15 §0 B0-3):
--   - deploy: 本 SQL 前段（CONFIGURE ZONE on DATABASE）
--   - post-prepare: 本 SQL 後段（per-table ALTER TABLE）

-- 2026-07-13 修正：constraints 原為 list form '[+region=idc]'＝「全部副本」鎖 IDC，
-- 直接與 voter_constraints 的 +region=gcp:1 矛盾——allocator 以 constraints 為準，
-- 實測（w128 20260711T215200）3 voters 全落 IDC、GCP 零副本。
-- 改 counted form '{+region=idc: 2}' 只鎖 2 份，留 1 份給 GCP voter。
ALTER DATABASE tpcc CONFIGURE ZONE USING
  num_replicas       = 3,
  num_voters         = 3,
  constraints        = '{+region=idc: 2}',
  voter_constraints  = '{+region=idc: 2, +region=gcp: 1}',
  lease_preferences  = '[[+region=idc]]';

-- tpcc database 套用 (deploy-time DB 由 prepare.sh 建立；以下 per-table override 段需 tables 存在)
-- v26.2 強制 voter_constraints 必須同時設 num_voters，否則 SQLSTATE 22023
ALTER TABLE tpcc.warehouse  CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 2}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc]]';
ALTER TABLE tpcc.district   CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 2}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc]]';
ALTER TABLE tpcc.customer   CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 2}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc]]';
ALTER TABLE tpcc.history    CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 2}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc]]';
ALTER TABLE tpcc.new_order  CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 2}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc]]';
ALTER TABLE tpcc.orders     CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 2}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc]]';
ALTER TABLE tpcc.order_line CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 2}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc]]';
ALTER TABLE tpcc.item       CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 2}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc]]';
ALTER TABLE tpcc.stock      CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 2}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc]]';

-- Verify zone config attached（後續 dry-run-confirm gate 解析）
SHOW ZONE CONFIGURATION FROM DATABASE tpcc;
