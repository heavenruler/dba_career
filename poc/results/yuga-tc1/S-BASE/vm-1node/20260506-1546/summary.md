# yuga-tc1 / S-BASE / vm-1node / 20260506-1546

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 414.7 | 3489.7             | 109.1           |
| 32      | 394.8 | 8589.9             | 2684.4          |
| 64      | 378.6 | 16106.1            | 7516.2          |
| 128     | 370.4 | 16106.1            | 16106.1         |

## Environment

```
YUGA_HOST=172.24.40.32
YUGA_PORT=5433
YUGA_USER=yugabyte
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=vm-1node
TOPO=yuga-tc1
SCENARIO=S-BASE
TIMESTAMP=20260506-1546
```

## Notes

- variant: vm-1node
- control plane overhead: N/A (VM)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed with 2 matched error lines
