# yuga-tc1 / S-BASE / k8s-3node-unlimit / 20260513-0037

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 16      | 441.8 | 285.2              | 37.7            |
| 32      | n/a  | n/a                | n/a             |

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
TIMESTAMP=20260513-0037
```

## Notes

- variant: k8s-3node-unlimit
- control plane overhead: included (K8s control plane on poc-1)
- log status:
  - threads=16: completed with 30 matched error lines
  - threads=32: incomplete/no tpmC
