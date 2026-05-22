-- YBDB pre-create TPC-C 9 tables with SPLIT INTO 1 TABLETS
-- (PoC-DESIGN §7.5.3 — vm-3node-1s1r / vm-3node-1s3r 拓樸用)
--
-- Schema 來源：go-tpc v1.0.12 tpcc/ddl.go PostgreSQL dialect
-- （MySQL/TiDB 版本用 DATETIME；PG / YB 用 TIMESTAMP；其餘共用）
-- 每張表結尾加 `SPLIT INTO 1 TABLETS` 強制鎖 1 tablet（覆寫 cluster default
-- `ysql_num_shards_per_tserver=1 × 3 tservers = 3 tablets` 預設）
--
-- 接續流程（prepare.sh）：
--   1. DROP+CREATE database tpcc;
--   2. (本檔) pre-create 9 tables with SPLIT INTO 1 TABLETS
--   3. go-tpc tpcc prepare（CREATE TABLE IF NOT EXISTS → skip 已存在的，
--      data INSERT 進已 pre-create 的 schema）

CREATE TABLE IF NOT EXISTS warehouse (
	w_id INT NOT NULL,
	w_name VARCHAR(10),
	w_street_1 VARCHAR(20),
	w_street_2 VARCHAR(20),
	w_city VARCHAR(20),
	w_state CHAR(2),
	w_zip CHAR(9),
	w_tax DECIMAL(4, 4),
	w_ytd DECIMAL(12, 2),
	PRIMARY KEY (w_id)
) SPLIT INTO 1 TABLETS;

CREATE TABLE IF NOT EXISTS district (
	d_id INT NOT NULL,
	d_w_id INT NOT NULL,
	d_name VARCHAR(10),
	d_street_1 VARCHAR(20),
	d_street_2 VARCHAR(20),
	d_city VARCHAR(20),
	d_state CHAR(2),
	d_zip CHAR(9),
	d_tax DECIMAL(4, 4),
	d_ytd DECIMAL(12, 2),
	d_next_o_id INT,
	PRIMARY KEY (d_w_id, d_id)
) SPLIT INTO 1 TABLETS;

CREATE TABLE IF NOT EXISTS customer (
	c_id INT NOT NULL,
	c_d_id INT NOT NULL,
	c_w_id INT NOT NULL,
	c_first VARCHAR(16),
	c_middle CHAR(2),
	c_last VARCHAR(16),
	c_street_1 VARCHAR(20),
	c_street_2 VARCHAR(20),
	c_city VARCHAR(20),
	c_state CHAR(2),
	c_zip CHAR(9),
	c_phone CHAR(16),
	c_since TIMESTAMP,
	c_credit CHAR(2),
	c_credit_lim DECIMAL(12, 2),
	c_discount DECIMAL(4, 4),
	c_balance DECIMAL(12, 2),
	c_ytd_payment DECIMAL(12, 2),
	c_payment_cnt INT,
	c_delivery_cnt INT,
	c_data VARCHAR(500),
	PRIMARY KEY (c_w_id, c_d_id, c_id)
) SPLIT INTO 1 TABLETS;

CREATE TABLE IF NOT EXISTS history (
	h_c_id INT NOT NULL,
	h_c_d_id INT NOT NULL,
	h_c_w_id INT NOT NULL,
	h_d_id INT NOT NULL,
	h_w_id INT NOT NULL,
	h_date TIMESTAMP,
	h_amount DECIMAL(6, 2),
	h_data VARCHAR(24)
) SPLIT INTO 1 TABLETS;

CREATE TABLE IF NOT EXISTS new_order (
	no_o_id INT NOT NULL,
	no_d_id INT NOT NULL,
	no_w_id INT NOT NULL,
	PRIMARY KEY (no_w_id, no_d_id, no_o_id)
) SPLIT INTO 1 TABLETS;

CREATE TABLE IF NOT EXISTS orders (
	o_id INT NOT NULL,
	o_d_id INT NOT NULL,
	o_w_id INT NOT NULL,
	o_c_id INT,
	o_entry_d TIMESTAMP,
	o_carrier_id INT,
	o_ol_cnt INT,
	o_all_local INT,
	PRIMARY KEY (o_w_id, o_d_id, o_id)
) SPLIT INTO 1 TABLETS;

CREATE TABLE IF NOT EXISTS order_line (
	ol_o_id INT NOT NULL,
	ol_d_id INT NOT NULL,
	ol_w_id INT NOT NULL,
	ol_number INT NOT NULL,
	ol_i_id INT NOT NULL,
	ol_supply_w_id INT,
	ol_delivery_d TIMESTAMP,
	ol_quantity INT,
	ol_amount DECIMAL(6, 2),
	ol_dist_info CHAR(24),
	PRIMARY KEY (ol_w_id, ol_d_id, ol_o_id, ol_number)
) SPLIT INTO 1 TABLETS;

CREATE TABLE IF NOT EXISTS stock (
	s_i_id INT NOT NULL,
	s_w_id INT NOT NULL,
	s_quantity INT,
	s_dist_01 CHAR(24),
	s_dist_02 CHAR(24),
	s_dist_03 CHAR(24),
	s_dist_04 CHAR(24),
	s_dist_05 CHAR(24),
	s_dist_06 CHAR(24),
	s_dist_07 CHAR(24),
	s_dist_08 CHAR(24),
	s_dist_09 CHAR(24),
	s_dist_10 CHAR(24),
	s_ytd INT,
	s_order_cnt INT,
	s_remote_cnt INT,
	s_data VARCHAR(50),
	PRIMARY KEY (s_w_id, s_i_id)
) SPLIT INTO 1 TABLETS;

CREATE TABLE IF NOT EXISTS item (
	i_id INT NOT NULL,
	i_im_id INT,
	i_name VARCHAR(24),
	i_price DECIMAL(5, 2),
	i_data VARCHAR(50),
	PRIMARY KEY (i_id)
) SPLIT INTO 1 TABLETS;
