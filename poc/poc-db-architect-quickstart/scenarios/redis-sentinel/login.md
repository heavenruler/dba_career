# redis-sentinel login

## Sentinel 查詢

```bash
redis-cli -h 127.0.0.1 -p 26379 SENTINEL masters
redis-cli -h 127.0.0.1 -p 26380 SENTINEL master mymaster
redis-cli -h 127.0.0.1 -p 26381 SENTINEL replicas mymaster
```

## Redis master / replicas

```bash
podman exec -it redis-sentinel-master-1 redis-cli -p 6390
podman exec -it redis-sentinel-replica-1 redis-cli -p 6391
podman exec -it redis-sentinel-replica-2 redis-cli -p 6392
```
