# tidb-tc1 / S-BASE — VM vs K8s TPC-C 對照

## TL;DR

**k8s-limit 損耗遠超預期。** 原本預估高 thread 才有感，實際從 16t 就已損耗 18%，
64t+ 穩定在 **-37%**。

k8s-unlimit 的 tpmC 在 64→128t 仍有小幅增長（18,456 → 18,842），
而 k8s-limit 幾乎持平（11,729 → 11,823），確認 **TiKV 2c CPU ceiling 就是瓶頸**。

### Scaling 對照

| variant | 16t | 32t | 64t | 128t | scaling (16→128) |
|---------|-----|-----|-----|------|-----------------|
| vm           | —      | —      | —      | —      | —    |
| k8s-unlimit  | 13,668 | 16,992 | 18,456 | 18,842 | **+38%** |
| k8s-limit    | 11,156 | 11,508 | 11,729 | 11,823 | **+6%（觸頂）** |

### 建議

TiKV 觀測到 ~2c 飽和於 18,842 tpmC（unlimit 峰值），現行 limit `2c/8Gi` 過嚴。
- **方案 A**：limit 上調至 `3c/12Gi` 重測，目標 tpmC 損耗 < 10%
- **方案 B**：DB Pod 改用 **Guaranteed QoS**（requests=limits），消除 burst 抖動
- 不建議生產採用目前的 k8s-limit 配置

---

## 架構規格

### 硬體（共用）

| 節點 | IP | vCPU | RAM | Disk |
|------|----|------|-----|------|
| poc-1 | 172.24.40.32 | 4 | 15 GB | 99 GB |
| poc-2 | 172.24.40.33 | 4 | 15 GB | 99 GB |
| poc-3 | 172.24.40.34 | 4 | 15 GB | 99 GB |
| client | 172.24.40.31 | 4 | 15 GB | — |

### Resource limits 對照（K8s only）

| 元件 | requests | k8s-unlimit | k8s-limit | PV |
|------|---------|-------------|-----------|-----|
| PD   × 3 | 500m / 1Gi | 無上限 | 1c / 2Gi | 10 Gi (local-path) |
| TiDB × 2 | 500m / 1Gi | 無上限 | 1c / 3Gi | — |
| TiKV × 3 | 1c / 4Gi   | 無上限 | **2c / 8Gi** | 100 Gi (local-path) |

### VM 部署（Variant: vm）

```
172.24.40.31 (client)
     │  go-tpc → :4000
     ▼
172.24.40.34  HAProxy :4000
     │  roundrobin
     ├─▶ 172.24.40.32  TiDB + PD + TiKV
     └─▶ 172.24.40.33  TiDB + PD + TiKV
         172.24.40.34            PD + TiKV

processes: 直接跑於 OS，無容器層
TiKV RF=3，每節點 30 GB data dir
```

### K8s 部署（Variant: k8s-unlimit / k8s-limit）

```
172.24.40.31 (client)
     │  go-tpc → :30004
     ▼
172.24.40.32  NodePort :30004
     │
     │  k3s cluster
     ├─ poc-1  k3s server  ┐
     ├─ poc-2  k3s agent   ├─ TiDB Operator v1.6.5 / TiDB v8.5.2
     └─ poc-3  k3s agent   ┘
          │
          └─ PD × 3、TiDB × 2、TiKV × 3（resource 詳見上表）

overhead: k3s control plane 跑於 poc-1，佔約 1 vCPU / 1~2 GB RAM（納入比較）
```

---

## TPC-C 結果對照

### tpmC

| threads | vm | k8s-unlimit | k8s-limit |
|---------|----|----|----|
| 16  | — | 13,668 | 11,156 |
| 32  | — | 16,992 | 11,508 |
| 64  | — | 18,456 | 11,729 |
| 128 | — | 18,842 | 11,823 |

### NEW_ORDER p99 (ms)

| threads | vm | k8s-unlimit | k8s-limit |
|---------|----|----|----|
| 16  | — | 56.6  | 96.5  |
| 32  | — | 104.9 | 201.3 |
| 64  | — | 218.1 | 352.3 |
| 128 | — | 436.2 | 704.6 |

### PAYMENT p99 (ms)

| threads | vm | k8s-unlimit | k8s-limit |
|---------|----|----|----|
| 16  | — | 37.7  | 65.0  |
| 32  | — | 75.5  | 134.2 |
| 64  | — | 176.2 | 268.4 |
| 128 | — | 385.9 | 637.5 |

> 參數：WAREHOUSES=128，DURATION=10m，WARMUP=5m
> 來源：
> - `results/tidb-tc1/S-BASE/k8s-unlimit/20260427-1241/`
> - `results/tidb-tc1/S-BASE/k8s-limit/20260427-1431/`
> - vm 待補

---

## 效能損耗分析

### 量測一：VM → K8s-unlimit（容器層 + CNI overhead）

> **假設**：受控變數不變，僅引入 containerd + flannel CNI。預期損耗 < 5%（local-path PV、同 LAN、無 CPU limit）。

| threads | tpmC 比值 (k8s-unlimit / vm) | NO p99 delta (ms) | 判定 |
|---------|------------------------------|-------------------|------|
| 16  | — | — | — |
| 32  | — | — | — |
| 64  | — | — | — |
| 128 | — | — | — |

**結論**：待 VM 數據補入。

---

### 量測二：K8s-unlimit → K8s-limit（resource limits 影響）

> **原假設**：低 thread 數無感；高 thread 數（≥ 64）若 TiKV CPU 觸頂則 tpmC 下降、p99 上升。
> **實際結果**：❌ 假設不成立 — 低 thread 已大幅損耗。

| threads | k8s-unlimit | k8s-limit | 比值 | tpmC 損耗 | NO p99 delta | PAY p99 delta | 判定 |
|---------|-------------|-----------|------|-----------|--------------|---------------|------|
| 16  | 13,668 | 11,156 | 0.816 | **-18.4%** | +39.9 ms  | +27.3 ms  | ⚠️ 超預期 |
| 32  | 16,992 | 11,508 | 0.677 | **-32.3%** | +96.4 ms  | +58.7 ms  | ❌ 嚴重 |
| 64  | 18,456 | 11,729 | 0.635 | **-36.5%** | +134.2 ms | +92.2 ms  | ❌ 嚴重 |
| 128 | 18,842 | 11,823 | 0.628 | **-37.2%** | +268.4 ms | +251.6 ms | ❌ 嚴重 |

**結論**：limits 設定過嚴，TiKV 2c 上限已成瓶頸。
tpmC 在 limit 模式下從 16t 起即出現 18% 損耗，64t 以上穩定在 -37%
且 tpmC 幾乎不增長（11,729 → 11,823），確認 CPU ceiling 已觸頂。
k8s-limit 配置不適合此工作負載，需依 TL;DR 建議調整。

---

## 綜合結論

| 比較組 | tpmC 損耗 | NO p99 影響 | 備註 |
|--------|-----------|-------------|------|
| VM → K8s-unlimit         | 待補 | 待補 | 純容器層開銷 |
| K8s-unlimit → K8s-limit  | **-18% ~ -37%** | +40 ~ +268 ms | TiKV 2c limit 觸頂 |
| VM → K8s-limit           | 待補 | 待補 | 實際生產部署總損耗 |
