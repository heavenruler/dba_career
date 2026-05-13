# tidb-tc1 / S-BASE / k8s-3node-unlimit / 20260510-1409

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 13160.9 | 58.7               | 41.9            |
| 32      | 16304.1 | 113.2              | 83.9            |
| 64      | 18918.8 | 201.3              | 159.4           |
| 128     | 18871.3 | 486.5              | 419.4           |

## Environment

```
TIDB_HOST=172.24.40.32
TIDB_PORT=30004
TIDB_USER=root
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=k8s-3node-unlimit
TOPO=tidb-tc1
SCENARIO=S-BASE
TIMESTAMP=20260510-1409
```

## Notes

- variant: k8s-3node-unlimit
- control plane overhead: included (K8s control plane on poc-1)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed
