# mysql-group-replication login

## 從 host 連線

```bash
mysql -h 127.0.0.1 -P 3320 -uroot -prootpass
mysql -h 127.0.0.1 -P 3321 -uroot -prootpass
mysql -h 127.0.0.1 -P 3322 -uroot -prootpass
```

## 查群組狀態

```bash
mysql -h 127.0.0.1 -P 3320 -uroot -prootpass -e "SELECT MEMBER_HOST, MEMBER_PORT, MEMBER_STATE, MEMBER_ROLE FROM performance_schema.replication_group_members;"
```
