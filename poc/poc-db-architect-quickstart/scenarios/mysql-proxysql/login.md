# mysql-proxysql login

## 從 host 連線

```bash
mysql -h 127.0.0.1 -P 6032 -uadmin -padmin
mysql -h 127.0.0.1 -P 6033 -uappuser -papppass
```

## 進容器操作

```bash
podman exec -it "$(podman ps --format '{{.Names}}' | rg '^mysql-proxysql-.*master-1$' -m 1)" mysql -uroot -prootpass
```
