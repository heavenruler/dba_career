# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Proof-of-Concept (PoC)** project (Jira: ITDBA-3596) evaluating distributed database solutions — **TiDB** and **YugabyteDB** — for 104Corp. The current state is documentation and planning; infrastructure code has not yet been written.

**Goal:** Validate that distributed database architecture can provide continuous service (no downtime from any single failure), comparing TiDB and YugabyteDB across 9 dimensions: consistency, availability, scalability, multi-region writes, failover, network resilience, conflict handling, operability, and cost.

## Documentation Reading Order

Start with these files in order:

1. `README.md` — PoC scope, goals, and technology survey/comparison matrix (TiDB vs. YugabyteDB vs. Vitess)
2. `NAVIGATION.md` — Map of all docs and their purpose
3. `POC_TEST_DESIGN.md` — Test case definitions, metrics, and acceptance criteria
4. `POC_EXECUTION_RUNBOOK.md` — Deployment procedure, IaC requirements, and phase breakdown
5. `TIDB_IDC_GCP_ARCHITECTURE_DRAFT.md` — TiDB logical and physical deployment diagrams (Mermaid)
6. `YUGABYTEDB_IDC_GCP_ARCHITECTURE_DRAFT.md` — YugabyteDB equivalent

## Target Architecture

**Testbed:** 5 VMs (4 vCPU / 16GB RAM / 200GB each) across two sites:
- **IDC** (172.24.*.*): 3 VMs — control plane quorum lives here to prevent split-brain
- **GCP** (10.160.*.*): 2 VMs

**TiDB roles:** TiDB (SQL layer) + PD (Placement Driver / TSO) + TiKV (storage, Raft)
**YugabyteDB roles:** YB-TServer (SQL + storage) + YB-Master (control plane, Raft)

Both systems use Raft consensus with control-plane quorum pinned to IDC and data nodes distributed across both sites.

## Planned Infrastructure Stack

| Layer | Technology |
|-------|-----------|
| Provisioning | Terraform (vSphere + GCP modules) |
| Configuration | Ansible playbooks |
| OS | AlmaLinux |
| Load testing | sysbench or k6 |
| Metrics | Prometheus + Grafana (planned) |
| Diagrams | Mermaid (embedded in Markdown) |

**Planned directory layout** (not yet implemented):
```
infra/terraform/{gcp,vsphere}/
infra/ansible/{inventories,group_vars,roles,playbooks}/
tests/{common,tidb,yugabytedb}/
results/{logs,metrics,reports}/
```

## Key Test Cases

All test cases are defined in `POC_TEST_DESIGN.md`. Critical ones:

- **TC-01** — Concurrent same-row updates (32/64/128 concurrency, 10+ min): measures write conflict rate, serialization failures, retry count
- **TC-02** — Multi-region write latency: commit latency vs. TSO/HLC quorum path
- **TC-03** — Follower read staleness: leader vs. follower vs. stale read modes
- **TC-04** — Node failure RTO: leader election time under continuous load
- **TC-05** — Network partition: quorum preservation and fail-closed behavior

**Primary SLA metrics:** p95/p99 latency, abort rate, time-to-new-leader (RTO), write unavailability window.

## Important Context

- Cross-site network latency is a **critical test variable** — `tc` (traffic control) is used to simulate delays
- TiDB transaction model: Percolator + 2PC with TSO for global ordering
- YugabyteDB transaction model: DocDB intent-based + HLC (Hybrid Logical Clocks)
- When writing IaC, vSphere and GCP environment details (project IDs, VPC, service accounts, datastore names) are still TBD — leave as variables/placeholders
- Port assignments: TiDB SQL=4000, PD=2379, TiKV=20160; YugabyteDB YSQL=5433, Master RPC=7100, TServer RPC=9100
