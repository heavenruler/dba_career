# PMM instance capacity sample: p-my-fp02-1

## Scope

- Observation: 2026-06-26 23:05 +0800 to 2026-06-27 23:05 +0800 (24 hours)
- Sampling and rate window: 5 minutes
- Sustained peak: maximum rolling mean of three consecutive 5-minute samples
- Per-request HTTP timeout: 1 second(s)
- Generated: 2026-06-27 23:05:58 +0800
- This is an instance capacity report, not an audited TPC-C result.

## Inventory and health

| Item | Value |
|---|---:|
| Inferred topology | Async/standalone primary candidate |
| Telemetry coverage of requested period | 100.0% (289/289) |
| MySQL availability within observed samples | 100.000% |
| Logical CPU | 4 |
| Memory | 15.4 GiB |
| Current PXC cluster size | N/A |
| Current wsrep ready | N/A |
| Current wsrep connected | N/A |
| Current read_only | 0 |
| Replication master_server_id | N/A |

## Transaction and row demand

| Metric | Unit | P50 | P95 | P99 | Max 15m avg | 5m samples |
|---|---|---:|---:|---:|---:|---:|
| PXC local commits | txn/min | N/A | N/A | N/A | N/A | 0 |
| InnoDB RW commits | txn/min | 12.0 | 18.0 | 18.0 | 14.9 | 289 |
| InnoDB RO commits | txn/min | 8.5 | 9.0 | 9.0 | 8.9 | 289 |
| Rollbacks | txn/min | 0.0 | 0.0 | 0.0 | 0.0 | 289 |
| Rows read | rows/min | 490.0 | 495.7 | 497.5 | 496.2 | 289 |
| Rows inserted | rows/min | 220.0 | 225.5 | 226.0 | 225.5 | 289 |
| Rows updated | rows/min | 0.0 | 0.5 | 0.5 | 0.2 | 289 |
| Rows deleted | rows/min | 0.0 | 0.0 | 0.0 | 0.0 | 289 |
| Deadlocks | events/min | 0.0 | 0.0 | 0.0 | 0.0 | 289 |
| Row lock waits | events/min | 0.0 | 0.0 | 0.0 | 0.0 | 289 |
| PXC cert failures | events/min | N/A | N/A | N/A | N/A | 0 |
| PXC BF aborts | events/min | N/A | N/A | N/A | N/A | 0 |

## Resource demand

| Metric | Unit | P50 | P95 | P99 | Max 15m avg |
|---|---|---:|---:|---:|---:|
| CPU busy | % | 1.8 | 1.9 | 2.1 | 2.4 |
| CPU iowait | % | 0.0 | 0.0 | 0.0 | 0.0 |
| Memory used | % | 27.5 | 27.5 | 27.5 | 27.5 |
| Disk read | MiB/s | 0.0 | 0.0 | 0.0 | 0.0 |
| Disk write | MiB/s | 0.1 | 0.1 | 0.1 | 0.3 |

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
