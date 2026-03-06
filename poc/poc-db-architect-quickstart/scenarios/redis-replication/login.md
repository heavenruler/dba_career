# redis-replication login

## Master

```bash
redis-cli -h 127.0.0.1 -p 6380
```

## Replica 1

```bash
redis-cli -h 127.0.0.1 -p 6381
```

## Replica 2

```bash
redis-cli -h 127.0.0.1 -p 6382
```

## 進容器

```bash
podman exec -it redis-replication-master-1 redis-cli -p 6379
podman exec -it redis-replication-replica-1 redis-cli -p 6380
podman exec -it redis-replication-replica-2 redis-cli -p 6381
```
