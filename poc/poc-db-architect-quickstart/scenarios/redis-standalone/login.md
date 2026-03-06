# redis-standalone login

```bash
redis-cli -h 127.0.0.1 -p 6379
```

Inside Podman container:

```bash
podman exec -it redis-standalone-1 redis-cli -p 6379
```
