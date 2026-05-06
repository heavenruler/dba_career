# tidb-tc1 / S-BASE / k8s-unlimit / 20260427-1241

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 13668.4 | 56.6               | 37.7            |
| 32      | 16991.9 | 104.9              | 75.5            |
| 64      | 18456.1 | 218.1              | 176.2           |
| 128     | 18841.8 | 436.2              | 385.9           |

## Environment

```
TIDB_HOST=172.24.40.32
TIDB_PORT=30004
TIDB_USER=root
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=k8s-unlimit
TOPO=tidb-tc1
SCENARIO=S-BASE
TIMESTAMP=20260427-1241
```

## Notes

- variant: k8s-unlimit
- control plane overhead: included (K8s control plane on poc-1)
