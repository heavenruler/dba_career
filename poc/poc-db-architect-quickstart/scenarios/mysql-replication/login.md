# mysql-replication login

## 從 host 連線

```bash
mysql -h 127.0.0.1 -P 3307 -uroot -prootpass
mysql -h 127.0.0.1 -P 3308 -uroot -prootpass
mysql -h 127.0.0.1 -P 3309 -uroot -prootpass
```

## 進容器操作

```bash
podman exec -it "$(podman ps --format '{{.Names}}' | rg '^mysql-replication-.*master-1$' -m 1)" mysql -uroot -prootpass
```
