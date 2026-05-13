# yuga-tc1 / S-BASE / k8s-3node-limit / 20260513-0954

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 1716.4 | 1275.1             | 209.7           |
| 32      | 1766.1 | 2952.8             | 637.5           |
| 64      | 1627.3 | 7516.2             | 2550.1          |
| 128     | 1568.3 | 15569.3            | 6979.3          |

## Environment

```
YUGA_HOST=172.24.40.32
YUGA_PORT=30005
YUGA_USER=yugabyte
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=k8s-3node-limit
TOPO=yuga-tc1
SCENARIO=S-BASE
TIMESTAMP=20260513-0954
```

## Notes

- variant: k8s-3node-limit
- control plane overhead: included (K8s control plane on poc-1)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed
