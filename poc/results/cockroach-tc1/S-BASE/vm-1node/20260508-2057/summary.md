# cockroach-tc1 / S-BASE / vm-1node / 20260508-2057

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 8559.5 | 125.8              | 75.5            |
| 32      | 8732.5 | 260.0              | 151.0           |
| 64      | 8555.3 | 604.0              | 318.8           |
| 128     | 8133.4 | 1275.1             | 738.2           |

## Environment

```
CRDB_HOST=172.24.40.32
CRDB_PORT=26257
CRDB_USER=root
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=vm-1node
TOPO=cockroach-tc1
SCENARIO=S-BASE
TIMESTAMP=20260508-2057
```

## Notes

- variant: vm-1node
- control plane overhead: N/A (VM)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed
