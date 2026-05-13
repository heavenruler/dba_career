# tidb-tc1 / S-BASE / vm-3node-verify / 20260510-0119

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
| 128     | 23746.4 | 335.5              | 285.2           |

## Environment

```
TIDB_HOST=172.24.40.34
TIDB_PORT=4000
TIDB_USER=root
WAREHOUSES=128
DURATION=10m
THREADS_LIST="128"
WARMUP=5m
VARIANT=vm-3node-verify
TOPO=tidb-tc1
SCENARIO=S-BASE
TIMESTAMP=20260510-0119
```

## Notes

- variant: vm-3node-verify
- control plane overhead: N/A (VM)
- log status:
  - threads=128: completed
