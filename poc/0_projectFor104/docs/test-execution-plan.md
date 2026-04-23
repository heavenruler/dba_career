# Test Execution Plan

本文件定義「如何執行」測試，對應 `docs/test-design.md`（定義「測什麼」）。

## 1. 名詞定義

| 層次 | 名稱 | 意義 |
|------|------|------|
| L0 | **Topo** | Makefile 定義的部署拓樸（tidb-tc1/tc2/tc3、yuga-tc1/tc2/tc3） |
| L1 | **Scenario** | 要驗證的功能行為（對應 test-design.md TC-xx） |

兩者為不同概念，不可混用。

---

## 2. 拓樸摘要（Makefile 現況）

| Topo | 節點範圍 | RF | PD/Master 位置 | 備註 |
|------|---------|-----|--------------|------|
| `tidb-tc1` | IDC×3 | 3 | IDC×3 | 純單站 HA |
| `tidb-tc2` | IDC×2 + GCP×1 | 2 | IDC×2 + GCP×1 | IDC primary，最小跨站 |
| `tidb-tc3` | IDC×3 + GCP×2 | 3 | IDC×2 + GCP×1 | IDC primary，全節點 |
| `tidb-tc4` | IDC×3 + GCP×2 | 3 | IDC×1 + GCP×2 | **GCP primary（Route B）** |
| `yuga-tc1` | IDC×3 | 3 | IDC×3 | 純單站 HA |
| `yuga-tc2` | IDC×3 + GCP×2 | 3 | IDC×2 + GCP×1 | IDC primary，follower reads |
| `yuga-tc3` | IDC×3 + GCP×2 | 5 | IDC×2 + GCP×1 | IDC primary，RF=5，100GB |
| `yuga-tc4` | IDC×3 + GCP×2 | 3 | IDC×1 + GCP×2 | **GCP primary（Route B）** |

---

## 3. Scenario 定義

### 3.1 共同執行（TiDB + YugabyteDB 各跑一遍，結果對比）

| Scenario ID | 說明 | 對應 test-design | 測試工具 |
|-------------|------|----------------|---------|
| S-BASE | TPC-C 基線壓測 | — | go-tpc |
| S-HA | 單站 node failure RTO | TC-04 | k6 + kill process |
| S-PART | 單站內 network partition | TC-05 | iptables |
| S-WRITE | 跨站寫入延遲（per-site p95/p99） | TC-02 | k6 |
| S-READ | Follower read delay / stale lag | TC-03 | k6 |
| S-HOT | 同 row 高併發 update（32/64/128） | TC-01 | k6 |
| S-5050 | 雙站各 50% 流量穩定性 | TC-MS-01 | k6 ×2 sites |
| S-SHIFT | 計劃性流量 IDC→GCP（無中斷） | TC-MS-02 | k6 + LB 切換 |
| S-IDC-SOLO | iptables 斷線，IDC 繼續（IDC primary） | TC-MS-03 | iptables |
| S-CHAOS-DELAY | tc netem 加延遲/丟包模擬專線不穩 | — | tc netem |
| S-CHAOS-FLAP | iptables 間歇性斷線 30s×3 | — | iptables script |

### 3.2 TiDB 專屬

| Scenario ID | 說明 | 對應 test-design | Topo | 工具 |
|-------------|------|----------------|------|------|
| T-TSO | TSO 取得成本 vs TiKV quorum 成本分離 | TiDB-01 | tc2 vs tc3 | Prometheus PD metrics |
| T-STALREAD | leader / follower / stale read 三模式對比 | TiDB-02 | tc3 | k6 + `SET tidb_replica_read` |
| T-DDL | Online ADD INDEX 對熱寫影響 | TiDB-03 | tc3 | k6 持續打 + 背景 DDL |

### 3.3 YugabyteDB 專屬

| Scenario ID | 說明 | 對應 test-design | Topo | 工具 |
|-------------|------|----------------|------|------|
| Y-HLC | HLC transaction restart / kConflict 分布 | YB-01 | tc2/tc3 | k6 高衝突 + YB metrics |
| Y-GEO | tablespace placement policy → failover 結果 | YB-02 | tc2/tc3 | yb-admin + k6 |
| Y-RF5 | RF=5 雙節點容錯驗證 | — | tc3 | kill 2 nodes + k6 |

---

## 4. Scenario × Topo 對應表

| Scenario | tidb-tc1 | tidb-tc2 | tidb-tc3 | tidb-tc4 | yuga-tc1 | yuga-tc2 | yuga-tc3 | yuga-tc4 |
|----------|:--------:|:--------:|:--------:|:--------:|:--------:|:--------:|:--------:|:--------:|
| S-BASE   | ✅ | — | ✅ | — | ✅ | — | ✅ | — |
| S-HA     | ✅ | — | — | — | ✅ | — | — | — |
| S-PART   | ✅ | — | — | — | ✅ | — | — | — |
| S-WRITE  | — | ✅ | ✅ | ✅ | — | ✅ | ✅ | ✅ |
| S-READ   | — | ✅ | ✅ | ✅ | — | ✅ | ✅ | ✅ |
| S-HOT    | — | — | ✅ | — | — | — | ✅ | — |
| S-5050   | — | — | ✅ | ✅ | — | — | ✅ | ✅ |
| S-SHIFT  | — | — | ✅ | ✅ | — | — | ✅ | ✅ |
| S-IDC-SOLO | — | — | ✅ | — | — | ✅ | ✅ | — |
| S-GCP-SOLO | — | — | — | ✅ | — | — | — | ✅ |
| S-CHAOS-DELAY | — | ✅ | ✅ | ✅ | — | ✅ | ✅ | ✅ |
| S-CHAOS-FLAP  | — | ✅ | ✅ | ✅ | — | ✅ | ✅ | ✅ |
| T-TSO    | — | ✅ | ✅ | ✅ | — | — | — | — |
| T-STALREAD | — | — | ✅ | — | — | — | — | — |
| T-DDL    | — | — | ✅ | — | — | — | — | — |
| Y-HLC    | — | — | — | — | — | ✅ | ✅ | ✅ |
| Y-GEO    | — | — | — | — | — | ✅ | ✅ | ✅ |
| Y-RF5    | — | — | — | — | — | — | ✅ | — |

---

## 5. 執行順序

```
Phase 1：單站 HA 基線
  tidb-tc1 → S-BASE → S-HA → S-PART
  yuga-tc1 → S-BASE → S-HA → S-PART

Phase 2：跨站寫入與讀取
  tidb-tc2 → S-WRITE → S-READ → S-IDC-SOLO → T-TSO → S-CHAOS-DELAY → S-CHAOS-FLAP
  yuga-tc2 → S-WRITE → S-READ → S-IDC-SOLO → Y-HLC → Y-GEO → S-CHAOS-DELAY → S-CHAOS-FLAP

Phase 3：全節點完整驗證
  tidb-tc3 → S-BASE → S-HOT → S-WRITE → S-READ
           → S-5050 → S-SHIFT → S-IDC-SOLO
           → S-CHAOS-DELAY → S-CHAOS-FLAP
           → T-TSO → T-STALREAD → T-DDL

  yuga-tc3 → S-BASE → S-HOT → S-WRITE → S-READ
           → S-5050 → S-SHIFT → S-IDC-SOLO
           → S-CHAOS-DELAY → S-CHAOS-FLAP
           → Y-HLC → Y-GEO → Y-RF5

Phase 4：GCP primary（待補）
  tidb-tc4 → S-GCP-SOLO（需先新增 Topo）
  yuga-tc4 → S-GCP-SOLO（需先新增 Topo）
```

---

## 6. 結果歸檔規範

```
results/
└── <topo>/               # e.g. tidb-tc3
    └── <scenario>/       # e.g. S-HOT
        └── <timestamp>/  # e.g. 20260423-1430
            ├── client.jsonl      # k6 / go-tpc raw output（每行一筆紀錄）
            ├── event.log         # 故障注入時間點紀錄
            ├── metrics.tar.gz    # Prometheus snapshot（測試前後各一次）
            └── summary.md        # pass/fail + 關鍵數字
```

每筆 client log 須包含欄位：`start_ts`, `end_ts`, `site`, `txn_type`, `error_code`, `retry_count`

---

## 7. 缺口與待補

| 項目 | 影響 Scenario | 建議處置 | 狀態 |
|------|-------------|---------|------|
| Route B Topo 未實作 | S-GCP-SOLO | 新增 `tidb-tc4` / `yuga-tc4`（1 IDC + 2 GCP master） | ✅ |
| TPC-C Makefile target 未定義 | S-BASE | 補 `make test-tpcc` | ⏳ |
| 故障注入無 Makefile target | S-HA / S-PART / S-IDC-SOLO / S-CHAOS-* | 補 `make fault-*` targets | ⏳ |
| 結果歸檔腳本未建立 | 全部 | 補 `tests/common/collect.sh` | ⏳ |
| k6 / go-tpc 腳本未建立 | 全部 | 補 `tests/common/` 與 `tests/tidb/` / `tests/yugabytedb/` | ⏳ |

---

## 8. VM vs K8s TPC-C 效能比較（待實作）

### 8.1 目的

量化相同硬體下，DB 部署在裸 VM 與 K8s 之間的 TPC-C 效能損耗或差異，作為架構選型依據。

### 8.2 比較框架

**受控變數（兩者保持一致）**

- 硬體：同一批 VM（poc-1/2/3，sequential 執行）
- DB 版本：相同
- TPC-C 參數：warehouses、concurrency、duration 一致
- 儲存：K8s 使用 local-path PV，掛載路徑對齊 VM 資料目錄

**測試變數（K8s 引入的差異）**

| 層次 | VM | K8s | 預期影響 |
|------|-----|-----|---------|
| 運算 | 直接 CPU/RAM | containerd + cgroup | resource limits 策略決定 |
| 網路 | 直接 IP | CNI overlay（flannel） | cross-node commit latency ↑ |
| 儲存 | 直接路徑 | PV/PVC → local-path | 差異最小化 |
| 排程 | 無 | kube-scheduler + kubelet | 固定背景消耗，約 1 vCPU / 1~2 GB |

**K8s resource limits 策略（兩輪）**

| 輪次 | limits 設定 | 量測目的 |
|------|------------|---------|
| K8s-unlimit | 不設 limits | container / CNI 純開銷下限 |
| K8s-limit | limits = VM 可用量 | 實際生產部署場景 |

### 8.3 主要量測指標

| 指標 | 說明 |
|------|------|
| `tpmC` | TPC-C 主指標，三組比較（VM / K8s-unlimit / K8s-limit） |
| `p99 commit latency` | CNI overlay 對尾延遲的影響最明顯 |
| `CPU utilization delta` | 相同 tpmC 下的 CPU 消耗差異 |
| `inter-node RTT` | VM 直連 vs CNI overlay 的網路延遲基線 |

### 8.4 已知限制

- K8s control plane 跑在 poc-1，佔用約 1 vCPU / 1~2 GB RAM，**納入**比較而非排除；結果需標記此 overhead
- 本比較不涵蓋：K8s 獨立 control plane 節點、雲端 managed K8s（GKE）vs VM

### 8.5 執行順序（tc1 範圍）

```
1. make tidb-tc1       → TPC-C (VM baseline)
2. make destroy-all
3. make apply-all + ansible-setup
4. make k8s-setup      ← 待實作（k3s on poc-1/2/3）
5. make tidb-tc1-k8s   ← 待實作（TiDB Operator，K8s-unlimit）
6. make tidb-tc1-k8s   ← 待實作（TiDB Operator，K8s-limit）
7. 比對 tpmC / p99 / CPU delta
```

### 8.6 待補實作項目

| 項目 | 狀態 |
|------|------|
| Ansible role：k3s server / agent 安裝 | ⏳ |
| Makefile target：`k8s-setup` | ⏳ |
| TiDB Operator + TidbCluster CRD（tc1 規格） | ⏳ |
| YugabyteDB Helm chart（tc1 規格） | ⏳ |
| Makefile target：`tidb-tc1-k8s` / `yuga-tc1-k8s` | ⏳ |
| TPC-C 執行腳本（go-tpc wrapper） | ⏳ |
| 結果比較報告模板 | ⏳ |
