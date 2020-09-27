# disable u're epel. repo & install percona-release
```
yum install https://repo.percona.com/yum/percona-release-latest.noarch.rpm
```

# Assign mysql server version & install it.
```
percona-release setup ps80
yum install percona-server-server
```
