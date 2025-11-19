# TiDB Intro for DBA #5-4

## 如何測試 RTO / RPO 數據

### Scenario
- RTO: 
- RPO: 
- SQL Layer 不可用: 
- TiKV Layer 不可用: 

- TiKV Layer Re-Sharding: 

## 環境交代
```
[root@l-k8s-labroom-1 ~]# make display
date ; tiup cluster display tidb-demo
Wed Nov 19 11:07:35 CST 2025
Cluster type:       tidb
Cluster name:       tidb-demo
Cluster version:    v8.5.3
Deploy user:        root
SSH type:           builtin
Dashboard URL:      http://10.160.152.21:2379/dashboard
Dashboard URLs:     http://10.160.152.21:2379/dashboard
Grafana URL:        http://172.24.40.20:3000
ID                   Role        Host           Ports                 OS/Arch       Status   Data Dir                         Deploy Dir
--                   ----        ----           -----                 -------       ------   --------                         ----------
172.24.40.20:3000    grafana     172.24.40.20   3000                  linux/x86_64  Up       -                                /data/tidb-deploy/grafana-3000
10.160.152.21:2379   pd          10.160.152.21  2379/2380             linux/x86_64  Up|L|UI  /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
10.160.152.22:2379   pd          10.160.152.22  2379/2380             linux/x86_64  Up       /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
10.160.152.23:2379   pd          10.160.152.23  2379/2380             linux/x86_64  Up       /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.17:2379    pd          172.24.40.17   2379/2380             linux/x86_64  Up       /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.18:2379    pd          172.24.40.18   2379/2380             linux/x86_64  Up       /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.19:2379    pd          172.24.40.19   2379/2380             linux/x86_64  Up       /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.20:9090    prometheus  172.24.40.20   9090/9115/9100/12020  linux/x86_64  Up       /data/tidb-data/prometheus-9090  /data/tidb-deploy/prometheus-9090
10.160.152.21:4000   tidb        10.160.152.21  4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
10.160.152.22:4000   tidb        10.160.152.22  4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
10.160.152.23:4000   tidb        10.160.152.23  4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
172.24.40.17:4000    tidb        172.24.40.17   4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
172.24.40.18:4000    tidb        172.24.40.18   4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
172.24.40.19:4000    tidb        172.24.40.19   4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
10.160.152.24:20160  tikv        10.160.152.24  20160/20180           linux/x86_64  Up       /data/tidb-data/tikv-20160       /data/tidb-deploy/tikv-20160
172.24.40.20:20160   tikv        172.24.40.20   20160/20180           linux/x86_64  Up       /data/tidb-data/tikv-20160       /data/tidb-deploy/tikv-20160
10.160.152.21:6000   tiproxy     10.160.152.21  6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
10.160.152.22:6000   tiproxy     10.160.152.22  6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
10.160.152.23:6000   tiproxy     10.160.152.23  6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
172.24.40.17:6000    tiproxy     172.24.40.17   6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
172.24.40.18:6000    tiproxy     172.24.40.18   6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
172.24.40.19:6000    tiproxy     172.24.40.19   6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
Total nodes: 22
```