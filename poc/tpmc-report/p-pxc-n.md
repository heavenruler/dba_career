# PMM PXC cluster capacity sample: p-pxc-n

## Scope

- Members: p-pxc-n-1, p-pxc-n-2, p-pxc-n-3
- Observation: 2026-06-26 23:14 +0800 to 2026-06-27 23:14 +0800 (24 hours)
- Sampling/rate window: 5 minutes; sustained peak is a rolling three-sample mean.
- Per-request HTTP timeout: 1 second(s)
- Cluster totals use only timestamps present for every member.
- This is a capacity-equivalence input, not an audited TPC-C result.

## Logical and physical demand

| Metric | Unit | P50 | P95 | P99 | Max 15m avg | Peak end | Aligned samples |
|---|---|---:|---:|---:|---:|---|---:|
| Logical writes originated | txn/min | 1,273.7 | 4,616.2 | 5,519.2 | 5,447.7 | 06-27 06:04 | 289 |
| Read-only transactions | txn/min | 57.8 | 317.9 | 620.2 | 1,761.8 | 06-27 03:29 | 289 |
| Rollbacks | txn/min | 0.0 | 0.0 | 0.0 | 0.1 | 06-27 21:14 | 289 |
| Physical RW commits across nodes | txn/min | 10,748.7 | 22,674.5 | 26,334.6 | 26,596.1 | 06-27 06:04 | 289 |
| Physical rows read across nodes | rows/min | 48,413,255.8 | 89,632,482.6 | 117,487,470.1 | 195,076,220.5 | 06-27 03:49 | 289 |
| Observed physical/logical commit-work | ratio | 8.44 | 11.65 | 12.25 | 12.09 | 06-27 00:59 | 289 |

- 24-hour logical-write design candidate: **5,519.2 txn/min** (`max(P99, max 15m avg)`).
- Write origin concentration: **p-pxc-n-1 = 100.00%** of observed local commits.
- Capacity-equivalent tpmC remains N/A until benchmark calibration supplies `logical local commits per tpmC`.

## HA health

| Metric | Value |
|---|---:|
| Health telemetry coverage | 100.0% (289/289) |
| Quorum available (at least 2 healthy nodes) | 100.000% |
| All 3 nodes healthy | 100.000% |

A healthy member requires `mysql_up=1`, `wsrep_ready=1`, `wsrep_connected=1`, and `wsrep_local_state=4` (Synced). This is database health, not application/proxy availability.

### Current member state

| Member | up | ready | connected | local state | cluster size |
|---|---:|---:|---:|---:|---:|
| p-pxc-n-1 | 1 | 1 | 1 | 4 | 3 |
| p-pxc-n-2 | 1 | 1 | 1 | 4 | 3 |
| p-pxc-n-3 | 1 | 1 | 1 | 4 | 3 |

## Member capacity comparison

| Member | Local commit P99 | Physical RW P99 | RO P99 | CPU P99 | Memory P99 | Disk write P99 |
|---|---:|---:|---:|---:|---:|---:|
| p-pxc-n-1 | 5,519.2 txn/min | 10,908.0 txn/min | 254.0 txn/min | 22.2% | 89.2% | 20.6 MiB/s |
| p-pxc-n-2 | 0.0 txn/min | 7,871.5 txn/min | 191.3 txn/min | 9.2% | 86.2% | 14.3 MiB/s |
| p-pxc-n-3 | 0.0 txn/min | 7,856.2 txn/min | 181.0 txn/min | 9.4% | 85.5% | 16.4 MiB/s |

## Interpretation

- Logical write demand is the time-aligned sum of `wsrep_local_commits` across all members.
- Physical RW commits and row operations include replicated work and must not be used directly as cluster tpmC.
- The physical/logical commit-work ratio is diagnostic only; it is not the PXC replication factor.
- Read-only transactions remain separate from write tpmC-equivalent.
- N-1 sizing must verify that either surviving member can absorb the cluster logical demand; summed CPU percentages are not capacity.
- The 24-hour range validates collection and report shape. Final sizing requires representative business peaks and benchmark calibration.
