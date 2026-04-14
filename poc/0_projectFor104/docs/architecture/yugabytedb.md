# YugabyteDB IDC-GCP Mermaid Draft

## 1. Logical Architecture

```mermaid
flowchart LR
    C1[App Client / Test Client]

    subgraph API[YSQL Layer]
        Y1[YSQL on vm01 IDC]
        Y2[YSQL on vm02 IDC]
        Y3[YSQL on vm03 IDC]
        Y4[YSQL on vm04 GCP]
        Y5[YSQL on vm05 GCP]
    end

    subgraph MASTER[Control Plane]
        M1[yb-master vm01 IDC]
        M2[yb-master vm02 IDC]
        M3[yb-master vm03 IDC]
    end

    subgraph TSERVER[Storage / Query Nodes]
        S1[yb-tserver vm01 IDC]
        S2[yb-tserver vm02 IDC]
        S3[yb-tserver vm03 IDC]
        S4[yb-tserver vm04 GCP]
        S5[yb-tserver vm05 GCP]
    end

    C1 -->|TCP/5433 YSQL| Y1
    C1 -->|TCP/5433 YSQL| Y4
    C1 -->|TCP/5433 YSQL| Y5

    M1 <-->|TCP/7100 master RPC| M2
    M2 <-->|TCP/7100 master RPC| M3

    M1 -->|TCP/7100 / 9100 control| S1
    M1 -->|TCP/7100 / 9100 control| S2
    M1 -->|TCP/7100 / 9100 control| S3
    M1 -->|TCP/7100 / 9100 control| S4
    M1 -->|TCP/7100 / 9100 control| S5

    S1 <-->|TCP/9100 Raft replication| S2
    S2 <-->|TCP/9100 Raft replication| S3
    S3 <-->|TCP/9100 Raft replication| S4
    S4 <-->|TCP/9100 Raft replication| S5
```

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

    VM1 <-->|TCP/7100 master RPC| VM2
    VM2 <-->|TCP/7100 master RPC| VM3

    VM1 <-->|TCP/9100 tserver RPC| VM2
    VM2 <-->|TCP/9100 tserver RPC| VM3
    VM3 <-->|TCP/9100 tserver RPC| VM4
    VM4 <-->|TCP/9100 tserver RPC| VM5

    VM1 -->|TCP/7100 / 9100 control| VM4
    VM1 -->|TCP/7100 / 9100 control| VM5

    VM5 -->|TCP/5433 YSQL traffic| VM4
    VM5 -->|TCP/5433 YSQL traffic| VM1
```

## 3. Drawing Notes

- Master quorum in IDC
- TServer distributed across IDC and GCP
- Cross-site Raft replication between IDC and GCP
- Placement policy directly affects failover and write latency
- PoC mixed-role deployment, not production best practice
