# TiDB IDC-GCP Architecture

## 1. Scenario Analysis

四個驗證情境與對架構的技術要求：

| # | 專線 | 流量 | PD quorum 需求 | TiKV replica 需求 |
|---|------|------|---------------|-----------------|
| S1 | 正常 | IDC 50% / GCP 50% | 兩站皆可達任一 PD | 跨站皆有 replica |
| S2 | 正常 | 全切至 GCP（計劃性） | GCP TiDB 可達 IDC PD（link OK） | 跨站皆有 replica |
| S3 | 中斷 | 流量維持在 IDC | **IDC 需有 PD quorum（≥2/3）** | IDC TiKV ≥2 replica per Region |
| S4 | 中斷 | 流量維持在 GCP | **GCP 需有 PD quorum（≥2/3）** | GCP TiKV ≥2 replica per Region |

**S3 與 S4 在 5 VM（3 IDC + 2 GCP）下互斥**
PD 3 節點只能讓一個 site 持有多數；TiKV RF=3 的 replica 也只能偏向一個 site。
要同時支援 S3 + S4，須擴充至每站 ≥3 PD 與 ≥3 TiKV（見 Route C）。

---

## 2. Route A — IDC Primary（支援 S1, S2, S3）

### 節點配置

| VM | Site | 角色 | 備註 |
|----|------|------|------|
| vm01 | IDC | PD + TiDB + TiKV | PD quorum 節點 |
| vm02 | IDC | PD + TiKV | PD quorum 節點 |
| vm03 | IDC | PD + TiKV | PD quorum 節點 |
| vm04 | GCP | TiDB + TiKV | 無 PD |
| vm05 | GCP | TiDB + TiKV + Client | 無 PD |

TiKV placement rule：每個 Region 強制 **2 IDC + 1 GCP** replica

### 斷線行為

| 對象 | 結果 | 原因 |
|------|------|------|
| IDC TiDB | ✅ 繼續運作 | IDC PD quorum 完整 |
| GCP TiDB | ❌ 停止寫入 | 無法跨站取得 TSO |

### Physical Deployment

```mermaid
flowchart TB
    subgraph IDC["IDC 172.24.*.* ── PD Quorum"]
        VM1[vm01\nPD + TiDB + TiKV]
        VM2[vm02\nPD + TiKV]
        VM3[vm03\nPD + TiKV]
    end

    subgraph GCP["GCP 10.160.*.*"]
        VM4[vm04\nTiDB + TiKV]
        VM5[vm05\nTiDB + TiKV + Client]
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

---

## 3. Route B — GCP Primary（支援 S1, S2, S4）

### 節點配置

| VM | Site | 角色 | 備註 |
|----|------|------|------|
| vm01 | IDC | PD + TiDB + TiKV | PD quorum 節點 |
| vm02 | IDC | TiKV | 無 PD |
| vm03 | IDC | TiKV | 無 PD |
| vm04 | GCP | PD + TiDB + TiKV | PD quorum 節點 |
| vm05 | GCP | PD + TiDB + TiKV + Client | PD quorum 節點 |

TiKV placement rule：每個 Region 強制 **1 IDC + 2 GCP** replica

### 斷線行為

| 對象 | 結果 | 原因 |
|------|------|------|
| GCP TiDB | ✅ 繼續運作 | GCP PD quorum 完整（2/3） |
| IDC TiDB | ❌ 停止寫入 | 僅剩 1 PD 節點，無法維持 quorum |

### Physical Deployment

```mermaid
flowchart TB
    subgraph IDC["IDC 172.24.*.*"]
        VM1[vm01\nPD + TiDB + TiKV]
        VM2[vm02\nTiKV]
        VM3[vm03\nTiKV]
    end

    subgraph GCP["GCP 10.160.*.* ── PD Quorum"]
        VM4[vm04\nPD + TiDB + TiKV]
        VM5[vm05\nPD + TiDB + TiKV + Client]
    end

    VM1 <-->|TCP/2380 PD Raft cross-site| VM4
    VM1 <-->|TCP/2380 PD Raft cross-site| VM5
    VM4 <-->|TCP/2380 PD Raft| VM5

    VM1 <-->|TCP/20160 TiKV Raft| VM2
    VM1 <-->|TCP/20160 TiKV Raft| VM3
    VM2 <-->|TCP/20160 TiKV Raft| VM3
    VM3 <-->|TCP/20160 TiKV Raft cross-site| VM4
    VM3 <-->|TCP/20160 TiKV Raft cross-site| VM5
    VM4 <-->|TCP/20160 TiKV Raft| VM5

    VM1 -->|TCP/2379 PD access| VM4
    VM1 -->|TCP/2379 PD access| VM5
    VM2 -->|TCP/2379 PD access| VM4
    VM2 -->|TCP/2379 PD access| VM5
    VM3 -->|TCP/2379 PD access| VM4
    VM3 -->|TCP/2379 PD access| VM5
```

---

## 4. Route C — 兩站皆可獨立（S3 + S4 同時支援）

需要每站各自形成 quorum，超出 5 VM 限制，需額外資源：

| 層級 | 最小需求 | 說明 |
|------|---------|------|
| PD | 3 IDC + 3 GCP（共 6） | 各站 3 節點才能獨立維持 quorum |
| TiKV | 3 IDC + 3 GCP（共 6），RF=3 | 各站 3 個 replica 才能在斷線後獨立服務 |
| 或：見證節點 | 任一第三站 1 個 PD | 作為 tie-breaker，不需各站對稱擴充 |

---

## 5. Logical Architecture

SQL Layer 與 Storage Layer 兩種 Route 相同；Control Plane 的 PD 位置依 Route 不同。

### Route A Logical（PD quorum in IDC）

```mermaid
flowchart LR
    C1[App Client / Test Client]

    subgraph SQL[SQL Layer]
        T1[TiDB vm01 IDC]
        T4[TiDB vm04 GCP]
        T5[TiDB vm05 GCP]
    end

    subgraph PD["Control Plane — PD Raft (IDC quorum)"]
        P1[PD vm01 IDC]
        P2[PD vm02 IDC]
        P3[PD vm03 IDC]
    end

    subgraph KV[Storage Layer — TiKV]
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

### Route B Logical（PD quorum in GCP）

```mermaid
flowchart LR
    C1[App Client / Test Client]

    subgraph SQL[SQL Layer]
        T1[TiDB vm01 IDC]
        T4[TiDB vm04 GCP]
        T5[TiDB vm05 GCP]
    end

    subgraph PD["Control Plane — PD Raft (GCP quorum)"]
        P1[PD vm01 IDC]
        P4[PD vm04 GCP]
        P5[PD vm05 GCP]
    end

    subgraph KV[Storage Layer — TiKV]
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
    T1 -->|TCP/2379 TSO + Region routing| P4
    T1 -->|TCP/2379 TSO + Region routing| P5
    T4 -->|TCP/2379 TSO + Region routing| P1
    T4 -->|TCP/2379 TSO + Region routing| P4
    T4 -->|TCP/2379 TSO + Region routing| P5
    T5 -->|TCP/2379 TSO + Region routing| P1
    T5 -->|TCP/2379 TSO + Region routing| P4
    T5 -->|TCP/2379 TSO + Region routing| P5

    T1 -->|TCP/20160 to Region leader| K1
    T1 -->|TCP/20160 to Region leader| K4
    T4 -->|TCP/20160 to Region leader| K1
    T4 -->|TCP/20160 to Region leader| K4
    T5 -->|TCP/20160 to Region leader| K3
    T5 -->|TCP/20160 to Region leader| K5

    K1 <-->|Raft RF=3| K2
    K1 <-->|Raft RF=3| K4
    K2 <-->|Raft RF=3| K5
    K3 <-->|Raft RF=3 cross-site| K4
    K4 <-->|Raft RF=3| K5

    P1 <-->|TCP/2380 Raft cross-site| P4
    P1 <-->|TCP/2380 Raft cross-site| P5
    P4 <-->|TCP/2380 Raft| P5
```

---

## 6. Placement Configuration

### TiKV Node Labels

```toml
# tikv.toml — IDC nodes (vm01, vm02, vm03)
[server]
labels = { region = "idc" }

# tikv.toml — GCP nodes (vm04, vm05)
[server]
labels = { region = "gcp" }
```

PD 需設定 `location-labels = ["region"]` 以啟用 label-aware 排程。

### PD Placement Rules

Route A（IDC primary：2 IDC + 1 GCP per Region）

```json
[
  {
    "group_id": "pd", "id": "idc-voter",
    "role": "voter", "count": 2,
    "label_constraints": [{"key": "region", "op": "in", "values": ["idc"]}]
  },
  {
    "group_id": "pd", "id": "gcp-voter",
    "role": "voter", "count": 1,
    "label_constraints": [{"key": "region", "op": "in", "values": ["gcp"]}]
  }
]
```

Route B（GCP primary：1 IDC + 2 GCP per Region）

```json
[
  {
    "group_id": "pd", "id": "idc-voter",
    "role": "voter", "count": 1,
    "label_constraints": [{"key": "region", "op": "in", "values": ["idc"]}]
  },
  {
    "group_id": "pd", "id": "gcp-voter",
    "role": "voter", "count": 2,
    "label_constraints": [{"key": "region", "op": "in", "values": ["gcp"]}]
  }
]
```

套用指令：
```bash
pd-ctl config placement-rules rule-bundle set pd --in=rules.json
```

---

## 7. Drawing Notes

- 任何 TiDB 節點都可路由到任意 TiKV Region leader，跨站連線為代表性標示
- 每個 Region Raft group 為 RF=3，replica 位置依 placement rule 決定
- PD quorum 決定哪個 site 在斷線後可獨立存活；Route A / B 為互斥選擇
- PoC mixed-role deployment，非 production 最佳實務
