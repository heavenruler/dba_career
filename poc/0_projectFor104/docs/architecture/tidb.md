# TiDB IDC-GCP Mermaid Draft

## 1. Logical Architecture

```mermaid
flowchart LR
    C1[App Client / Test Client]

    subgraph SQL[SQL Layer]
        T1[TiDB vm01 IDC]
        T4[TiDB vm04 GCP]
        T5[TiDB vm05 GCP]
    end

    subgraph PD[Control Plane]
        P1[PD vm01 IDC]
        P2[PD vm02 IDC]
        P3[PD vm03 IDC]
    end

    subgraph KV[Storage Layer]
        K1[TiKV vm01 IDC]
        K2[TiKV vm02 IDC]
        K3[TiKV vm03 IDC]
        K4[TiKV vm04 GCP]
        K5[TiKV vm05 GCP]
    end

    C1 -->|TCP/4000| T1
    C1 -->|TCP/4000| T4
    C1 -->|TCP/4000| T5

    T1 -->|TCP/2379 TSO / metadata| P1
    T1 -->|TCP/2379 TSO / metadata| P2
    T1 -->|TCP/2379 TSO / metadata| P3
    T4 -->|TCP/2379 TSO / metadata| P1
    T5 -->|TCP/2379 TSO / metadata| P1

    T1 -->|TCP/20160 KV access| K1
    T1 -->|TCP/20160 KV access| K2
    T4 -->|TCP/20160 KV access| K4
    T5 -->|TCP/20160 KV access| K5

    K1 <-->|TCP/20160 Raft replication| K2
    K2 <-->|TCP/20160 Raft replication| K3
    K3 <-->|TCP/20160 Raft replication| K4
    K4 <-->|TCP/20160 Raft replication| K5

    P1 <-->|TCP/2380 PD peer| P2
    P2 <-->|TCP/2380 PD peer| P3
```

## 2. Physical Deployment

```mermaid
flowchart TB
    subgraph IDC[IDC 172.24.*.*]
        VM1[vm01\nPD + TiDB + TiKV]
        VM2[vm02\nPD + TiKV]
        VM3[vm03\nPD + TiKV]
    end

    subgraph GCP[GCP 10.160.*.*]
        VM4[vm04\nTiDB + TiKV]
        VM5[vm05\nTiDB + TiKV + Test Client]
    end

    VM1 <-->|TCP/2380 PD peer| VM2
    VM2 <-->|TCP/2380 PD peer| VM3

    VM1 <-->|TCP/20160 TiKV Raft| VM2
    VM2 <-->|TCP/20160 TiKV Raft| VM3
    VM3 <-->|TCP/20160 TiKV Raft| VM4
    VM4 <-->|TCP/20160 TiKV Raft| VM5

    VM4 -->|TCP/2379 PD access| VM1
    VM5 -->|TCP/2379 PD access| VM1

    VM5 -->|TCP/4000 SQL traffic| VM4
    VM5 -->|TCP/4000 SQL traffic| VM1
```

## 3. Drawing Notes

- PD quorum in IDC
- SQL entry in IDC and GCP
- Cross-site TiKV replication between IDC and GCP
- PoC mixed-role deployment, not production best practice
- No dedicated monitoring / bastion / automation node
