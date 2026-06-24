# cockroach-tc1 / S-BASE / vm-3node-direct / 20260508-2336

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 9142.5 | 134.2              | 65.0            |
| 32      | 10144.4 | 260.0              | 134.2           |
| 64      | 10892.4 | 469.8              | 285.2           |
| 128     | 11142.6 | 906.0              | 604.0           |

## Environment

```
CRDB_HOST=172.24.40.32
CRDB_PORT=26257
CRDB_USER=root
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=vm-3node-direct
TOPO=cockroach-tc1
SCENARIO=S-BASE
TIMESTAMP=20260508-2336
```

## Notes

- variant: vm-3node-direct
- control plane overhead: N/A (VM)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed
