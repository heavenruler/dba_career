# tidb-tc1 / S-BASE / vm-3node-direct / 20260509-2335

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 12882.2 | 62.9               | 44.0            |
| 32      | 14385.6 | 117.4              | 88.1            |
| 64      | 13204.3 | 285.2              | 218.1           |
| 128     | 14779.6 | 486.5              | 453.0           |

## Environment

```
TIDB_HOST=172.24.40.32
TIDB_PORT=4000
TIDB_USER=root
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=vm-3node-direct
TOPO=tidb-tc1
SCENARIO=S-BASE
TIMESTAMP=20260509-2335
```

## Notes

- variant: vm-3node-direct
- control plane overhead: N/A (VM)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed
