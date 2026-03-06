# redis-cluster login

## 連線叢集

```bash
redis-cli -h 127.0.0.1 -p 7001 -c
```

## 查看節點

```bash
redis-cli -h 127.0.0.1 -p 7001 cluster nodes
redis-cli -h 127.0.0.1 -p 7001 cluster info
```

## 進容器

```bash
podman exec -it redis-cluster-node-1 redis-cli -p 7001 -c
```
