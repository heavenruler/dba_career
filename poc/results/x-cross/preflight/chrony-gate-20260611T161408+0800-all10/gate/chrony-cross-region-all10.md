# chrony cross-region drift gate — all 10 hosts
TS: 20260611T161408+0800   threshold: 100 ms

## Per-host
| Region | Label | Stratum | Last offset (sec) | Leap | Reference ID |
|---|---|---|---|---|---|
| IDC | idc-driver | 7 | 0.000048079 | Normal | AC13FE07 (172.19.254.7) |
| IDC | idc-dbhost-1 | 7 | -0.000001081 | Normal | AC13FE07 (172.19.254.7) |
| IDC | idc-dbhost-2 | 7 | -0.000011959 | Normal | AC13FE07 (172.19.254.7) |
| IDC | idc-dbhost-3 | 7 | -0.000013467 | Normal | AC13FE07 (172.19.254.7) |
| IDC | idc-haproxy | 7 | -0.000064682 | Normal | AC13FE07 (172.19.254.7) |
| GCP | gcp-poc-1 | 3 | 0.000003077 | Normal | A9FEA9FE (metadata.google.internal) |
| GCP | gcp-poc-2 | 3 | 0.000004479 | Normal | A9FEA9FE (metadata.google.internal) |
| GCP | gcp-poc-3 | 3 | -0.000003732 | Normal | A9FEA9FE (metadata.google.internal) |
| GCP | gcp-poc-4 | 3 | -0.000006785 | Normal | A9FEA9FE (metadata.google.internal) |
| GCP | gcp-poc-5 | 3 | 0.000003297 | Normal | A9FEA9FE (metadata.google.internal) |

## Per-region |Last offset| (ms) stats
```
IDC  n=5  mean=0.027854 ms  median=0.013467 ms  max=0.064682 ms  min=0.001081 ms  stdev=0.024256 ms
GCP  n=5  mean=0.004274 ms  median=0.003732 ms  max=0.006785 ms  min=0.003077 ms  stdev=0.001344 ms

drift_median_ms = 0.017199   (idc_med=0.013467 + gcp_med=0.003732)
drift_mean_ms   = 0.032128   (idc_mean=0.027854 + gcp_mean=0.004274)
drift_worst_ms  = 0.071467   (idc_max=0.064682 + gcp_max=0.006785)
drift_best_ms   = 0.004158   (idc_min=0.001081 + gcp_min=0.003077)
```

verdict=PASS  (10/10 Leap=Normal; drift_median=0.017 ms / drift_mean=0.032 ms / drift_worst=0.071 ms — all ≪ 100 ms)
