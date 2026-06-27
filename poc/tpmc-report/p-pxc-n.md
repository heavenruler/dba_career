# PMM PXC cluster capacity sample: p-pxc-n

## Scope

- Members: p-pxc-n-1, p-pxc-n-2, p-pxc-n-3
- Observation: 2026-06-26 23:21 +0800 to 2026-06-27 23:21 +0800 (24 hours)
- Sampling/rate window: 5 minutes; sustained peak is a rolling three-sample mean.
- Per-request HTTP timeout: 1 second(s)
- Cluster totals use only timestamps present for every member.
- This is a capacity-equivalence input, not an audited TPC-C result.

## Calculation rules

For metric `m`, member `i`, and aligned timestamp `t`:

1. Per-member rate: `x_i(t) = rate(m_i[5m]) * 60`.
2. Cluster series: `X(t) = x_1(t) + x_2(t) + x_3(t)`; use only timestamps present for all three members.
3. P50/P95/P99: calculate percentiles over `X(t)`, not by adding member percentiles.
4. Max 15m avg: maximum rolling mean of three consecutive `X(t)` samples.
5. Physical/logical ratio: `sum(RW commits_i(t)) / sum(local commits_i(t))`, calculated per timestamp before percentiles.

| Report row | Source metric | Aggregation | Meaning |
|---|---|---|---|
| Logical writes originated | `mysql_global_status_wsrep_local_commits` | Sum 3 members | Logical write transactions originating in the cluster |
| Read-only transactions | `...trx_ro_commits_total` | Sum 3 members | Read workload, kept separate from tpmC-equivalent |
| Rollbacks | `...trx_rollbacks_total` | Sum 3 members | Cluster rollback activity |
| Physical RW commits across nodes | `...trx_rw_commits_total` | Sum 3 members | Physical work including replicated commits |
| Physical rows read across nodes | `mysql_global_status_innodb_row_ops_total{operation="read"}` | Sum 3 members | Physical row-read work handled by all nodes |
| Observed physical/logical commit-work | RW total / local total | Per timestamp | Diagnostic ratio; not PXC replication factor |

## Logical and physical demand

| Metric | Unit | P50 | P95 | P99 | Max 15m avg | Peak end | Aligned samples |
|---|---|---:|---:|---:|---:|---|---:|
| Logical writes originated | txn/min | 1,284.8 | 4,683.5 | 5,470.9 | 5,372.7 | 06-27 06:41 | 289 |
| Read-only transactions | txn/min | 55.6 | 322.7 | 572.9 | 1,647.3 | 06-27 03:31 | 289 |
| Rollbacks | txn/min | 0.0 | 0.0 | 0.0 | 0.1 | 06-27 21:16 | 289 |
| Physical RW commits across nodes | txn/min | 10,908.3 | 22,500.3 | 26,121.8 | 26,247.8 | 06-27 06:06 | 289 |
| Physical rows read across nodes | rows/min | 48,706,486.5 | 89,406,327.8 | 120,875,373.7 | 188,292,243.2 | 06-27 03:46 | 289 |
| Observed physical/logical commit-work | ratio | 8.53 | 11.82 | 12.45 | 12.36 | 06-27 01:01 | 289 |

- 24-hour logical-write design candidate: **5,470.9 txn/min** (`max(P99, max 15m avg)`).
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
| p-pxc-n-1 | 5,470.9 txn/min | 10,874.4 txn/min | 259.4 txn/min | 21.9% | 89.2% | 17.1 MiB/s |
| p-pxc-n-2 | 0.0 txn/min | 7,910.2 txn/min | 172.5 txn/min | 8.7% | 86.2% | 12.6 MiB/s |
| p-pxc-n-3 | 0.0 txn/min | 7,847.7 txn/min | 166.3 txn/min | 9.0% | 85.5% | 14.0 MiB/s |

## Interpretation

- Logical write demand is the time-aligned sum of `wsrep_local_commits` across all members.
- Physical RW commits and row operations include replicated work and must not be used directly as cluster tpmC.
- The physical/logical commit-work ratio is diagnostic only; it is not the PXC replication factor.
- Read-only transactions remain separate from write tpmC-equivalent.
- N-1 sizing must verify that either surviving member can absorb the cluster logical demand; summed CPU percentages are not capacity.
- The 24-hour range validates collection and report shape. Final sizing requires representative business peaks and benchmark calibration.
