# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Proof-of-Concept (PoC)** project (Jira: ITDBA-3596) evaluating distributed database solutions — **TiDB** and **YugabyteDB** — for 104Corp. The current state is documentation and planning; infrastructure code has not yet been written.

**Goal:** Validate that distributed database architecture can provide continuous service (no downtime from any single failure), comparing TiDB and YugabyteDB across 9 dimensions: consistency, availability, scalability, multi-region writes, failover, network resilience, conflict handling, operability, and cost.

## Documentation Reading Order

1. `README.md` — PoC goals, current status, and doc index
2. `docs/survey.md` — 9-dimension technology comparison matrix (TiDB vs. YugabyteDB vs. Vitess)
3. `docs/test-design.md` — Test case definitions, metrics, and acceptance criteria
4. `docs/execution-runbook.md` — Deployment procedure, IaC requirements, and phase breakdown
5. `docs/architecture/tidb.md` — TiDB scenario analysis, Route A/B configs, architecture diagrams
6. `docs/architecture/yugabytedb.md` — YugabyteDB equivalent

## Testbed

5 VMs (4 vCPU / 16GB RAM / 200GB each): IDC 3 VMs (172.24.*.*) + GCP 2 VMs (10.160.*.*)

**TiDB roles:** TiDB (SQL) + PD (control plane / TSO) + TiKV (storage, Raft)
**YugabyteDB roles:** yb-tserver (YSQL + storage) + yb-master (control plane, Raft)
**Note:** YSQL is not a separate process — it runs inside yb-tserver.

## Multi-Site Architecture Routes

The architecture supports two deployment routes depending on which site must survive a link failure. **Route A and Route B are mutually exclusive with 5 VMs.**

| Route | Control plane quorum | TiKV / tablet replica | Survives IDC link failure? |
|-------|---------------------|----------------------|--------------------------|
| **Route A** — IDC primary | 3 IDC + 0 GCP | 2 IDC + 1 GCP per group | IDC ✅ GCP ❌ |
| **Route B** — GCP primary | 1 IDC + 2 GCP | 1 IDC + 2 GCP per group | GCP ✅ IDC ❌ |
| **Route C** — both independent | ≥3 each site | ≥3 each site | Both ✅ (needs >5 VMs) |

**Control plane:** TiDB = PD nodes; YugabyteDB = yb-master nodes.

## Four Validation Scenarios

| # | Link | Traffic | Required Route |
|---|------|---------|---------------|
| S1 | Normal | IDC 50% / GCP 50% | A or B |
| S2 | Normal | Shift all to GCP (planned) | A or B |
| S3 | Down | IDC continues | Route A only |
| S4 | Down | GCP continues | Route B only |

S3 and S4 require separate deployments. Switching between routes is done via rolling control-plane migration (no downtime) — see `docs/execution-runbook.md` Section 14.

## Key Test Cases

All test cases in `docs/test-design.md`. Critical ones:

- **TC-01** — Concurrent same-row updates (32/64/128 concurrency, 10+ min)
- **TC-02** — Multi-region write latency vs. TSO/HLC quorum path
- **TC-03** — Follower read / stale read staleness and latency
- **TC-04** — Node failure RTO under continuous load
- **TC-05** — Network partition: quorum preservation, fail-closed behavior
- **TC-MS-01~04** — Four multi-site scenarios (S1–S4 above)

**Primary metrics:** p95/p99 latency, commit latency, abort rate, time-to-new-leader, write unavailability window.

## Infrastructure Stack

| Layer | Technology |
|-------|-----------|
| Provisioning | Terraform (vSphere + GCP) |
| Configuration | Ansible |
| OS | AlmaLinux |
| Load testing | sysbench or k6 |
| Metrics | Prometheus + Grafana (planned) |
| Network fault injection | `iptables` (partition) + `tc` (delay) |

Directory layout (skeleton created, not yet implemented):
```
infra/terraform/{gcp,vsphere}/
infra/ansible/{inventories,group_vars,roles,playbooks}/
tests/{common,tidb,yugabytedb}/
results/{logs,metrics,reports}/
```

## Important Context

- TiDB transaction model: Percolator + 2PC, TSO from PD for global ordering
- YugabyteDB transaction model: DocDB intent-based, HLC (Hybrid Logical Clocks)
- Any TiDB node can route to any TiKV Region leader — no local affinity
- PD placement rules (TiDB) and tablespace placement policy (YugabyteDB) control replica distribution per route
- vSphere and GCP environment details (project IDs, VPC, datastores) are TBD — leave as Ansible/Terraform variables
- Port assignments: TiDB SQL=4000, PD RPC=2379, PD peer=2380, TiKV=20160; YugabyteDB YSQL=5433, master RPC=7100, tserver RPC=9100
