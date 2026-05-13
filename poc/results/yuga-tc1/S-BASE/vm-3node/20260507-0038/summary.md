# yuga-tc1 / S-BASE / vm-3node / 20260507-0038

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 933.8 | 2281.7             | 79.7            |
| 32      | 951.7 | 5905.6             | 1677.7          |
| 64      | 1012.3 | 15032.4            | 5100.3          |
| 128     | n/a  | n/a                | n/a             |

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
TIMESTAMP=20260507-0038
```

## Notes

- variant: vm-3node
- control plane overhead: N/A (VM)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: incomplete/no tpmC
