-- TiDB placement P-B — cross-region active-active leader spread.
-- Reference:
--   phase-crossregion/topology/P-B.md
--   phase-crossregion/decisions-2026-06-08.md Q9
--
-- Cluster: tpcc-tidb-vm6 (3 IDC + 3 GCP); RF=3.
-- PD location-labels = ["region","zone"]; tikv labels region=idc/gcp set by deploy playbook.
--
-- Apply order:
--   1. CREATE PLACEMENT POLICY p_b_leader_idc / p_b_leader_gcp
--   2. ALTER DATABASE tpcc + tables（依 table 分派兩個 policy 之一）
--   3. SELECT verify
--
-- 套用點 (per Q9): P-A → P-B 切換時，先 DROP p_a_idc_majority 再 CREATE 本檔兩個 policy。
-- 2026-07-27：改為雙 policy 設計，見下方套用區塊註解說明原因。

SET @@global.tidb_enable_alter_placement = 1;

DROP PLACEMENT POLICY IF EXISTS p_b_spread;
DROP PLACEMENT POLICY IF EXISTS p_b_leader_idc;
DROP PLACEMENT POLICY IF EXISTS p_b_leader_gcp;

-- 2026-07-27 第一次修正：原本的 list-form CONSTRAINTS="[+region=idc,+region=gcp]"
-- + FOLLOWERS=2 組合在 P-B smoke dry-run 實測炸開——ERROR 1105 (HY000):
-- invalid label constraints format ... cannot unmarshal !!seq into
-- map[string]int。list form 是「每個 replica 都必須同時滿足全部列出的
-- constraint」（AND 語意），[+region=idc,+region=gcp] 要求單一 store 同時掛
-- idc 與 gcp 兩個 region label 本就不可能滿足；改用官方文件的 dictionary
-- form（per-label 各自指定 replica 數）修好了語法，但只解決 replica/voter
-- 分佈——SHOW PLACEMENT 確認 Scheduling_State=SCHEDULED，voter 確實 2:1
-- 落在 idc:gcp。
--
-- 2026-07-27 第二次修正（設計層級缺口）：CONSTRAINTS-only（不含
-- PRIMARY_REGION/LEADER_CONSTRAINTS）完全不影響 leader 選在哪——smoke 實測
-- 19 個 leader 全部留在 IDC（DDL 從 172.24.40.32 下的，leader 天生留在
-- 建表當下所在 region，PD 不會主動搬移），prepare.sh 的 P-B leader-spread
-- gate（idc 30-70%）fail-closed。TiDB 官方文件證實：**單一 policy 無法表達
-- 「leader 跨兩區平衡分散」**——PRIMARY_REGION 是單一值，只能把 leader 釘死
-- 在一個 region。唯一文件記載作法：不同 table 掛不同 policy（各自不同
-- PRIMARY_REGION），讓 leader 在 database 內部呈現混合分布。
--
-- 9 個 TPCC table 拆兩組（5:4，粗略對齊 gate 的 30-70% 窗口；TiDB 對每個
-- table 通常切成 ~2 region，故預期 region-leader 層級比例落在 idc ~50-60%）：
--   p_b_leader_idc（leader 偏好 IDC）：warehouse, district, customer,
--                                      history, item
--   p_b_leader_gcp（leader 偏好 GCP）：new_order, orders, order_line, stock
-- 兩者皆 REGIONS='idc,gcp' + FOLLOWERS=2（RF=3，voter 兩區都有），只有
-- PRIMARY_REGION 不同；不用 SCHEDULE='MAJORITY_IN_PRIMARY'（那是 P-A 的
-- 「多數留 IDC」語意，P-B 只要 leader 偏好，不要求 replica majority）。
CREATE PLACEMENT POLICY p_b_leader_idc
  PRIMARY_REGION = "idc"
  REGIONS        = "idc,gcp"
  FOLLOWERS      = 2;

CREATE PLACEMENT POLICY p_b_leader_gcp
  PRIMARY_REGION = "gcp"
  REGIONS        = "idc,gcp"
  FOLLOWERS      = 2;

-- tpcc database 套用 (deploy-time DB 由 prepare.sh 建立；此 SQL 假設 DB tpcc 存在)
-- 2026-07-27 補：此標記行原本從缺——run-vm6-suite.sh 的 placement watcher
-- 靠 awk '/^-- tpcc database 套用/{exit}1' 切出 deploy-time 只跑 CREATE POLICY
-- 段；沒有這行會讓 deploy-time 就嘗試對尚未存在的 tpcc 表 ALTER，補齊對齊
-- placement-p-a.sql 慣例。
ALTER DATABASE tpcc PLACEMENT POLICY = `p_b_leader_idc`;

ALTER TABLE tpcc.warehouse  PLACEMENT POLICY = `p_b_leader_idc`;
ALTER TABLE tpcc.district   PLACEMENT POLICY = `p_b_leader_idc`;
ALTER TABLE tpcc.customer   PLACEMENT POLICY = `p_b_leader_idc`;
ALTER TABLE tpcc.history    PLACEMENT POLICY = `p_b_leader_idc`;
ALTER TABLE tpcc.item       PLACEMENT POLICY = `p_b_leader_idc`;
ALTER TABLE tpcc.new_order  PLACEMENT POLICY = `p_b_leader_gcp`;
ALTER TABLE tpcc.orders     PLACEMENT POLICY = `p_b_leader_gcp`;
ALTER TABLE tpcc.order_line PLACEMENT POLICY = `p_b_leader_gcp`;
ALTER TABLE tpcc.stock      PLACEMENT POLICY = `p_b_leader_gcp`;

SHOW PLACEMENT FOR DATABASE tpcc;
