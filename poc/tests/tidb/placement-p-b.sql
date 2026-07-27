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

-- 2026-07-27 修正：原本的 list-form CONSTRAINTS="[+region=idc,+region=gcp]"
-- + FOLLOWERS=2 組合在 P-B smoke dry-run 實測炸開——
-- ERROR 1105 (HY000): invalid label constraints format ... cannot unmarshal
-- !!seq into map[string]int。list form 是「每個 replica 都必須同時滿足全部
-- 列出的 constraint」（AND 語意），[+region=idc,+region=gcp] 要求單一 store
-- 同時掛 idc 與 gcp 兩個 region label 本就不可能滿足；正確作法是官方文件的
-- dictionary form（per-label 各自指定 replica 數，加總即為總副本數，
-- 不再需要另外的 FOLLOWERS）：2 個 replica 落 idc、1 個落 gcp，共 RF=3；
-- 不指定 PRIMARY_REGION → leader 不偏好任一 region（PD 自動 balance）。
-- 注意冒號後需留空格（"+region=idc: 2" 而非 "+region=idc:2"），否則官方文件
-- 記載會解析錯誤。
CREATE PLACEMENT POLICY p_b_spread
  CONSTRAINTS = '{"+region=idc": 2, "+region=gcp": 1}';

-- tpcc database 套用 (deploy-time DB 由 prepare.sh 建立；此 SQL 假設 DB tpcc 存在)
-- 2026-07-27 補：此標記行原本從缺——run-vm6-suite.sh 的 placement watcher
-- 靠 awk '/^-- tpcc database 套用/{exit}1' 切出 deploy-time 只跑 CREATE POLICY
-- 段；沒有這行會讓 deploy-time 就嘗試對尚未存在的 tpcc 表 ALTER，補齊對齊
-- placement-p-a.sql 慣例。
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
