# redis-standalone login

## 從 host 連線

```bash
redis-cli -h 127.0.0.1 -p 6379
```

## 進容器操作

```bash
podman exec -it redis-standalone-1 redis-cli
```
