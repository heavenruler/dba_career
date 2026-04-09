# mysql-innodb-cluster login

## 從 host 透過 Router 連線

```bash
mysql -h 127.0.0.1 -P 6446 -uappuser -papppass
```

## 直接登入節點

```bash
mysql -h 127.0.0.1 -P 3330 -uroot -prootpass
mysql -h 127.0.0.1 -P 3331 -uroot -prootpass
mysql -h 127.0.0.1 -P 3332 -uroot -prootpass
```
