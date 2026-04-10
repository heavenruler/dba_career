# mariadb-replication login

## 從 host 連線

```bash
mysql -h 127.0.0.1 -P 3317 -uroot -prootpass
mysql -h 127.0.0.1 -P 3318 -uroot -prootpass
mysql -h 127.0.0.1 -P 3319 -uroot -prootpass
```

## 進容器操作

```bash
podman exec -it "$(podman ps --format '{{.Names}}' | rg '^mariadb-replication-.*master-1$' -m 1)" mariadb -uroot -prootpass
```
