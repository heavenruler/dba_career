# tidb-tc1 / S-BASE / k8s-limit / 20260427-1431

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 11156.0 | 96.5               | 65.0            |
| 32      | 11508.3 | 201.3              | 134.2           |
| 64      | 11728.8 | 352.3              | 268.4           |
| 128     | 11822.8 | 704.6              | 637.5           |

## Environment

```
TIDB_HOST=172.24.40.32
TIDB_PORT=30004
TIDB_USER=root
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=k8s-limit
TOPO=tidb-tc1
SCENARIO=S-BASE
TIMESTAMP=20260427-1431
```

## Notes

- variant: k8s-limit
- control plane overhead: included (K8s control plane on poc-1)
