# tidb-tc1 / S-BASE / vm / 20260427-1624

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 13993.0 | 56.6               | 37.7            |
| 32      | 17939.0 | 92.3               | 71.3            |
| 64      | 20815.5 | 176.2              | 142.6           |
| 128     | 18922.5 | 419.4              | 369.1           |

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
TIMESTAMP=20260427-1624
```

## Notes

- variant: vm
- control plane overhead: N/A (VM)
