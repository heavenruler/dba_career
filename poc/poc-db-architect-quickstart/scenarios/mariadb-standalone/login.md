# mariadb-standalone login

## 從 host 連線

```bash
mysql -h 127.0.0.1 -P 3316 -uroot -prootpass
```

## 進容器操作

```bash
podman exec -it "$(podman ps --format '{{.Names}}' | rg '^mariadb-standalone-' -m 1)" mariadb -uroot -prootpass
```
