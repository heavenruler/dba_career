-- CockroachDB placement P-B — voter spread across IDC/GCP; lease 跨區混合分佈.
-- Reference:
--   phase-crossregion/topology/P-B.md
--   phase-crossregion/decisions-2026-06-08.md Q9
--   CockroachDB v26.2 doc: CONFIGURE ZONE USING constraints / voter_constraints / lease_preferences
--
-- Cluster: cockroach-vm6 (3 IDC + 3 GCP); replication factor = 3 voters.
-- cockroach start 啟動時帶 --locality=region=idc|gcp,zone=<zone>（per ansible/playbooks/cockroach-vm6.yml Play 3）
--
-- 2026-07-27 修正（設計層級缺口，先於 CRDB smoke dry-run 前置修正，
-- 同款問題已在 TiDB/YBDB 實測證實）：原本 9 個 table 全部套同一組
-- lease_preferences='[[+region=idc],[+region=gcp]]'——這是「優先順序」
-- 語意（idc 優先，gcp 只是 failover），只要 idc 副本健康，全部 9 個 table
-- 的 lease 都會倒向 idc，不會自然分成 30/70（run-vm6-suite.sh 既有的
-- lease enforcer 甚至還主動把 GCP lease 搬回 IDC，強化這個單向收斂——
-- 那段是 P-A 專用邏輯，被 P-A/P-B 共用，對 P-B 完全是反效果，run-vm6-suite.sh
-- 已同步修正為依 PLACEMENT 分支）。
--
-- 比照 tests/tidb/placement-p-b.sql 的雙 policy 設計，9 個 TPCC table 拆
-- 兩組，各自用相反方向的 lease_preferences；constraints/voter_constraints
-- （2 idc + 1 gcp）維持全部 table 一致，只有 lease 偏好方向不同。
--
-- 2026-07-27 二次修正：第一版分組（warehouse/district/customer/history/item
-- → idc；new_order/orders/order_line/stock → gcp）在 YBDB 上先撞出同款問題
-- ——tests/common/prepare.sh §6.6 crdb 分支**只抽樣
-- warehouse/district/customer 這 3 個 table**（非全部 9 個），這 3 個剛好
-- 全部在同一組，抽樣結果永遠同質。CRDB 尚未實測但用同一份 prepare.sh，
-- 搶先比照 YBDB 的修法調整分組，確保抽樣 3 個 table 本身跨兩組：
--   idc 優先：warehouse, district, history, item（4 table，含抽樣中的 2 個）
--   gcp 優先：customer, new_order, orders, order_line, stock（5 table，含
--            抽樣中的 1 個）
-- 抽樣 3 個 table 預期 idc=2/3≈66.7%，落在 30-70% 窗口內。
--
-- 2026-07-27 三次修正：CRDB smoke 實測 apply 直接失敗（"apply FAILED after
-- retries"，錯誤被導到 /dev/null 沒看到，手動重跑才抓到）——
-- ERROR: could not validate zone config: when voter_constraints are set,
-- num_voters must be set as well。本檔原本每條 CONFIGURE ZONE 都設了
-- voter_constraints 但沒設 num_voters，v26.2 這裡是硬性要求（DATABASE-level
-- 那條也一樣有此問題，deploy 階段的 "best-effort" 標記把它吞掉了，沒有真的
-- 生效）。所有 3 副本都是 voter（無 non-voter），num_voters 應等於
-- num_replicas=3，補上 num_voters=3。
--
-- Apply order:
--   1. DATABASE-level CONFIGURE ZONE (本 SQL 前段；deploy 階段套用)
--   2. ALTER TABLE per-table CONFIGURE ZONE (本 SQL 後段；prepare 完成 tpcc tables 後才套，由 run-vm6-suite.sh post-prepare 觸發)
--   3. SELECT verify (idempotent re-apply safe)

ALTER DATABASE tpcc CONFIGURE ZONE USING
  num_replicas       = 3,
  num_voters         = 3,
  constraints        = '{+region=idc: 1, +region=gcp: 1}',
  voter_constraints  = '{+region=idc: 2, +region=gcp: 1}',
  lease_preferences  = '[[+region=idc], [+region=gcp]]';

-- tpcc database 套用 (deploy-time DB 由 prepare.sh 建立；以下 per-table override 段需 tables 存在)
ALTER TABLE tpcc.warehouse  CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';
ALTER TABLE tpcc.district   CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';
ALTER TABLE tpcc.history    CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';
ALTER TABLE tpcc.item       CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';
-- 2026-07-28 三次修正（W=128 正式輪實測炸開）：customer 整表分到單一
-- 方向（gcp）在 W=4 smoke 沒問題（只有 1 個 range），但 W=128 時
-- customer 有 384 萬列，CRDB 依 range_max_bytes 自動切成多個 range
-- （實測 9 個），全部繼承同一份 table 層 zone config、全部倒向同一區——
-- prepare.sh §6.6 gate 只抽樣 warehouse/district/customer 這 3 個 table，
-- warehouse/district 因資料量小恆為 1 range，customer 的 range 數量
-- 主導了抽樣結果，導致 idc=2/11=18%，跌出 30-70% 窗口（無論 customer
-- 整表分到哪一區，都會被拉到其中一個極端，不可能自然落在窗口內）。
-- 改用 PARTITION BY RANGE（依 c_w_id 攔腰切兩半，各自掛不同 zone
-- config）——已在活著的 cluster 上實測驗證可行（非 Enterprise-only
-- 限制），且與 warehouse-range 切半的精神一致，不受 auto-split 的
-- range 數量影響。
ALTER TABLE tpcc.customer PARTITION BY RANGE (c_w_id) (
  PARTITION p_idc VALUES FROM (minvalue) TO (65),
  PARTITION p_gcp VALUES FROM (65) TO (maxvalue)
);
ALTER PARTITION p_idc OF TABLE tpcc.customer CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';
ALTER PARTITION p_gcp OF TABLE tpcc.customer CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=gcp], [+region=idc]]';
ALTER TABLE tpcc.new_order  CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=gcp], [+region=idc]]';
ALTER TABLE tpcc.orders     CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=gcp], [+region=idc]]';

-- 2026-07-29 四次修正：customer 改 partition 後 §6.6 抽樣 gate（只看
-- warehouse/district/customer）過了，但緊接著撞到 gcp-replica-gate.sh
-- 的**全體 9 個 table**判準（跟 TiDB/YBDB 共用同一支腳本，非本檔專屬）
-- ——idc=10/45=22%，跌出 30-70%。查實際分佈發現 order_line（11 range）
-- 與 stock（15 range）合計 26 個、全部倒向 gcp，佔全體 45 個 range
-- 的大宗，是這兩個 table 整表分到 gcp 主導了全體比例（同一種「大表整表
-- 分單一方向」問題，這次發生在全體 9 table 判準而非抽樣 3 table）。
-- 比照 customer 的修法，order_line／stock 也改用 PARTITION BY RANGE
-- （依各自的 warehouse-id 欄位攔腰切兩半）。
ALTER TABLE tpcc.order_line PARTITION BY RANGE (ol_w_id) (
  PARTITION p_idc VALUES FROM (minvalue) TO (65),
  PARTITION p_gcp VALUES FROM (65) TO (maxvalue)
);
ALTER PARTITION p_idc OF TABLE tpcc.order_line CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';
ALTER PARTITION p_gcp OF TABLE tpcc.order_line CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=gcp], [+region=idc]]';

ALTER TABLE tpcc.stock PARTITION BY RANGE (s_w_id) (
  PARTITION p_idc VALUES FROM (minvalue) TO (65),
  PARTITION p_gcp VALUES FROM (65) TO (maxvalue)
);
ALTER PARTITION p_idc OF TABLE tpcc.stock CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=idc], [+region=gcp]]';
ALTER PARTITION p_gcp OF TABLE tpcc.stock CONFIGURE ZONE USING num_replicas=3, num_voters=3, constraints='{+region=idc: 1, +region=gcp: 1}', voter_constraints='{+region=idc: 2, +region=gcp: 1}', lease_preferences='[[+region=gcp], [+region=idc]]';

-- Verify zone config attached（後續 dry-run-confirm gate 解析）
SHOW ZONE CONFIGURATION FROM DATABASE tpcc;
