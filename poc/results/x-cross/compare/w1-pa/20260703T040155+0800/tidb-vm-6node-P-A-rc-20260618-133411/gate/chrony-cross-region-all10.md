# chrony cross-region drift gate — 10 hosts
TS: 20260618-133411  median_threshold: 100.0 ms  worst_threshold: 250.0 ms

## Per-host
| Region | Label | Stratum | Last offset (ms) | Leap | Reference ID |
|---|---|---|---|---|---|
| IDC | idc-driver | ? | — | ? | ? |
| IDC | idc-dbhost-1 | ? | — | ? | ? |
| IDC | idc-dbhost-2 | ? | — | ? | ? |
| IDC | idc-dbhost-3 | ? | — | ? | ? |
| IDC | idc-haproxy | 7 | +0.004439 | Normal | AC13FE07 (172.19.254.7) |
| GCP | gcp-poc-1 | ? | — | ? | ? |
| GCP | gcp-poc-2 | ? | — | ? | ? |
| GCP | gcp-poc-3 | ? | — | ? | ? |
| GCP | gcp-poc-4 | ? | — | ? | ? |
| GCP | gcp-poc-5 | ? | — | ? | ? |

## Per-region |Last offset| (ms) stats
```
IDC  n=1  mean=0.004439  median=0.004439  max=0.004439  min=0.004439  stdev=0.000000
```

## Fail reasons
- insufficient samples (region missing all chronyc data)
- host idc-driver: chronyc unreadable / Last offset missing
- host idc-dbhost-1: chronyc unreadable / Last offset missing
- host idc-dbhost-2: chronyc unreadable / Last offset missing
- host idc-dbhost-3: chronyc unreadable / Last offset missing
- host gcp-poc-1: chronyc unreadable / Last offset missing
- host gcp-poc-2: chronyc unreadable / Last offset missing
- host gcp-poc-3: chronyc unreadable / Last offset missing
- host gcp-poc-4: chronyc unreadable / Last offset missing
- host gcp-poc-5: chronyc unreadable / Last offset missing

verdict=FAIL
