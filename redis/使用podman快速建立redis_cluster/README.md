redis.conf 內容
```
# bind 127.0.0.1
protected-mode no
daemonize no
```

docker-compose.yml 內容
```
version: '3.8'

services:
  redis-master-6380:
    image: redis:7.0
    container_name: redis-master-6380
    network_mode: "host"
    privileged: true
    volumes:
      - /Users/wn.lin/lab/redis/cluster/master/6380:/data
      - /Users/wn.lin/lab/redis/cluster/master/6380/redis.conf:/usr/local/etc/redis/redis.conf
    command: ["redis-server", "/usr/local/etc/redis/redis.conf", "--cluster-enabled", "yes", "--appendonly", "yes", "--port", "6380"]
    restart: always

  redis-master-6381:
    image: redis:7.0
    container_name: redis-master-6381
    network_mode: "host"
    privileged: true
    volumes:
      - /Users/wn.lin/lab/redis/cluster/master/6381:/data
      - /Users/wn.lin/lab/redis/cluster/master/6381/redis.conf:/usr/local/etc/redis/redis.conf
    command: ["redis-server", "/usr/local/etc/redis/redis.conf", "--cluster-enabled", "yes", "--appendonly", "yes", "--port", "6381"]
    restart: always

  redis-master-6382:
    image: redis:7.0
    container_name: redis-master-6382
    network_mode: "host"
    privileged: true
    volumes:
      - /Users/wn.lin/lab/redis/cluster/master/6382:/data
      - /Users/wn.lin/lab/redis/cluster/master/6382/redis.conf:/usr/local/etc/redis/redis.conf
    command: ["redis-server", "/usr/local/etc/redis/redis.conf", "--cluster-enabled", "yes", "--appendonly", "yes", "--port", "6382"]
    restart: always

  redis-master-6383:
    image: redis:7.0
    container_name: redis-master-6383
    network_mode: "host"
    privileged: true
    volumes:
      - /Users/wn.lin/lab/redis/cluster/master/6383:/data
      - /Users/wn.lin/lab/redis/cluster/master/6383/redis.conf:/usr/local/etc/redis/redis.conf
    command: ["redis-server", "/usr/local/etc/redis/redis.conf", "--cluster-enabled", "yes", "--appendonly", "yes", "--port", "6383"]
    restart: always

  redis-slave-6390:
    image: redis:7.0
    container_name: redis-slave-6390
    network_mode: "host"
    privileged: true
    volumes:
      - /Users/wn.lin/lab/redis/cluster/slave/6390:/data
      - /Users/wn.lin/lab/redis/cluster/slave/6390/redis.conf:/usr/local/etc/redis/redis.conf
    command: ["redis-server", "/usr/local/etc/redis/redis.conf", "--cluster-enabled", "yes", "--appendonly", "yes", "--port", "6390"]
    restart: always

  redis-slave-6391:
    image: redis:7.0
    container_name: redis-slave-6391
    network_mode: "host"
    privileged: true
    volumes:
      - /Users/wn.lin/lab/redis/cluster/slave/6391:/data
      - /Users/wn.lin/lab/redis/cluster/slave/6391/redis.conf:/usr/local/etc/redis/redis.conf
    command: ["redis-server", "/usr/local/etc/redis/redis.conf", "--cluster-enabled", "yes", "--appendonly", "yes", "--port", "6391"]
    restart: always

  redis-slave-6392:
    image: redis:7.0
    container_name: redis-slave-6392
    network_mode: "host"
    privileged: true
    volumes:
      - /Users/wn.lin/lab/redis/cluster/slave/6392:/data
      - /Users/wn.lin/lab/redis/cluster/slave/6392/redis.conf:/usr/local/etc/redis/redis.conf
    command: ["redis-server", "/usr/local/etc/redis/redis.conf", "--cluster-enabled", "yes", "--appendonly", "yes", "--port", "6392"]
    restart: always

  redis-slave-6393:
    image: redis:7.0
    container_name: redis-slave-6393
    network_mode: "host"
    privileged: true
    volumes:
      - /Users/wn.lin/lab/redis/cluster/slave/6393:/data
      - /Users/wn.lin/lab/redis/cluster/slave/6393/redis.conf:/usr/local/etc/redis/redis.conf
    command: ["redis-server", "/usr/local/etc/redis/redis.conf", "--cluster-enabled", "yes", "--appendonly", "yes", "--port", "6393"]
    restart: always
```

啟動 & 關閉命令
```
podman compose up -d
podman compose down
```

redis cluster 操作記錄
```
podman exec -it redis-master-6380 /bin/bash

redis-cli --cluster create localhost:6380 localhost:6381 localhost:6382 localhost:6390 localhost:6391 localhost:6392 --cluster-replicas 1

M: 0237e10932bfd029a1e49fbc7a4e87cfd09263ef localhost:6380
   slots:[0-5460] (5461 slots) master
M: 29f14359006fd67927b022f4cb85ae85c5f2c6ed localhost:6381
   slots:[5461-10922] (5462 slots) master
M: ab5babbf26cf65a0f72efed9e73ccc757060bb45 localhost:6382
   slots:[10923-16383] (5461 slots) master
S: 505d164dc67d4187816643a54fa7fc6b37df118f localhost:6390
   replicates 0237e10932bfd029a1e49fbc7a4e87cfd09263ef
S: c20d805b0d4aea8ec86cff714d87d7949b7df044 localhost:6391
   replicates 29f14359006fd67927b022f4cb85ae85c5f2c6ed
S: 0998e460bec46282e586c6feffce22773ee317cc localhost:6392
   replicates ab5babbf26cf65a0f72efed9e73ccc757060bb45

redis-cli --cluster check localhost:6380

redis-cli --cluster reshard localhost:6380

M: 0237e10932bfd029a1e49fbc7a4e87cfd09263ef localhost:6380
   slots:[0-5460],[10923-16383] (10922 slots) master
   3 additional replica(s)
S: ab5babbf26cf65a0f72efed9e73ccc757060bb45 ::1:6382
   slots: (0 slots) slave
   replicates 0237e10932bfd029a1e49fbc7a4e87cfd09263ef
S: 0998e460bec46282e586c6feffce22773ee317cc ::1:6392
   slots: (0 slots) slave
   replicates 0237e10932bfd029a1e49fbc7a4e87cfd09263ef
M: 29f14359006fd67927b022f4cb85ae85c5f2c6ed ::1:6381
   slots:[5461-10922] (5462 slots) master
   1 additional replica(s)
S: c20d805b0d4aea8ec86cff714d87d7949b7df044 ::1:6391
   slots: (0 slots) slave
   replicates 29f14359006fd67927b022f4cb85ae85c5f2c6ed
S: 505d164dc67d4187816643a54fa7fc6b37df118f ::1:6390
   slots: (0 slots) slave
   replicates 0237e10932bfd029a1e49fbc7a4e87cfd09263ef

redis-cli --cluster del-node localhost:6382 ab5babbf26cf65a0f72efed9e73ccc757060bb45

redis-cli --cluster check localhost:6380

redis-cli --cluster add-node localhost:6382 localhost:6380

redis-cli --cluster reshard localhost:6380

redis-cli --cluster check localhost:6380

redis-cli --cluster del-node localhost:6390 505d164dc67d4187816643a54fa7fc6b37df118f

redis-cli --cluster add-node localhost:6390 localhost:6382 --cluster-slave --cluster-master-id ab5babbf26cf65a0f72efed9e73ccc757060bb45

redis-cli --cluster check localhost:6380
```