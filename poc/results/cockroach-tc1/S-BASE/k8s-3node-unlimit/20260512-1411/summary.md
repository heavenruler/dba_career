# cockroach-tc1 / S-BASE / k8s-3node-unlimit / 20260512-1411

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 8998.0 | 130.0              | 67.1            |
| 32      | 10599.9 | 251.7              | 142.6           |
| 64      | 12416.6 | 453.0              | 260.0           |
| 128     | 13982.2 | 805.3              | 536.9           |

## Environment

```
CRDB_HOST=172.24.40.32
CRDB_PORT=30007
CRDB_USER=root
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=k8s-3node-unlimit
TOPO=cockroach-tc1
SCENARIO=S-BASE
TIMESTAMP=20260512-1411
```

## Notes

- variant: k8s-3node-unlimit
- control plane overhead: included (K8s control plane on poc-1)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed
