# PMM instance capacity sample: p-pxc-n-1

## Scope

- Observation: 2026-06-26 23:08 +0800 to 2026-06-27 23:08 +0800 (24 hours)
- Sampling and rate window: 5 minutes
- Sustained peak: maximum rolling mean of three consecutive 5-minute samples
- Per-request HTTP timeout: 1 second(s)
- Generated: 2026-06-27 23:08:58 +0800
- This is an instance capacity report, not an audited TPC-C result.

## Inventory and health

| Item | Value |
|---|---:|
| Inferred topology | PXC/Galera member |
| Telemetry coverage of requested period | 100.0% (289/289) |
| MySQL availability within observed samples | 100.000% |
| Logical CPU | 8 |
| Memory | 125.9 GiB |
| Current PXC cluster size | 3 |
| Current wsrep ready | 1 |
| Current wsrep connected | 1 |
| Current read_only | 0 |
| Replication master_server_id | N/A |

## Transaction and row demand

| Metric | Unit | P50 | P95 | P99 | Max 15m avg | 5m samples |
|---|---|---:|---:|---:|---:|---:|
| PXC local commits | txn/min | 1,295.4 | 4,795.5 | 5,379.9 | 5,442.6 | 289 |
| InnoDB RW commits | txn/min | 3,668.3 | 8,421.5 | 10,801.9 | 11,119.7 | 289 |
| InnoDB RO commits | txn/min | 32.5 | 181.7 | 240.4 | 243.6 | 289 |
| Rollbacks | txn/min | 0.0 | 0.0 | 0.0 | 0.1 | 289 |
| Rows read | rows/min | 32,941,696.4 | 56,963,623.4 | 85,302,818.2 | 199,905,128.9 | 289 |
| Rows inserted | rows/min | 75,041.8 | 86,848.0 | 229,116.8 | 902,067.3 | 289 |
| Rows updated | rows/min | 520.6 | 2,545.7 | 4,149.6 | 7,129.2 | 289 |
| Rows deleted | rows/min | 647.3 | 15,661.7 | 48,634.2 | 166,016.8 | 289 |
| Deadlocks | events/min | 0.0 | 0.0 | 0.0 | 0.0 | 289 |
| Row lock waits | events/min | 0.0 | 0.4 | 1.1 | 27.8 | 289 |
| PXC cert failures | events/min | 0.0 | 0.0 | 0.0 | 0.0 | 289 |
| PXC BF aborts | events/min | 0.0 | 0.0 | 0.0 | 0.0 | 289 |

## Resource demand

| Metric | Unit | P50 | P95 | P99 | Max 15m avg |
|---|---|---:|---:|---:|---:|
| CPU busy | % | 10.1 | 16.6 | 21.4 | 22.0 |
| CPU iowait | % | 0.3 | 1.2 | 2.6 | 4.8 |
| Memory used | % | 89.2 | 89.2 | 89.2 | 89.2 |
| Disk read | MiB/s | 0.1 | 1.6 | 3.8 | 7.7 |
| Disk write | MiB/s | 1.3 | 5.1 | 16.7 | 50.0 |

## Interpretation

- For PXC, `PXC local commits` represents logical writes originated on this node; time-align and sum it across cluster members.
- For async replication, use `InnoDB RW commits` as logical write demand only on the confirmed writer. Replica RW commits are physical replay load.
- `InnoDB RW commits` may include replicated writes. Never add it to `PXC local commits`.
- `InnoDB RO commits` is reported separately; it is not folded into tpmC-equivalent.
- Convert logical write demand to capacity-equivalent tpmC only after a controlled benchmark establishes `local commits per tpmC`.
- Use P99 or maximum 15-minute average for design demand. Raw single-sample maximum is intentionally excluded.

## Review gates before batch generation

1. Confirm instance-to-cluster membership and which nodes accept application traffic.
2. The 24-hour sample validates collection and report shape only; production sizing still needs representative peak periods.
3. Confirm the disk-device filter. Current disk figures sum all exporter-visible block devices.
4. Add PMM/QAN latency percentiles if this PMM deployment exposes them outside the Prometheus metric set.
5. Keep `N/A` as missing telemetry; never convert missing series to zero.
