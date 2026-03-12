# Cleanup Guide

## 目的

本文件說明如何完整清除本次 PoWA + PostgreSQL 17 測試環境，避免殘留容器、pod、設定檔或資料目錄。

## 清除範圍

- PoWA repository pod 與其容器
- PostgreSQL 17 monitored target 容器
- PoWA collector 容器
- 測試資料目錄
- 測試設定檔

## 先確認目前狀態

```bash
podman ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```

## 只停止服務，不刪資料

適合暫停測試，之後還要再啟動：

```bash
podman stop powa-collector >/dev/null 2>&1 || true
podman stop pg17-test >/dev/null 2>&1 || true
podman pod stop powa-pod >/dev/null 2>&1 || true
```

## 刪除容器與 pod，但保留本機資料

適合保留 `~/powa-test` 與 `~/pg17-test`，之後重建時沿用：

```bash
podman rm -f powa-collector >/dev/null 2>&1 || true
podman rm -f pg17-test >/dev/null 2>&1 || true
podman pod rm -f powa-pod >/dev/null 2>&1 || true
```

## 完整刪除測試環境

注意：以下會刪除資料目錄，屬不可逆操作。

```bash
podman rm -f powa-collector >/dev/null 2>&1 || true
podman rm -f pg17-test >/dev/null 2>&1 || true
podman pod rm -f powa-pod >/dev/null 2>&1 || true
rm -rf ~/powa-test
rm -rf ~/pg17-test
```

## 若要連 Podman machine 一起重置

注意：以下會清掉該 machine 內的所有容器與 image。

```bash
podman machine stop >/dev/null 2>&1 || true
podman machine rm -f
```

## 清除後驗證

```bash
podman ps -a
podman pod ps
ls ~/powa-test ~/pg17-test
```

若已完整清除，預期：

- `powa-pod` 不存在
- `powa-pg` / `powa-web` / `powa-collector` / `pg17-test` 不存在
- `~/powa-test` 與 `~/pg17-test` 不存在或為空

## 建議清除策略

- 只想暫停：使用 stop
- 想重建容器但保留資料：刪 container / pod，不刪目錄
- 想回到乾淨初始狀態：連同 `~/powa-test`、`~/pg17-test` 一起刪
