# 分散式資料庫架構 PoC 實作項目 Runbook

## 1. 文件目的

本文件將 `docs/test-design.md` 轉換為可落地執行的實作項目，供 PoC 建置、測試、驗證與環境重建使用。

適用前提：

- 部署型態：VMware (vSphere) + GCP
- 作業系統：AlmaLinux
- IaC 工具：Terraform + Ansible
- PoC 產品：TiDB、YugabyteDB
- 架構圖層次：Logical Architecture + Physical Deployment
- 網路拓樸：IDC `172.24.*.*` <-> GCP `10.160.*.*`
- VM 總數限制：5 VMs
- 站點分布：IDC 3 VMs + GCP 2 VMs

## 2. 輸出目標

本階段需產出以下可執行成果：

- Terraform：GCP / vSphere 基礎資源建立
- Ansible：主機基線、套件安裝、系統參數、產品部署、測試前置設定
- 架構圖輸入資料：Logical / Physical deployment 所需節點與連線資訊
- Test Case 執行清單：可逐項落地執行
- 驗證結果保存目錄與命名規則
- 環境可重建、可抽換、可重跑

## 3. 目錄結構

```text
0_projectFor104/
├── README.md
├── docs/
│   ├── survey.md
│   ├── test-design.md
│   ├── execution-runbook.md
│   └── architecture/
│       ├── tidb.md
│       └── yugabytedb.md
├── infra/
│   ├── terraform/
│   │   ├── gcp/
│   │   └── vsphere/
│   └── ansible/
│       ├── inventories/
│       │   └── idc-gcp/
│       ├── group_vars/
│       ├── roles/
│       └── playbooks/
├── tests/
│   ├── common/
│   ├── tidb/
│   └── yugabytedb/
└── results/
    ├── logs/
    ├── metrics/
    └── reports/
```

## 4. 實作原則

- 所有節點建立與重建，優先透過 Terraform 完成
- 所有 OS 設定、套件安裝、DB 部署與測試前置，優先透過 Ansible 完成
- 測試資料、測試腳本、故障注入步驟需可重複執行
- 任何手動操作都要能在文件中被追蹤
- 同一套 5 VM 骨架需可重建為 TiDB 或 YugabyteDB 環境
- 本 Runbook 以 PoC mixed-role deployment 為前提，不等同 production 最佳實務

## 5. 環境實作項目

### EC-01 Terraform 基礎資源模板

| 欄位 | 內容 |
| --- | --- |
| Objective | 建立可重建的 IDC-GCP PoC 基礎設施模板 |
| Scope | VM、CPU、Memory、Disk、NIC、Subnet、Security Rule、DNS / hostname |
| Deliverable | `infra/terraform/gcp`、`infra/terraform/vsphere` |
| 完成標準 | 能成功建立 IDC 3 台 + GCP 2 台 VM，並輸出 inventory 所需資訊 |

實作項目：

- 建立 `terraform.tfvars` 範本
- 抽出共用變數：`site_pair`、`vm_count`、`vm_cpu`、`vm_memory_gb`、`vm_disk_gb`
- 建立命名規則：`poc-<product>-<site>-<role>-<seq>`
- 輸出 inventory 所需資訊：IP、hostname、role、site
- 固定支援 `idc-gcp` 站點組合

### EC-02 Ansible 主機基線

| 欄位 | 內容 |
| --- | --- |
| Objective | 建立 AlmaLinux 標準化主機基線 |
| Scope | 使用者、SSH、NTP、sysctl、ulimit、firewalld、SELinux、必要套件 |
| Deliverable | `infra/ansible/roles/common_baseline` |
| 完成標準 | 新建主機可透過單一 playbook 完成 baseline 設定 |

實作項目：

- 建立管理帳號與 SSH key 佈署
- 設定 NTP / Chrony
- 設定 `vm.max_map_count`、`nofile`、`nproc` 等系統參數
- 停用或調整 `firewalld` / `SELinux` 政策
- 安裝通用工具：`curl`、`wget`、`jq`、`tar`、`unzip`、`iperf3`、`sysstat`

### EC-03 網路與連線前置驗證

| 欄位 | 內容 |
| --- | --- |
| Objective | 確保兩地網路在部署前已具備 PoC 所需條件 |
| Scope | Route、Port、RTT、DNS / hostname 解析 |
| Deliverable | precheck 結果報告 |
| 完成標準 | 所有節點互通、必要 port 開放、RTT 可量測 |

實作項目：

- 建立 site matrix：`IDC <-> GCP`
- 測試節點間 ICMP / TCP 連線
- 量測 baseline RTT 與封包穩定度
- 確認 DB / 管理 port 可雙向通訊

## 6. 架構圖輸入資訊

架構圖草稿檔案：

- TiDB：[`docs/architecture/tidb.md`](./architecture/tidb.md)
- YugabyteDB：[`docs/architecture/yugabytedb.md`](./architecture/yugabytedb.md)

### AD-01 共用 VM 規劃

| VM | Site | 建議規格 | 用途 |
| --- | --- | --- | --- |
| `vm01` | IDC | 4 vCPU / 16 GB / 200 GB | DB node 1 |
| `vm02` | IDC | 4 vCPU / 16 GB / 200 GB | DB node 2 |
| `vm03` | IDC | 4 vCPU / 16 GB / 200 GB | DB node 3 |
| `vm04` | GCP | 4 vCPU / 16 GB / 200 GB | DB node 4 |
| `vm05` | GCP | 4 vCPU / 16 GB / 200 GB | DB node 5 / test client |

說明：

- 本配置以 5 VM PoC 為前提，採 mixed-role deployment
- 同一套 5 VM 骨架建議分批部署 TiDB 與 YugabyteDB，不建議同時常駐
- 架構圖需同時表達 logical 與 physical deployment

## 7. TiDB 實作項目

### TC-DEP-01 TiDB 拓樸與節點規劃

| 欄位 | 內容 |
| --- | --- |
| Objective | 定義 TiDB PoC 在 IDC-GCP 5VM 條件下的節點角色與放置策略 |
| Scope | PD、TiDB、TiKV、monitoring |
| Deliverable | 拓樸 YAML、inventory、site mapping |
| 完成標準 | 可明確知道每一節點的 role、site、IP、用途 |

推薦節點配置：

| VM | Site | 角色 | 備註 |
| --- | --- | --- | --- |
| `vm01` | IDC | `PD + TiDB + TiKV` | 控制面 + SQL 入口 + 儲存 |
| `vm02` | IDC | `PD + TiKV` | 控制面 + 儲存 |
| `vm03` | IDC | `PD + TiKV` | 控制面 + 儲存 |
| `vm04` | GCP | `TiDB + TiKV` | 遠端 SQL 入口 + 儲存 |
| `vm05` | GCP | `TiDB + TiKV + Test Client` | 遠端 SQL 入口 + 儲存 + 壓測節點 |

架構圖標註重點：

- PD quorum in IDC
- SQL entry in IDC and GCP
- Cross-site TiKV Raft replication
- Client -> TiDB: `TCP/4000`
- TiDB -> PD: `TCP/2379`
- PD peer: `TCP/2380`
- TiDB -> TiKV: `TCP/20160`
- TiKV -> PD: `TCP/2379`
- TiKV <-> TiKV: `TCP/20160`

實作項目：

- 產出 `topology.yaml`
- 定義 PD 固定落在 IDC
- 定義 TiKV 橫跨 IDC 與 GCP
- 定義 vm05 同時作為 test client

### TC-DEP-02 TiDB 自動化部署

| 欄位 | 內容 |
| --- | --- |
| Objective | 以 Ansible 自動化完成 TiDB 前置與部署 |
| Scope | binary 安裝、目錄、systemd、啟停、基本驗證 |
| Deliverable | `roles/tidb`、`playbooks/deploy-tidb.yml` |
| 完成標準 | 可自動部署、啟動、檢查集群健康狀態 |

實作項目：

- 安裝 TiUP 或等效部署流程
- 建立資料目錄與 log 目錄
- 建立 health check 步驟
- 收集 deployment artifact 與版本資訊
- 輸出 logical / physical architecture 所需節點與 port 資訊

### TC-DEP-03 TiDB 測試前置條件

| 欄位 | 內容 |
| --- | --- |
| Objective | 完成 TiDB test case 所需前置設定 |
| Scope | schema、seed data、metrics、慢查詢、dashboard 存取 |
| Deliverable | 初始化 SQL、測試帳號、metrics baseline |
| 完成標準 | 可直接開始執行 `docs/test-design.md` 中 TiDB test cases |

實作項目：

- 建立 `account` 表與 seed data
- 開啟必要 metrics 收集
- 建立測試用 DB user
- 驗證 follower read / stale read 所需設定

### TC-DEP-04 TiDB 架構圖輸入資訊

| 欄位 | 內容 |
| --- | --- |
| Objective | 產出可直接用於繪製 TiDB logical / physical architecture 的資訊 |
| Scope | node、role、site、flow、port / protocol |
| Deliverable | 架構圖文字版、節點表、連線表 |
| 完成標準 | 可直接轉成 draw.io / Mermaid 架構圖 |

實作項目：

- 整理 physical deployment node table
- 整理 logical architecture layer
- 整理 client / control plane / storage replication flow
- 整理 port / protocol 對照表

參考草稿：[`docs/architecture/tidb.md`](./architecture/tidb.md)

## 8. YugabyteDB 實作項目

### YC-DEP-01 YugabyteDB 拓樸與節點規劃

| 欄位 | 內容 |
| --- | --- |
| Objective | 定義 YugabyteDB PoC 在 IDC-GCP 5VM 條件下的 master / tserver / placement 規劃 |
| Scope | master、tserver、client、placement policy |
| Deliverable | node mapping、placement 規劃、inventory |
| 完成標準 | 可清楚定義各節點 site 與 RF / placement 條件 |

推薦節點配置：

| VM | Site | 角色 | 備註 |
| --- | --- | --- | --- |
| `vm01` | IDC | `yb-master + yb-tserver` | 控制面 + 資料節點 |
| `vm02` | IDC | `yb-master + yb-tserver` | 控制面 + 資料節點 |
| `vm03` | IDC | `yb-master + yb-tserver` | 控制面 + 資料節點 |
| `vm04` | GCP | `yb-tserver` | 遠端資料節點 |
| `vm05` | GCP | `yb-tserver + Test Client` | 遠端資料節點 + 壓測節點 |

架構圖標註重點：

- Master quorum in IDC
- TServer across IDC and GCP
- Raft replication across sites
- Client -> YSQL: `TCP/5433`
- yb-master UI / HTTP: `TCP/7000`
- yb-master RPC: `TCP/7100`
- yb-tserver UI / HTTP: `TCP/9000`
- yb-tserver RPC: `TCP/9100`
- yb-master <-> yb-master: `TCP/7100`
- yb-master <-> yb-tserver: `TCP/7100,9100`
- yb-tserver <-> yb-tserver: `TCP/9100`

實作項目：

- 明確定義 master 固定落在 IDC
- 明確定義 tserver 橫跨 IDC 與 GCP
- 規劃 RF=3 與 region-aware placement
- 定義 vm05 同時作為 test client

### YC-DEP-02 YugabyteDB 自動化部署

| 欄位 | 內容 |
| --- | --- |
| Objective | 以 Ansible 自動化完成 YugabyteDB 前置與部署 |
| Scope | binary 安裝、systemd、master/tserver 啟動、cluster join |
| Deliverable | `roles/yugabytedb`、`playbooks/deploy-yugabytedb.yml` |
| 完成標準 | 可自動部署、加入叢集並完成健康檢查 |

實作項目：

- 安裝 YugabyteDB binary
- 設定 master / tserver 啟動參數
- 建立 cluster init 與 join 流程
- 收集 cluster health 與版本資訊
- 輸出 logical / physical architecture 所需節點與 port 資訊

### YC-DEP-03 YugabyteDB 測試前置條件

| 欄位 | 內容 |
| --- | --- |
| Objective | 完成 YugabyteDB test case 所需前置設定 |
| Scope | schema、seed data、YSQL 連線、metrics、placement policy |
| Deliverable | 初始化 SQL、測試帳號、placement 設定 |
| 完成標準 | 可直接開始執行 `docs/test-design.md` 中 YugabyteDB test cases |

實作項目：

- 建立 `account` 表與 seed data
- 建立測試 user 與連線字串
- 配置 placement policy / tablespace
- 驗證 follower read 測試所需條件

### YC-DEP-04 YugabyteDB 架構圖輸入資訊

| 欄位 | 內容 |
| --- | --- |
| Objective | 產出可直接用於繪製 YugabyteDB logical / physical architecture 的資訊 |
| Scope | node、role、site、flow、port / protocol |
| Deliverable | 架構圖文字版、節點表、連線表 |
| 完成標準 | 可直接轉成 draw.io / Mermaid 架構圖 |

實作項目：

- 整理 physical deployment node table
- 整理 logical architecture layer
- 整理 client / control plane / storage replication flow
- 整理 port / protocol 對照表

參考草稿：[`docs/architecture/yugabytedb.md`](./architecture/yugabytedb.md)

## 9. Common Test Case 落地執行項目

### EX-01 壓測框架

| 欄位 | 內容 |
| --- | --- |
| Objective | 建立共同可重用的 workload runner |
| Scope | client 安裝、參數化、結果輸出 |
| Deliverable | `tests/common` 腳本與設定檔 |
| 完成標準 | 同一套 runner 可切換 TiDB / YugabyteDB 執行 |

實作項目：

- 決定 runner：`k6`、`sysbench` 或自製 script
- 參數化 DB host、port、user、password、site、concurrency、duration
- 統一輸出 JSON / CSV 結果

### EX-02 測試資料初始化

| 欄位 | 內容 |
| --- | --- |
| Objective | 建立可重複初始化的測試資料流程 |
| Scope | schema、seed data、reset |
| Deliverable | `tests/common/init.sql`、`reset.sql` |
| 完成標準 | 每次測試前可回到一致狀態 |

實作項目：

- 建立 schema SQL
- 建立 seed data loading 流程
- 建立清除與重建流程

### EX-03 故障注入腳本

| 欄位 | 內容 |
| --- | --- |
| Objective | 將 node failure / network partition 標準化 |
| Scope | process kill、service stop、iptables、tc |
| Deliverable | `tests/common/failure/` 腳本 |
| 完成標準 | 可安全重複執行並可回復 |

實作項目：

- 建立 node failure 腳本
- 建立 network delay 腳本
- 建立 network partition 腳本
- 建立 rollback / cleanup 腳本

### EX-04 Metrics 收集

| 欄位 | 內容 |
| --- | --- |
| Objective | 確保所有 test case 都能收集必收指標 |
| Scope | client metrics、DB metrics、system metrics、network metrics |
| Deliverable | metrics 清單、抓取方式、保存路徑 |
| 完成標準 | 每次測試結束後可取得完整 metrics 集合 |

實作項目：

- 建立 client log 格式
- 定義 DB metrics 抓取清單
- 定義 OS metrics 抓取方式
- 將測試結果歸檔至 `results/`

## 10. IaC 落地需求

### IAC-01 Terraform 變數抽象

- site pair：`idc-gcp`
- product：`tidb`、`yugabytedb`
- role：`pd`、`tidb`、`tikv`、`master`、`tserver`、`client`
- resource sizing：CPU、RAM、Disk、NIC
- network：subnet、gateway、dns、route

### IAC-02 Ansible Inventory 抽象

- 以 site 與 product 分 inventory
- group 需能支援：`all`、`site`、`product`、`role`
- 將共用變數放在 `group_vars`

### IAC-03 可重建要求

- 任何節點替換不應影響 inventory 結構
- hostname / role 命名固定化
- 測試腳本不得寫死 IP
- DB 連線資訊改由變數注入

## 11. 執行順序

1. 建立 Terraform 模板
2. 建立 Ansible baseline
3. 完成網路 precheck
4. 完成 TiDB / YugabyteDB 自動化部署
5. 產出 logical / physical architecture 所需資訊
6. 完成 schema 與 seed data 初始化
7. 完成 workload runner 與 metrics 收集
8. 完成 failure injection 腳本
9. 依 `docs/test-design.md` 執行 test cases
10. 整理結果與輸出報告

## 12. 開工前仍需補齊資訊

以下資訊若補齊，可直接進入實作：

- vSphere 環境資訊：Datacenter、Cluster、Datastore、Template 名稱
- GCP 專案資訊：Project ID、VPC、Subnet、Service Account
- GCP 與 vSphere 各自可用的 VM quota / resource pool
- 各 site 允許開放的 port 清單
- 是否已有監控系統可直接接入
- 測試 client 預計使用語言或工具
- 是否需要將結果匯入既有報表平台

## 13. 建議下一步

1. 先建立 `infra/terraform` 與 `infra/ansible` 目錄骨架
2. 先固定 `IDC-GCP` 的 IP、hostname 與 site mapping
3. 先定 TiDB / YugabyteDB 的 5VM 節點配置與 Route 選擇
4. 再開始產出 Terraform / Ansible 初版

---

## 14. Multi-Site Scenario 設定項目

本章對應 `docs/test-design.md` Section 12 的四個情境，記錄各情境所需的實際設定步驟。

### 14.1 情境與 Route 對照

| 情境 | 專線 | 流量 | 需用 Route |
|------|------|------|-----------|
| S1 | 正常 | 50/50 | A 或 B |
| S2 | 正常 | 全切 GCP | A 或 B |
| S3 | 中斷 | IDC 繼續 | **Route A** |
| S4 | 中斷 | GCP 繼續 | **Route B** |

S3 與 S4 需分兩次部署分別驗證。同一套 5 VM 無法同時滿足兩者。

---

### 14.2 TiDB Route A 設定（S1 / S2 / S3）

#### SC-TIDB-A-01 節點角色分配

| VM | Site | PD | TiDB | TiKV |
|----|------|----|------|------|
| vm01 | IDC | ✅ | ✅ | ✅ |
| vm02 | IDC | ✅ | — | ✅ |
| vm03 | IDC | ✅ | — | ✅ |
| vm04 | GCP | — | ✅ | ✅ |
| vm05 | GCP | — | ✅ | ✅ |

#### SC-TIDB-A-02 TiKV Node Label 設定

在各 VM 的 `tikv.toml` 加入：

```toml
# vm01 / vm02 / vm03 (IDC)
[server]
labels = { region = "idc" }

# vm04 / vm05 (GCP)
[server]
labels = { region = "gcp" }
```

PD 設定啟用 location-aware 排程：

```toml
# pd.toml
[replication]
location-labels = ["region"]
```

#### SC-TIDB-A-03 PD Placement Rule（2 IDC + 1 GCP per Region）

```bash
# 建立 route-a-rules.json
cat > route-a-rules.json << 'EOF'
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
EOF

pd-ctl config placement-rules rule-bundle set pd --in=route-a-rules.json
```

#### SC-TIDB-A-04 Ansible 實作項目

- `group_vars/idc.yml`：`tikv_labels: { region: idc }`
- `group_vars/gcp.yml`：`tikv_labels: { region: gcp }`
- `roles/tidb/tasks/pd_placement_rules.yml`：部署後自動套用 placement rule
- 驗收：`pd-ctl store` 確認 label 已套用，`pd-ctl region` 確認 replica 分布

---

### 14.3 TiDB Route B 設定（S1 / S2 / S4）

#### SC-TIDB-B-01 節點角色分配

| VM | Site | PD | TiDB | TiKV |
|----|------|----|------|------|
| vm01 | IDC | ✅ | ✅ | ✅ |
| vm02 | IDC | — | — | ✅ |
| vm03 | IDC | — | — | ✅ |
| vm04 | GCP | ✅ | ✅ | ✅ |
| vm05 | GCP | ✅ | ✅ | ✅ |

#### SC-TIDB-B-02 TiKV Node Label 設定

同 Route A（region label 相同），僅 PD 部署位置不同。

#### SC-TIDB-B-03 PD Placement Rule（1 IDC + 2 GCP per Region）

```bash
cat > route-b-rules.json << 'EOF'
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
EOF

pd-ctl config placement-rules rule-bundle set pd --in=route-b-rules.json
```

#### SC-TIDB-B-04 Route A → Route B 切換程序（不停機）

```bash
# 1. 在 vm04 啟動新 PD，加入現有 cluster
pd-ctl member add <vm04-ip>:2380

# 2. 在 vm05 啟動新 PD，加入現有 cluster
pd-ctl member add <vm05-ip>:2380

# 3. 確認 5 個 PD 皆 healthy
pd-ctl member

# 4. 移除 vm02 PD
pd-ctl member delete name pd-vm02

# 5. 移除 vm03 PD
pd-ctl member delete name pd-vm03

# 6. 確認剩 3 個 PD（vm01/vm04/vm05），quorum 正常
pd-ctl member

# 7. 更新 placement rule 為 Route B
pd-ctl config placement-rules rule-bundle set pd --in=route-b-rules.json
```

---

### 14.4 YugabyteDB Route A 設定（S1 / S2 / S3）

#### SC-YB-A-01 節點角色分配

| VM | Site | yb-master | yb-tserver |
|----|------|-----------|-----------|
| vm01 | IDC | ✅ | ✅ |
| vm02 | IDC | ✅ | ✅ |
| vm03 | IDC | ✅ | ✅ |
| vm04 | GCP | — | ✅ |
| vm05 | GCP | — | ✅ |

#### SC-YB-A-02 Placement 啟動參數

```bash
# IDC nodes (vm01 / vm02 / vm03) — yb-master 與 yb-tserver
--placement_cloud=on-prem
--placement_region=idc
--placement_zone=idc-a

# GCP nodes (vm04 / vm05) — yb-tserver only
--placement_cloud=gcp
--placement_region=gcp-region
--placement_zone=gcp-a
```

#### SC-YB-A-03 Tablespace（2 IDC + 1 GCP per tablet）

```sql
CREATE TABLESPACE idc_primary WITH (
  replica_placement = '{
    "num_replicas": 3,
    "placement_blocks": [
      {"cloud": "on-prem", "region": "idc",        "zone": "idc-a", "min_num_replicas": 2},
      {"cloud": "gcp",     "region": "gcp-region", "zone": "gcp-a", "min_num_replicas": 1}
    ]
  }'
);

ALTER TABLE account SET TABLESPACE idc_primary;
```

#### SC-YB-A-04 Ansible 實作項目

- `group_vars/idc.yml`：`yb_placement_cloud: on-prem`, `yb_placement_region: idc`, `yb_placement_zone: idc-a`
- `group_vars/gcp.yml`：`yb_placement_cloud: gcp`, `yb_placement_region: gcp-region`, `yb_placement_zone: gcp-a`
- `roles/yugabytedb/tasks/tablespace.yml`：部署後自動建立 tablespace 並 ALTER TABLE
- 驗收：`yb-admin list_all_masters` 確認 3 masters 皆在 IDC

---

### 14.5 YugabyteDB Route B 設定（S1 / S2 / S4）

#### SC-YB-B-01 節點角色分配

| VM | Site | yb-master | yb-tserver |
|----|------|-----------|-----------|
| vm01 | IDC | ✅ | ✅ |
| vm02 | IDC | — | ✅ |
| vm03 | IDC | — | ✅ |
| vm04 | GCP | ✅ | ✅ |
| vm05 | GCP | ✅ | ✅ |

#### SC-YB-B-02 Placement 啟動參數

```bash
# vm01 (IDC) — yb-master + yb-tserver
--placement_cloud=on-prem --placement_region=idc --placement_zone=idc-a

# vm02 / vm03 (IDC) — yb-tserver only（不啟動 yb-master）
--placement_cloud=on-prem --placement_region=idc --placement_zone=idc-a

# vm04 / vm05 (GCP) — yb-master + yb-tserver
--placement_cloud=gcp --placement_region=gcp-region --placement_zone=gcp-a
```

#### SC-YB-B-03 Tablespace（1 IDC + 2 GCP per tablet）

```sql
CREATE TABLESPACE gcp_primary WITH (
  replica_placement = '{
    "num_replicas": 3,
    "placement_blocks": [
      {"cloud": "on-prem", "region": "idc",        "zone": "idc-a", "min_num_replicas": 1},
      {"cloud": "gcp",     "region": "gcp-region", "zone": "gcp-a", "min_num_replicas": 2}
    ]
  }'
);

ALTER TABLE account SET TABLESPACE gcp_primary;
```

#### SC-YB-B-04 Route A → Route B 切換程序（不停機）

```bash
# 1. 在 vm04 以 master 模式啟動，加入現有 cluster
yb-admin -master_addresses <vm01,vm02,vm03>:7100 \
  change_master_config ADD_SERVER <vm04-ip> 7100

# 2. 在 vm05 以 master 模式啟動，加入現有 cluster
yb-admin -master_addresses <vm01,vm02,vm03,vm04>:7100 \
  change_master_config ADD_SERVER <vm05-ip> 7100

# 3. 確認 5 個 master 皆 healthy
yb-admin -master_addresses <all-5> list_all_masters

# 4. 移除 vm02 master
yb-admin -master_addresses <all-5> change_master_config REMOVE_SERVER <vm02-ip> 7100

# 5. 移除 vm03 master
yb-admin -master_addresses <vm01,vm04,vm05> change_master_config REMOVE_SERVER <vm03-ip> 7100

# 6. 確認剩 3 個 master（vm01/vm04/vm05），quorum 正常
yb-admin -master_addresses <vm01,vm04,vm05> list_all_masters

# 7. 更新 tablespace 為 gcp_primary
ALTER TABLE account SET TABLESPACE gcp_primary;
```

---

### 14.6 網路中斷模擬（TC-MS-03 / TC-MS-04 用）

在測試節點上以 `iptables` 模擬 IDC↔GCP 專線中斷：

```bash
# 在 IDC 節點封鎖所有 GCP 來源（以 GCP subnet 為例）
iptables -I INPUT  -s 10.160.0.0/16 -j DROP
iptables -I OUTPUT -d 10.160.0.0/16 -j DROP

# 恢復
iptables -D INPUT  -s 10.160.0.0/16 -j DROP
iptables -D OUTPUT -d 10.160.0.0/16 -j DROP
```

注意事項：
- 封鎖須同時在 IDC 側與 GCP 側執行，確保完全隔離
- 封鎖前先確認 client workload 已在兩站持續執行
- 保留封鎖前後的 metrics snapshot 作為 baseline 對照
- 恢復後等待 30 秒再進行資料一致性驗證

---

### 14.7 Scenario 執行順序建議

```
1. 部署 Route A → 執行 TC-MS-01（S1）→ TC-MS-02（S2）→ TC-MS-03（S3）
2. 執行 Route A → Route B 切換程序（SC-TIDB-B-04 / SC-YB-B-04）
3. 執行 TC-MS-01（S1）→ TC-MS-02（S2）→ TC-MS-04（S4）
4. 比較兩種 Route 下 S1 / S2 的 latency 差異（control plane 位置影響）
```
