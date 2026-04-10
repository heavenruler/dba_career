# mariadb-galera login

## 從 host 連線

```bash
mysql -h 127.0.0.1 -P 3336 -uroot -prootpass
mysql -h 127.0.0.1 -P 3337 -uroot -prootpass
mysql -h 127.0.0.1 -P 3338 -uroot -prootpass
```

## 查叢集狀態

```bash
mysql -h 127.0.0.1 -P 3336 -uroot -prootpass -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
```
