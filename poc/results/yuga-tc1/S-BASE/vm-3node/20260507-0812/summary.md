# yuga-tc1 / S-BASE / vm-3node / 20260507-0812

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 1036.7 | 1946.2             | 75.5            |
| 32      | 971.4 | 5905.6             | 805.3           |
| 64      | 965.7 | 15569.3            | 5905.6          |
| 128     | 915.8 | 16106.1            | 13958.6         |

## Environment

```
YUGA_HOST=172.24.40.32
YUGA_PORT=15433
YUGA_USER=yugabyte
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=vm-3node
TOPO=yuga-tc1
SCENARIO=S-BASE
TIMESTAMP=20260507-0812
```

## Notes

- variant: vm-3node
- control plane overhead: N/A (VM)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed
