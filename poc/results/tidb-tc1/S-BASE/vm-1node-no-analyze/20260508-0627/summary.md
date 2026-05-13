# tidb-tc1 / S-BASE / vm-1node-no-analyze / 20260508-0627

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 11380.6 | 71.3               | 52.4            |
| 32      | 12596.2 | 125.8              | 104.9           |
| 64      | 13345.3 | 243.3              | 218.1           |
| 128     | 13191.7 | 520.1              | 503.3           |

## Environment

```
TIDB_HOST=172.24.40.32
TIDB_PORT=4000
TIDB_USER=root
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=vm-1node-no-analyze
TOPO=tidb-tc1
SCENARIO=S-BASE
TIMESTAMP=20260508-0627
```

## Notes

- variant: vm-1node-no-analyze
- control plane overhead: N/A (VM)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed
