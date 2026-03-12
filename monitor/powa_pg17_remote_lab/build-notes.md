# Build Notes

## 1. 啟動 Podman 環境

因 macOS 上的 Podman 需依賴 Linux VM，先確認 machine 可用：

```bash
podman machine start
podman info
```

## 2. 建立 PoWA 本地測試環境

建立腳本：

- `/Users/wn.lin/setup-powa-podman.sh`

用途：

- 建立 `powa-pg`
- 建立 `powa-web`
- 建立 `powa-pod`
- 寫入初始化 SQL 與 `powa-web.conf`

執行：

```bash
/Users/wn.lin/setup-powa-podman.sh
```

結果：

- `5432` 提供 PoWA repository PostgreSQL
- `8888` 提供 PoWA Web UI

## 3. 建立 PostgreSQL 17 測試環境

一開始曾用原生 image：

```bash
docker.io/library/postgres:17
```

但此方式無法直接作為 PoWA remote monitored server，因為缺少 PoWA 所需 extensions。

後續改用：

```bash
docker.io/powateam/powa-archivist-17
```

並綁定到 host `5433`：

```bash
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

## 4. 修復 `database "powa" does not exist`

因沿用舊資料目錄，初始化腳本未重跑，需手動補建：

```bash
podman exec pg17-test psql -U postgres -d postgres -c "CREATE DATABASE powa;"
```

```bash
podman exec pg17-test psql -U postgres -d powa -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements; CREATE EXTENSION IF NOT EXISTS btree_gist; CREATE EXTENSION IF NOT EXISTS powa; CREATE EXTENSION IF NOT EXISTS pg_qualstats; CREATE EXTENSION IF NOT EXISTS pg_stat_kcache; CREATE EXTENSION IF NOT EXISTS pg_wait_sampling; CREATE EXTENSION IF NOT EXISTS pg_track_settings; CREATE EXTENSION IF NOT EXISTS hypopg;"
```

```bash
podman exec pg17-test psql -U postgres -d postgres -c "DO \$role\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powa') THEN CREATE ROLE powa WITH LOGIN SUPERUSER PASSWORD 'powa123'; END IF; END \$role\$;"
```

修復後 log 可見：

```text
POWA connected to database powa
```

## 5. 在 PoWA repository 註冊 PG17

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

## 6. 建立 collector 設定並啟動

設定檔：

- `~/powa-test/conf/powa-collector.conf`

內容：

```json
{
  "repository": {
    "dsn": "postgresql://powa:powa123@host.containers.internal:5432/powa"
  },
  "debug": false
}
```

啟動：

```bash
podman run -d \
  --name powa-collector \
  -v ~/powa-test/conf/powa-collector.conf:/etc/powa-collector.conf:Z \
  docker.io/powateam/powa-collector
```

## 7. 驗證結果

### 查看已註冊 remote servers

```bash
podman exec powa-pg psql -U postgres -d powa -c "select id, alias, hostname, port, username, dbname, frequency, retention, allow_ui_connection from powa_servers order by id;"
```

### 查看 collector log

```bash
podman logs powa-collector
```

### 查看 PG17 extensions

```bash
podman exec pg17-test psql -U postgres -d powa -c "\dx"
```

## 8. 已知事項

- `powateam/powa-*` images 目前在 Apple Silicon 上可能以 `linux/amd64` 模擬執行
- 這套流程偏向 PoC / lab，不是正式環境建議配置
- 若要重新初始化 PG17，最乾淨方式是清空 `~/pg17-test/data`
