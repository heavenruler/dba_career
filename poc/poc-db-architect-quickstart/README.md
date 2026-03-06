# poc-db-architect-quickstart

A macOS-friendly local **database architecture lab** powered by Podman and `podman kube play`.

This repository is scenario-driven so architects can quickly switch between topology patterns.

## Quick Start (5 minutes)

```bash
# 1) Install podman
brew install podman

# 2) Init and start VM
podman machine init
podman machine start

# 3) Enter project
cd poc-db-architect-quickstart

# 4) Start first scenario
make up SCENARIO=redis-standalone

# 5) Verify
make verify SCENARIO=redis-standalone
```

## Prerequisites

- macOS host
- Podman 4+
- `podman machine` working
- `make`

## Scenario Catalog

```bash
make list
```

Current scenarios:

- `redis-standalone` (single node)
- `redis-replication` (1 master + 2 replicas)
- `redis-sentinel` (master/replica + 3 sentinel nodes)
- `redis-cluster` (6-node Redis cluster)

## Operations Interface

```bash
make up SCENARIO=<name>
make down SCENARIO=<name>
make reset SCENARIO=<name>
make verify SCENARIO=<name>
make logs SCENARIO=<name>
```

## Architecture Diagrams

### redis-standalone

```text
Client -> 127.0.0.1:6379 -> redis-standalone-1
```

### redis-replication

```text
                +----------------------------+
Client -> 6380  | redis-replication-master-1 |
                +----------------------------+
                    |                |
                 sync to          sync to
                    v                v
            +----------------+  +----------------+
Client->6381| replica-1      |  | replica-2      |<-Client->6382
            +----------------+  +----------------+
```

### redis-sentinel

```text
Data Plane:
  master(6390) <-> replica(6391)
Control Plane:
  sentinel-1(26379)
  sentinel-2(26380)
  sentinel-3(26381)
```

### redis-cluster

```text
7001 7002 7003 (masters)
7004 7005 7006 (replicas)
Hash slots are distributed after cluster bootstrap.
```

## Login Instructions

See each scenario document:

- `scenarios/redis-standalone/login.md`
- `scenarios/redis-replication/login.md`
- `scenarios/redis-sentinel/login.md`
- `scenarios/redis-cluster/login.md`

## Verify Commands

```bash
make verify SCENARIO=redis-standalone
make verify SCENARIO=redis-replication
make verify SCENARIO=redis-sentinel
make verify SCENARIO=redis-cluster
```

## Extending the Lab

To add a new scenario:

1. Create `scenarios/<new-scenario>/kube.yaml`
2. Add `scenarios/<new-scenario>/verify.sh`
3. Add `scenarios/<new-scenario>/login.md`
4. Run using existing Make targets

Suggested future additions:

- `mysql-standalone`
- `mysql-group-replication`
- `postgres-ha`
- `mongo-replica-set`
- `tidb-local`
