-- CockroachDB placement P-B — voter spread across IDC/GCP; lease preferences allow both sides.
-- Reference:
--   phase-crossregion/topology/P-B.md
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

ALTER DATABASE tpcc CONFIGURE ZONE USING
  num_replicas       = 3,
  constraints        = '{+region=idc: 1, +region=gcp: 1}',
  voter_constraints  = '{+region=idc: 2, +region=gcp: 1}',
  lease_preferences  = '[[+region=idc], [+region=gcp]]';

-- tpcc database 套用 (deploy-time DB 由 prepare.sh 建立；以下 per-table override 段需 tables 存在)
ALTER TABLE tpcc.warehouse  CONFIGURE ZONE USING num_replicas=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';
ALTER TABLE tpcc.district   CONFIGURE ZONE USING num_replicas=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';
ALTER TABLE tpcc.customer   CONFIGURE ZONE USING num_replicas=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';
ALTER TABLE tpcc.history    CONFIGURE ZONE USING num_replicas=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';
ALTER TABLE tpcc.new_order  CONFIGURE ZONE USING num_replicas=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';
ALTER TABLE tpcc.orders     CONFIGURE ZONE USING num_replicas=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';
ALTER TABLE tpcc.order_line CONFIGURE ZONE USING num_replicas=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';
ALTER TABLE tpcc.item       CONFIGURE ZONE USING num_replicas=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';
ALTER TABLE tpcc.stock      CONFIGURE ZONE USING num_replicas=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';

-- Verify zone config attached（後續 dry-run-confirm gate 解析）
SHOW ZONE CONFIGURATION FROM DATABASE tpcc;
