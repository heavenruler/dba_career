# chrony cross-region drift gate — 10 hosts
TS: 20260611T161930+0800  median_threshold: 100.0 ms  worst_threshold: 250.0 ms

## Per-host
| Region | Label | Stratum | Last offset (ms) | Leap | Reference ID |
|---|---|---|---|---|---|
| IDC | idc-driver | 7 | -0.004523 | Normal | AC13FE07 (172.19.254.7) |
| IDC | idc-dbhost-1 | 7 | -0.001081 | Normal | AC13FE07 (172.19.254.7) |
| IDC | idc-dbhost-2 | 7 | -0.030605 | Normal | AC13FE07 (172.19.254.7) |
| IDC | idc-dbhost-3 | 7 | -0.013467 | Normal | AC13FE07 (172.19.254.7) |
| IDC | idc-haproxy | 7 | -0.064682 | Normal | AC13FE07 (172.19.254.7) |
| GCP | gcp-poc-1 | 3 | +0.003736 | Normal | A9FEA9FE (metadata.google.internal) |
| GCP | gcp-poc-2 | 3 | +0.000841 | Normal | A9FEA9FE (metadata.google.internal) |
| GCP | gcp-poc-3 | 3 | +0.005311 | Normal | A9FEA9FE (metadata.google.internal) |
| GCP | gcp-poc-4 | 3 | -0.012063 | Normal | A9FEA9FE (metadata.google.internal) |
| GCP | gcp-poc-5 | 3 | -0.003851 | Normal | A9FEA9FE (metadata.google.internal) |

## Per-region |Last offset| (ms) stats
```
IDC  n=5  mean=0.022872  median=0.013467  max=0.064682  min=0.001081  stdev=0.023272
GCP  n=5  mean=0.005160  median=0.003851  max=0.012063  min=0.000841  stdev=0.003744

drift_median_ms = 0.017318
drift_mean_ms   = 0.028032
drift_worst_ms  = 0.076745
drift_best_ms   = 0.001922
```

verdict=PASS
