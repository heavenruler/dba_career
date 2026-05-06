# tidb-tc1 / S-BASE / vm / 20260428-0900

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 14236.0 | 52.4               | 37.7            |
| 32      | 18067.0 | 92.3               | 71.3            |
| 64      | 20019.8 | 192.9              | 151.0           |
| 128     | 20393.9 | 385.9              | 352.3           |

## Environment

```
TIDB_HOST=172.24.40.34
TIDB_PORT=4000
TIDB_USER=root
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=vm
TOPO=tidb-tc1
SCENARIO=S-BASE
TIMESTAMP=20260428-0900
```

## Notes

- variant: vm
- control plane overhead: N/A (VM)
