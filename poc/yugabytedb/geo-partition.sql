DROP TABLE IF EXISTS demo_geo.bank_txn CASCADE;
DROP SCHEMA IF EXISTS demo_geo CASCADE;
DROP TABLESPACE IF EXISTS ts_az1;
DROP TABLESPACE IF EXISTS ts_az2;
DROP TABLESPACE IF EXISTS ts_az3;

CREATE TABLESPACE ts_az1 WITH (
  replica_placement='{"num_replicas":1,"placement_blocks":[{"cloud":"cloud1","region":"region1","zone":"az1","min_num_replicas":1}]}'
);

CREATE TABLESPACE ts_az2 WITH (
  replica_placement='{"num_replicas":1,"placement_blocks":[{"cloud":"cloud1","region":"region2","zone":"az2","min_num_replicas":1}]}'
);

CREATE TABLESPACE ts_az3 WITH (
  replica_placement='{"num_replicas":1,"placement_blocks":[{"cloud":"cloud1","region":"region3","zone":"az3","min_num_replicas":1}]}'
);

CREATE SCHEMA demo_geo;

CREATE TABLE demo_geo.bank_txn (
  user_id bigint NOT NULL,
  account_id bigint NOT NULL,
  geo_partition text NOT NULL,
  amount numeric(12,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id HASH, account_id, geo_partition)
) PARTITION BY LIST (geo_partition);

CREATE TABLE demo_geo.bank_txn_az1 PARTITION OF demo_geo.bank_txn
  FOR VALUES IN ('AZ1') TABLESPACE ts_az1;

CREATE TABLE demo_geo.bank_txn_az2 PARTITION OF demo_geo.bank_txn
  FOR VALUES IN ('AZ2') TABLESPACE ts_az2;

CREATE TABLE demo_geo.bank_txn_az3 PARTITION OF demo_geo.bank_txn
  FOR VALUES IN ('AZ3') TABLESPACE ts_az3;

INSERT INTO demo_geo.bank_txn (user_id, account_id, geo_partition, amount)
VALUES
  (101, 10001, 'AZ1', 120.50),
  (201, 20001, 'AZ2', 1000.00),
  (301, 30001, 'AZ3', 105.25);

SELECT 'demo_geo.bank_txn' AS table_name,
       p.num_tablets
FROM yb_table_properties('demo_geo.bank_txn'::regclass) AS p;

SELECT c.relname AS partition_name,
       COALESCE(t.spcname, 'pg_default') AS tablespace_name
FROM pg_class c
LEFT JOIN pg_tablespace t ON t.oid = c.reltablespace
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'demo_geo'
  AND c.relname IN ('bank_txn_az1', 'bank_txn_az2', 'bank_txn_az3')
ORDER BY c.relname;

SELECT geo_partition, count(*) AS rows, sum(amount) AS total_amount
FROM demo_geo.bank_txn
GROUP BY geo_partition
ORDER BY geo_partition;

SELECT *
FROM demo_geo.bank_txn
ORDER BY geo_partition, user_id
LIMIT 5;
