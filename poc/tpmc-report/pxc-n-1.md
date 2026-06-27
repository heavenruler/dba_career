# PMM instance capacity sample: pxc-n-1

## Scope

- Observation: 2026-06-26 23:08 +0800 to 2026-06-27 23:08 +0800 (24 hours)
- Sampling and rate window: 5 minutes
- Sustained peak: maximum rolling mean of three consecutive 5-minute samples
- Per-request HTTP timeout: 1 second(s)
- Generated: 2026-06-27 23:08:34 +0800
- This is an instance capacity report, not an audited TPC-C result.

## Inventory and health

| Item | Value |
|---|---:|
| Inferred topology | Async/standalone primary candidate |
| Telemetry coverage of requested period | 0.0% (0/289) |
| MySQL availability within observed samples | N/A% |
| Logical CPU | N/A |
| Memory | N/A GiB |
| Current PXC cluster size | N/A |
| Current wsrep ready | N/A |
| Current wsrep connected | N/A |
| Current read_only | N/A |
| Replication master_server_id | N/A |

## Transaction and row demand

| Metric | Unit | P50 | P95 | P99 | Max 15m avg | 5m samples |
|---|---|---:|---:|---:|---:|---:|
| PXC local commits | txn/min | N/A | N/A | N/A | N/A | 0 |
| InnoDB RW commits | txn/min | N/A | N/A | N/A | N/A | 0 |
| InnoDB RO commits | txn/min | N/A | N/A | N/A | N/A | 0 |
| Rollbacks | txn/min | N/A | N/A | N/A | N/A | 0 |
| Rows read | rows/min | N/A | N/A | N/A | N/A | 0 |
| Rows inserted | rows/min | N/A | N/A | N/A | N/A | 0 |
| Rows updated | rows/min | N/A | N/A | N/A | N/A | 0 |
| Rows deleted | rows/min | N/A | N/A | N/A | N/A | 0 |
| Deadlocks | events/min | N/A | N/A | N/A | N/A | 0 |
| Row lock waits | events/min | N/A | N/A | N/A | N/A | 0 |
| PXC cert failures | events/min | N/A | N/A | N/A | N/A | 0 |
| PXC BF aborts | events/min | N/A | N/A | N/A | N/A | 0 |

## Resource demand

| Metric | Unit | P50 | P95 | P99 | Max 15m avg |
|---|---|---:|---:|---:|---:|
| CPU busy | % | N/A | N/A | N/A | N/A |
| CPU iowait | % | N/A | N/A | N/A | N/A |
| Memory used | % | N/A | N/A | N/A | N/A |
| Disk read | MiB/s | N/A | N/A | N/A | N/A |
| Disk write | MiB/s | N/A | N/A | N/A | N/A |

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
