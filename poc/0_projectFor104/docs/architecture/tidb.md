# TiDB IDC-GCP Architecture

## 1. Logical Architecture

```mermaid
flowchart LR
    C1[App Client / Test Client]

    subgraph SQL[SQL Layer]
        T1[TiDB\nvm01 IDC]
        T4[TiDB\nvm04 GCP]
        T5[TiDB\nvm05 GCP]
    end

    subgraph PD[Control Plane - PD Raft]
        P1[PD vm01 IDC]
        P2[PD vm02 IDC]
        P3[PD vm03 IDC]
    end

    subgraph KV[Storage Layer - TiKV]
        K1[TiKV vm01 IDC]
        K2[TiKV vm02 IDC]
        K3[TiKV vm03 IDC]
        K4[TiKV vm04 GCP]
        K5[TiKV vm05 GCP]
    end

    C1 -->|TCP/4000| T1
    C1 -->|TCP/4000| T4
    C1 -->|TCP/4000| T5

    T1 -->|TCP/2379 TSO + Region routing| P1
    T1 -->|TCP/2379 TSO + Region routing| P2
    T1 -->|TCP/2379 TSO + Region routing| P3
    T4 -->|TCP/2379 TSO + Region routing| P1
    T4 -->|TCP/2379 TSO + Region routing| P2
    T4 -->|TCP/2379 TSO + Region routing| P3
    T5 -->|TCP/2379 TSO + Region routing| P1
    T5 -->|TCP/2379 TSO + Region routing| P2
    T5 -->|TCP/2379 TSO + Region routing| P3

    T1 -->|TCP/20160 to Region leader| K1
    T1 -->|TCP/20160 to Region leader| K4
    T4 -->|TCP/20160 to Region leader| K2
    T4 -->|TCP/20160 to Region leader| K4
    T5 -->|TCP/20160 to Region leader| K3
    T5 -->|TCP/20160 to Region leader| K5

    K1 <-->|Raft RF=3| K2
    K1 <-->|Raft RF=3| K4
    K2 <-->|Raft RF=3| K3
    K2 <-->|Raft RF=3| K5
    K3 <-->|Raft RF=3 cross-site| K4

    P1 <-->|TCP/2380 Raft| P2
    P1 <-->|TCP/2380 Raft| P3
    P2 <-->|TCP/2380 Raft| P3
```

**Notes:**
- TiDB uses PD to locate Region leader; any TiDB can reach any TiKV — cross-site connections shown are representative
- Each Region Raft group has RF=3 replicas; PD schedules placement across IDC and GCP to ensure cross-site quorum
- All TiDB nodes must connect to all PD nodes for TSO and Region routing

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

    VM1 <-->|TCP/2380 PD Raft| VM2
    VM1 <-->|TCP/2380 PD Raft| VM3
    VM2 <-->|TCP/2380 PD Raft| VM3

    VM1 <-->|TCP/20160 TiKV Raft| VM2
    VM1 <-->|TCP/20160 TiKV Raft| VM3
    VM2 <-->|TCP/20160 TiKV Raft| VM3
    VM3 <-->|TCP/20160 TiKV Raft cross-site| VM4
    VM3 <-->|TCP/20160 TiKV Raft cross-site| VM5
    VM4 <-->|TCP/20160 TiKV Raft| VM5

    VM4 -->|TCP/2379 PD access| VM1
    VM4 -->|TCP/2379 PD access| VM2
    VM4 -->|TCP/2379 PD access| VM3
    VM5 -->|TCP/2379 PD access| VM1
    VM5 -->|TCP/2379 PD access| VM2
    VM5 -->|TCP/2379 PD access| VM3
```

## 3. Drawing Notes

- PD quorum in IDC (3 nodes); GCP TiDB access all PD nodes for TSO
- Any TiDB can route to any TiKV Region leader regardless of site
- Each TiKV Raft group spans IDC and GCP nodes (RF=3); cross-site Raft write latency is expected
- PoC mixed-role deployment, not production best practice
- No dedicated monitoring / bastion / automation node
