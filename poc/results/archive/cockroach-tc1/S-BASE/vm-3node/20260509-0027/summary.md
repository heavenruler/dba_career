# cockroach-tc1 / S-BASE / vm-3node / 20260509-0027

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 9958.3 | 117.4              | 56.6            |
| 32      | 11933.4 | 218.1              | 113.2           |
| 64      | 12661.7 | 402.7              | 243.3           |
| 128     | 14014.7 | 771.8              | 520.1           |

## Environment

```
CRDB_HOST=172.24.40.32
CRDB_PORT=15257
CRDB_USER=root
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=vm-3node
TOPO=cockroach-tc1
SCENARIO=S-BASE
TIMESTAMP=20260509-0027
```

## Notes

- variant: vm-3node
- control plane overhead: N/A (VM)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed
