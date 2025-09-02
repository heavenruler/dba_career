# TiDB Intro for DBA #4

## IDC * 1

Cluster Summary

<details>

```
date ; tiup cluster display tidb-demo
Tue Sep  2 14:18:11 CST 2025
Cluster type:       tidb
Cluster name:       tidb-demo
Cluster version:    v8.5.3
Deploy user:        root
SSH type:           builtin
Dashboard URL:      http://172.24.40.18:2379/dashboard
Dashboard URLs:     http://172.24.40.18:2379/dashboard
ID                  Role     Host          Ports        OS/Arch       Status   Data Dir                    Deploy Dir
--                  ----     ----          -----        -------       ------   --------                    ----------
172.24.40.18:2379   pd       172.24.40.18  2379/2380    linux/x86_64  Up|L|UI  /data/tidb-data/pd-2379     /data/tidb-deploy/pd-2379
172.24.40.18:4000   tidb     172.24.40.18  4000/10080   linux/x86_64  Up       -                           /data/tidb-deploy/tidb-4000
172.24.40.18:20160  tikv     172.24.40.18  20160/20180  linux/x86_64  Up       /data/tidb-data/tikv-20160  /data/tidb-deploy/tikv-20160
172.24.40.18:6000   tiproxy  172.24.40.18  6000/6001    linux/x86_64  Up       -                           /data/tidb-deploy/tiproxy-6000
```

</details>

RPS From TiProxy with IDC

![](./%23.png)

<details>

```
```

</details>