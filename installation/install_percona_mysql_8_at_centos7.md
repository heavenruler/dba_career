# disable u're epel. repo & install percona-release
```
yum install https://repo.percona.com/yum/percona-release-latest.noarch.rpm
```

# Assign mysql server version & install it.
```
percona-release setup ps80
yum install percona-server-server
```

# After install
```
Installed:
  percona-server-server.x86_64 0:8.0.20-11.1.el7                                       percona-server-shared-compat.x86_64 0:8.0.20-11.1.el7

Dependency Installed:
  net-tools.x86_64 0:2.0-0.25.20131004git.el7              percona-server-client.x86_64 0:8.0.20-11.1.el7              percona-server-shared.x86_64 0:8.0.20-11.1.el7

Replaced:
  mariadb-libs.x86_64 1:5.5.65-1.el7

Complete!
```

# Check client version
```
[root@centos7 yum.repos.d]# mysql -V
mysql  Ver 8.0.20-11 for Linux on x86_64 (Percona Server (GPL), Release 11, Revision 5b5a5d2)
```

# Check server version
```
[root@centos7 ~]# cat /var/log/mysqld.log | grep -i password
2020-09-27T13:37:55.610505Z 6 [Note] [MY-010454] [Server] A temporary password is generated for root@localhost: -O)+P4i/8tY_

[root@centos7 ~]# mysql -p'-O)+P4i/8tY_'
mysql: [Warning] Using a password on the command line interface can be insecure.
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 12
Server version: 8.0.20-11
```

# Change default validated password first
```
mysql> alter user 'root'@'localhost' identified by 'Qassw0rd999$%^'; flush privileges;
Query OK, 0 rows affected (0.01 sec)
Query OK, 0 rows affected (0.00 sec)
```

# Uninstall validate_password plugin
```
mysql> UNINSTALL COMPONENT 'file://component_validate_password';
Query OK, 0 rows affected (0.01 sec)
```

# Update password again
```
mysql> alter user 'root'@'localhost' identified by 'password'; flush privileges;
Query OK, 0 rows affected (0.01 sec)
Query OK, 0 rows affected (0.00 sec)
```
