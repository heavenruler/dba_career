# tidb-tc1 / S-BASE / vm-1node / 20260507-2308

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 11895.0 | 65.0               | 48.2            |
| 32      | 12766.7 | 125.8              | 100.7           |
| 64      | 13355.4 | 243.3              | 218.1           |
| 128     | 13078.8 | 520.1              | 503.3           |

## Environment

```
TIDB_HOST=172.24.40.32
TIDB_PORT=4000
TIDB_USER=root
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=vm-1node
TOPO=tidb-tc1
SCENARIO=S-BASE
TIMESTAMP=20260507-2308
```

## Notes

- variant: vm-1node
- control plane overhead: N/A (VM)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed
