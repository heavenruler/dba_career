# tidb-tc1 / S-BASE / k8s-3node-limit / 20260510-2140

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 10470.5 | 109.1              | 67.1            |
| 32      | 11080.7 | 201.3              | 134.2           |
| 64      | 10895.5 | 369.1              | 268.4           |
| 128     | 10519.7 | 805.3              | 704.6           |

## Environment

```
TIDB_HOST=172.24.40.32
TIDB_PORT=30004
TIDB_USER=root
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=k8s-3node-limit
TOPO=tidb-tc1
SCENARIO=S-BASE
TIMESTAMP=20260510-2140
```

## Notes

- variant: k8s-3node-limit
- control plane overhead: included (K8s control plane on poc-1)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed with 4 matched error lines
