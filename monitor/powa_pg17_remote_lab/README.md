# PoWA Remote Monitor PG17 Lab

## 測試目的

本測試目的是在 macOS + Podman 環境中，建立一套可操作的 PoWA 測試架構，驗證以下事項：

- PoWA repository 可正常提供 Web UI
- PostgreSQL 17 可作為被監控端 (remote server)
- `powa-collector` 可從 repository 端連線至 PG17 並進行收集
- 不依賴本機 `psql`，可完全透過 Podman 容器完成建置與驗證

## 架構摘要

- PoWA repository: `powa-pg`
- PoWA Web UI: `powa-web`
- 被監控 PostgreSQL 17: `pg17-test`
- 收集程序: `powa-collector`

## Port 規劃

- `5432` -> PoWA repository PostgreSQL 16
- `8888` -> PoWA Web UI
- `5433` -> PostgreSQL 17 monitored target

## 目前最終結果

- `powa-pg` 已啟動，提供 PoWA repository database
- `powa-web` 已啟動，Web UI 可由 `http://127.0.0.1:8888` 存取
- `pg17-test` 已改為 `powateam/powa-archivist-17` image，並成功建立 `powa` database 與相關 extensions
- `powa-collector` 已啟動
- `powa_servers` 已可看到 remote server `pg17-test`

## 已驗證項目

### 1. 驗證 PG17 的 `powa` database 與 extensions

```bash
podman exec pg17-test psql -U postgres -d powa -c "\dx"
```

驗證結果重點：

- `powa`
- `pg_stat_statements`
- `pg_qualstats`
- `pg_stat_kcache`
- `pg_wait_sampling`
- `pg_track_settings`
- `hypopg`

### 2. 驗證 PoWA repository 已註冊 PG17 remote server

```bash
podman exec powa-pg psql -U postgres -d powa -c "select id, alias, hostname, port, username, dbname, frequency, retention, allow_ui_connection from powa_servers order by id;"
```

已確認包含：

- `alias = pg17-test`
- `hostname = host.containers.internal`
- `port = 5433`
- `username = powa`
- `dbname = powa`

### 3. 驗證 collector 已啟動

```bash
podman logs powa-collector
```

## 建置經過

完整過程請見 `build-notes.md`。

## 重要問題與修正

### 問題 1: Podman 無法連線

現象：

```text
Cannot connect to Podman
```

處理方式：

- 啟動 `podman machine`
- 確認 `podman info` 可正常回應後再建立容器

### 問題 2: 5432 port 衝突

現象：

```text
bind: address already in use
```

原因：

- `5432` 已被 PoWA repository pod 使用

處理方式：

- 將 PG17 改綁 `5433:5432`

### 問題 3: PG17 缺少 `powa` database

現象：

```text
FATAL:  database "powa" does not exist
```

原因：

- 重建容器時沿用舊資料目錄
- `docker-entrypoint-initdb.d` 初始化腳本未再執行

處理方式：

- 直接進入既有 PG17 容器補建 `powa` database、role 與 extensions

## 常用操作指令

### 查看容器

```bash
podman ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```

### 查看 PoWA Web

```bash
open http://127.0.0.1:8888
```

### 測試 5432 的 PoWA repository

```bash
podman run --rm -e PGPASSWORD=postgres docker.io/library/postgres:17 \
  psql -h host.containers.internal -p 5432 -U postgres -d postgres \
  -c "select version(), current_database(), current_user;"
```

### 測試 5433 的 PG17 monitored target

```bash
podman run --rm -e PGPASSWORD=postgres docker.io/library/postgres:17 \
  psql -h host.containers.internal -p 5433 -U postgres -d powa \
  -c "select version(), current_database(), current_user;"
```

## 測試目錄說明

本目錄命名為 `powa_pg17_remote_lab`，用意是明確表達：

- `powa`: 監控工具
- `pg17`: 被監控的 PostgreSQL 版本
- `remote`: 採 remote repository / collector 架構
- `lab`: 屬於測試與驗證用途
