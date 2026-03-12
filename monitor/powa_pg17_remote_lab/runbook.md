# Runbook

## 目的

本文件整理本次 PoWA remote monitor PostgreSQL 17 測試環境的可重複操作 SOP。

## 環境概要

- Host OS: macOS
- Container runtime: Podman
- Repository DB: `powa-pg` on `5432`
- PoWA Web: `8888`
- Monitored PG17: `pg17-test` on `5433`
- Collector: `powa-collector`

## Step 1. 啟動 Podman machine

```bash
podman machine start
podman info
```

驗證重點：

- `podman info` 正常回應
- `podman ps` 不再出現 socket connection refused

## Step 2. 啟動 PoWA repository / web

使用既有腳本：

```bash
/Users/wn.lin/setup-powa-podman.sh
```

驗證：

```bash
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
podman logs powa-web
```

預期：

- `powa-pg` 存在
- `powa-web` 存在
- `http://127.0.0.1:8888` 可開啟

## Step 3. 啟動 PostgreSQL 17 monitored target

```bash
podman rm -f pg17-test >/dev/null 2>&1 || true

podman run -d \
  --name pg17-test \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=postgres \
  -p 5433:5432 \
  -v ~/pg17-test/data:/var/lib/postgresql/data:Z \
  -v ~/pg17-test/initdb:/docker-entrypoint-initdb.d:Z \
  docker.io/powateam/powa-archivist-17 \
  postgres \
  -c shared_preload_libraries='pg_stat_statements,powa,pg_stat_kcache,pg_qualstats,pg_wait_sampling' \
  -c track_io_timing=on
```

查看 log：

```bash
podman logs -f pg17-test
```

## Step 4. 若缺少 `powa` database，手動修復

適用於沿用舊資料目錄時。

```bash
podman exec pg17-test psql -U postgres -d postgres -c "CREATE DATABASE powa;"
```

```bash
podman exec pg17-test psql -U postgres -d powa -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements; CREATE EXTENSION IF NOT EXISTS btree_gist; CREATE EXTENSION IF NOT EXISTS powa; CREATE EXTENSION IF NOT EXISTS pg_qualstats; CREATE EXTENSION IF NOT EXISTS pg_stat_kcache; CREATE EXTENSION IF NOT EXISTS pg_wait_sampling; CREATE EXTENSION IF NOT EXISTS pg_track_settings; CREATE EXTENSION IF NOT EXISTS hypopg;"
```

```bash
podman exec pg17-test psql -U postgres -d postgres -c "DO \$role\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powa') THEN CREATE ROLE powa WITH LOGIN SUPERUSER PASSWORD 'powa123'; END IF; END \$role\$;"
```

驗證：

```bash
podman exec pg17-test psql -U postgres -d powa -c "\dx"
```

## Step 5. 在 PoWA repository 註冊 PG17

```bash
podman exec powa-pg psql -U postgres -d powa -c "
SELECT powa_register_server(
  hostname   => 'host.containers.internal',
  port       => 5433,
  alias      => 'pg17-test',
  username   => 'powa',
  password   => 'powa123',
  dbname     => 'powa',
  frequency  => 60,
  retention  => '1 day',
  extensions => '{pg_stat_kcache,pg_qualstats,pg_wait_sampling}'
);
"
```

驗證：

```bash
podman exec powa-pg psql -U postgres -d powa -c "select id, alias, hostname, port, username, dbname, frequency, retention, allow_ui_connection from powa_servers order by id;"
```

## Step 6. 啟動 collector

建立設定檔：

```bash
mkdir -p ~/powa-test/conf

cat > ~/powa-test/conf/powa-collector.conf <<'EOF'
{
  "repository": {
    "dsn": "postgresql://powa:powa123@host.containers.internal:5432/powa"
  },
  "debug": false
}
EOF
```

啟動 collector：

```bash
podman rm -f powa-collector >/dev/null 2>&1 || true

podman run -d \
  --name powa-collector \
  -v ~/powa-test/conf/powa-collector.conf:/etc/powa-collector.conf:Z \
  docker.io/powateam/powa-collector
```

驗證：

```bash
podman logs powa-collector
```

## Step 7. 進行連線測試

### 測 repository `5432`

```bash
podman run --rm -e PGPASSWORD=postgres docker.io/library/postgres:17 \
  psql -h host.containers.internal -p 5432 -U postgres -d postgres \
  -c "select version(), current_database(), current_user;"
```

### 測 monitored target `5433`

```bash
podman run --rm -e PGPASSWORD=postgres docker.io/library/postgres:17 \
  psql -h host.containers.internal -p 5433 -U postgres -d powa \
  -c "select version(), current_database(), current_user;"
```

## Step 8. 製造測試負載

```bash
podman exec pg17-test psql -U postgres -d postgres -c "create table if not exists t(id int, val text);"
podman exec pg17-test psql -U postgres -d postgres -c "insert into t select g, md5(g::text) from generate_series(1,10000) g;"
podman exec pg17-test psql -U postgres -d postgres -c "select count(*) from t where id between 1 and 5000;"
podman exec pg17-test psql -U postgres -d postgres -c "select * from t order by val limit 100;"
```

## Step 9. 查看 Web UI

```bash
open http://127.0.0.1:8888
```

登入資訊：

- user: `powa`
- password: `powa123`

## Step 10. 日常檢查

```bash
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
podman logs powa-web
podman logs powa-collector
podman exec powa-pg psql -U postgres -d powa -c "select * from powa_servers order by id;"
```

## 常見異常與處理

### `bind: address already in use`

- 表示 host port 已被占用
- 本案例做法：將 PG17 改為 `5433:5432`

### `database "powa" does not exist`

- 表示背景 worker 找不到 repository database
- 若沿用舊資料目錄，需手動補建 `powa` database 與 extensions

### `Cannot connect to Podman`

- 先確認 `podman machine start`
- 再確認 `podman info`
