# cockroach-tc1 / S-BASE / k8s-3node-limit / 20260512-2128

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 4931.8 | 369.1              | 167.8           |
| 32      | 5576.9 | 637.5              | 285.2           |
| 64      | 6181.7 | 1140.9             | 570.4           |
| 128     | 6749.9 | 2013.3             | 1140.9          |

## Environment

```
CRDB_HOST=172.24.40.32
CRDB_PORT=30007
CRDB_USER=root
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=k8s-3node-limit
TOPO=cockroach-tc1
SCENARIO=S-BASE
TIMESTAMP=20260512-2128
```

## Notes

- variant: k8s-3node-limit
- control plane overhead: included (K8s control plane on poc-1)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed
