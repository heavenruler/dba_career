# yuga-tc1 / S-BASE / k8s-3node-unlimit / 20260513-0114

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 2932.9 | 637.5              | 71.3            |
| 32      | 3163.6 | 1476.4             | 302.0           |
| 64      | 3144.3 | 3892.3             | 1342.2          |
| 128     | 2984.0 | 10737.4            | 4160.7          |

## Environment

```
YUGA_HOST=172.24.40.32
YUGA_PORT=30005
YUGA_USER=yugabyte
WAREHOUSES=128
DURATION=10m
THREADS_LIST="16 32 64 128"
WARMUP=5m
VARIANT=k8s-3node-unlimit
TOPO=yuga-tc1
SCENARIO=S-BASE
TIMESTAMP=20260513-0114
```

## Notes

- variant: k8s-3node-unlimit
- control plane overhead: included (K8s control plane on poc-1)
- log status:
  - threads=16: completed
  - threads=32: completed
  - threads=64: completed
  - threads=128: completed
