# mysql-standalone login

## 從 host 連線

```bash
mysql -h 127.0.0.1 -P 3306 -uroot -p
```

密碼預設是 `rootpass`。

## 進容器操作

```bash
podman exec -it "$(podman ps --format '{{.Names}}' | rg '^mysql-standalone-' -m 1)" mysql -uroot -prootpass
```
