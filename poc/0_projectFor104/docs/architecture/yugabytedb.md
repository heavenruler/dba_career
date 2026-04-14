# YugabyteDB IDC-GCP Architecture

## 1. Logical Architecture

```mermaid
flowchart LR
    C1[App Client / Test Client]

    subgraph MASTER[Control Plane - yb-master Raft]
        M1[yb-master vm01 IDC]
        M2[yb-master vm02 IDC]
        M3[yb-master vm03 IDC]
    end

    subgraph TSERVER[yb-tserver - YSQL + Storage]
        S1[yb-tserver vm01 IDC]
        S2[yb-tserver vm02 IDC]
        S3[yb-tserver vm03 IDC]
        S4[yb-tserver vm04 GCP]
        S5[yb-tserver vm05 GCP]
    end

    C1 -->|TCP/5433 YSQL| S1
    C1 -->|TCP/5433 YSQL| S4
    C1 -->|TCP/5433 YSQL| S5

    M1 <-->|TCP/7100 Raft| M2
    M1 <-->|TCP/7100 Raft| M3
    M2 <-->|TCP/7100 Raft| M3

    M1 -->|TCP/7100 / 9100 tablet mgmt| S1
    M1 -->|TCP/7100 / 9100 tablet mgmt| S2
    M1 -->|TCP/7100 / 9100 tablet mgmt| S3
    M1 -->|TCP/7100 / 9100 tablet mgmt| S4
    M1 -->|TCP/7100 / 9100 tablet mgmt| S5
    M2 -->|TCP/7100 / 9100 tablet mgmt| S1
    M2 -->|TCP/7100 / 9100 tablet mgmt| S4
    M3 -->|TCP/7100 / 9100 tablet mgmt| S2
    M3 -->|TCP/7100 / 9100 tablet mgmt| S5

    S1 <-->|TCP/9100 Raft RF=3| S2
    S1 <-->|TCP/9100 Raft RF=3| S4
    S2 <-->|TCP/9100 Raft RF=3| S3
    S2 <-->|TCP/9100 Raft RF=3| S5
    S3 <-->|TCP/9100 Raft RF=3 cross-site| S4
```

**Notes:**
- YSQL is the PostgreSQL-compatible SQL engine running **inside** yb-tserver; it is not a separate process or layer
- Any yb-tserver can accept client connections (TCP/5433); cross-site connections shown are representative
- yb-master leader handles tablet placement and load balancing; all masters participate in Raft and heartbeat with tservers
- Each tablet Raft group has RF=3 replicas; with geo-placement policy, replicas span IDC and GCP

## 2. Physical Deployment

```mermaid
flowchart TB
    subgraph IDC[IDC 172.24.*.*]
        VM1[vm01\nyb-master + yb-tserver]
        VM2[vm02\nyb-master + yb-tserver]
        VM3[vm03\nyb-master + yb-tserver]
    end

    subgraph GCP[GCP 10.160.*.*]
        VM4[vm04\nyb-tserver]
        VM5[vm05\nyb-tserver + Test Client]
    end

    VM1 <-->|TCP/7100 master Raft| VM2
    VM1 <-->|TCP/7100 master Raft| VM3
    VM2 <-->|TCP/7100 master Raft| VM3

    VM1 <-->|TCP/9100 tserver Raft| VM2
    VM1 <-->|TCP/9100 tserver Raft| VM3
    VM2 <-->|TCP/9100 tserver Raft| VM3
    VM3 <-->|TCP/9100 tserver Raft cross-site| VM4
    VM3 <-->|TCP/9100 tserver Raft cross-site| VM5
    VM4 <-->|TCP/9100 tserver Raft| VM5

    VM1 -->|TCP/7100 / 9100 tablet mgmt| VM4
    VM1 -->|TCP/7100 / 9100 tablet mgmt| VM5
    VM2 -->|TCP/7100 / 9100 tablet mgmt| VM4
    VM3 -->|TCP/7100 / 9100 tablet mgmt| VM5
```

## 3. Drawing Notes

- Master quorum in IDC (3 nodes); master leader manages tablet placement across all tservers
- YSQL runs inside yb-tserver — no separate SQL proxy process
- Tablet Raft groups (RF=3) span IDC and GCP; cross-site replication latency directly affects commit latency
- Placement policy (tablespace) controls which sites hold tablet leaders, affecting write latency distribution
- PoC mixed-role deployment, not production best practice
