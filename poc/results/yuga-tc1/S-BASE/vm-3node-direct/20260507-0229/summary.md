# yuga-tc1 / S-BASE / vm-3node-direct / 20260507-0229

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 1024.2 | 2013.3             | 83.9            |
| 32      | 1016.4 | 5368.7             | 1342.2          |
| 64      | 1003.2 | 13421.8            | 4563.4          |
| 128     | 964.7 | 16106.1            | 12884.9         |

## Environment

```
YUGA_HOST=172.24.40.32
YUGA_PORT=5433
YUGA_USER=yugabyte
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=vm-3node-direct
TOPO=yuga-tc1
SCENARIO=S-BASE
TIMESTAMP=20260507-0229
```

## Notes

- variant: vm-3node-direct
- control plane overhead: N/A (VM)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed with 2 matched error lines
  - threads=128: completed with 2 matched error lines
