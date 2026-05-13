# tidb-tc1 / S-BASE / vm-3node / 20260510-0021

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 13957.6 | 56.6               | 37.7            |
| 32      | 18393.2 | 96.5               | 71.3            |
| 64      | 21523.0 | 176.2              | 142.6           |
| 128     | 21875.0 | 369.1              | 318.8           |

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
TIMESTAMP=20260510-0021
```

## Notes

- variant: vm-3node
- control plane overhead: N/A (VM)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed
