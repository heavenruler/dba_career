# Check sysbench version @ percona-release repo
```
[root@centos7 ~]# yum list available --disablerepo='*' --enablerepo=tools-release-x86_64 | grep -i sysbench
sysbench.x86_64                           1.0.20-6.el7      tools-release-x86_64
sysbench-debuginfo.x86_64                 1.0.20-6.el7      tools-release-x86_64
sysbench-tpcc.x86_64                      1.0.20-6.el7      tools-release-x86_64
```

# Use percona-release repo install sysbench
```
[root@centos7 ~]# yum install sysbench
Running transaction
  Installing : sysbench-1.0.20-6.el7.x86_64                                                                                                                                   1/1
  Verifying  : sysbench-1.0.20-6.el7.x86_64                                                                                                                                   1/1

Installed:
  sysbench.x86_64 0:1.0.20-6.el7

Complete!
```
