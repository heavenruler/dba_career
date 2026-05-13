# tidb-tc1 / S-BASE / vm-3node / 20260510-0206

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 13573.7 | 67.1               | 56.6            |
| 32      | 19205.1 | 88.1               | 62.9            |
| 64      | 21992.7 | 167.8              | 130.0           |
| 128     | 22841.0 | 335.5              | 302.0           |

## Environment

```
TIDB_HOST=172.24.40.34
TIDB_PORT=4000
TIDB_USER=root
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=vm-3node
TOPO=tidb-tc1
SCENARIO=S-BASE
TIMESTAMP=20260510-0206
```

## Notes

- variant: vm-3node
- control plane overhead: N/A (VM)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed
