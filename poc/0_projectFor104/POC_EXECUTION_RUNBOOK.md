# 分散式資料庫架構 PoC 實作項目 Runbook

## 1. 文件目的

本文件將 `POC_TEST_DESIGN.md` 轉換為可落地執行的實作項目，供 PoC 建置、測試、驗證與環境重建使用。

適用前提：

- 部署型態：VMware (vSphere)
- 作業系統：AlmaLinux
- IaC 工具：Terraform + Ansible
- PoC 產品：TiDB、YugabyteDB
- 網路拓樸：
  - (Option1) IDC `172.24.*.*` <-> EDC `172.26.*.*`
  - (Option2) IDC `172.24.*.*` <-> GCP `10.160.*.*`

## 2. 輸出目標

本階段需產出以下可執行成果：

- Terraform：GCP / vSphere 基礎資源建立
- Ansible：主機基線、套件安裝、系統參數、產品部署、測試前置設定
- Test Case 執行清單：可逐項落地執行
- 驗證結果保存目錄與命名規則
- 環境可重建、可抽換、可重跑

## 3. 目錄建議

```text
0_projectFor104/
├── README.md
├── POC_TEST_DESIGN.md
├── POC_EXECUTION_RUNBOOK.md
├── infra/
│   ├── terraform/
│   │   ├── gcp/
│   │   └── vsphere/
│   └── ansible/
│       ├── inventories/
│       │   ├── idc-edc/
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
- 同一份 Runbook 要能套用在 `IDC-EDC` 與 `IDC-GCP` 兩種場景

## 5. 環境實作項目

### EC-01 Terraform 基礎資源模板

| 欄位 | 內容 |
| --- | --- |
| Objective | 建立可重建的 GCP / vSphere 基礎設施模板 |
| Scope | VM、CPU、Memory、Disk、NIC、Subnet、Security Rule、DNS / hostname |
| Deliverable | `infra/terraform/gcp`、`infra/terraform/vsphere` |
| 完成標準 | 能以變數切換 `IDC-EDC` 與 `IDC-GCP` 拓樸，並成功建立對應節點 |

實作項目：

- 建立 `terraform.tfvars` 範本
- 抽出共用變數：`region_pair`、`vm_count`、`vm_cpu`、`vm_memory_gb`、`vm_disk_gb`
- 建立命名規則：`poc-<product>-<site>-<role>-<seq>`
- 輸出 inventory 所需資訊：IP、hostname、role、site

### EC-02 Ansible 主機基線

| 欄位 | 內容 |
| --- | --- |
| Objective | 建立 Rocky / AlmaLinux 標準化主機基線 |
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

- 建立 site matrix：`IDC <-> EDC`、`IDC <-> GCP`
- 測試節點間 ICMP / TCP 連線
- 量測 baseline RTT 與封包穩定度
- 確認 DB / 管理 port 可雙向通訊

## 6. TiDB 實作項目

### TC-DEP-01 TiDB 拓樸與節點規劃

| 欄位 | 內容 |
| --- | --- |
| Objective | 定義 TiDB PoC 在兩種 site 組合下的節點角色與放置策略 |
| Scope | PD、TiDB、TiKV、monitoring |
| Deliverable | 拓樸 YAML、inventory、site mapping |
| 完成標準 | 可明確知道每一節點的 role、site、IP、用途 |

建議最小配置：

- PD x 3
- TiDB x 2~3
- TiKV x 3~6
- Monitoring x 1

實作項目：

- 產出 `topology.yaml`
- 定義 PD 與 TiKV 的跨站分布
- 預留獨立 client node 供壓測與故障注入使用

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

### TC-DEP-03 TiDB 測試前置條件

| 欄位 | 內容 |
| --- | --- |
| Objective | 完成 TiDB test case 所需前置設定 |
| Scope | schema、seed data、metrics、慢查詢、dashboard 存取 |
| Deliverable | 初始化 SQL、測試帳號、metrics baseline |
| 完成標準 | 可直接開始執行 `POC_TEST_DESIGN.md` 中 TiDB test cases |

實作項目：

- 建立 `account` 表與 seed data
- 開啟必要 metrics 收集
- 建立測試用 DB user
- 驗證 follower read / stale read 所需設定

## 7. YugabyteDB 實作項目

### YC-DEP-01 YugabyteDB 拓樸與節點規劃

| 欄位 | 內容 |
| --- | --- |
| Objective | 定義 YugabyteDB PoC 的 master / tserver / placement 規劃 |
| Scope | master、tserver、client、placement policy |
| Deliverable | node mapping、placement 規劃、inventory |
| 完成標準 | 可清楚定義各節點 site 與 RF / placement 條件 |

建議最小配置：

- master x 3
- tserver x 3~6
- client x 1~2

實作項目：

- 明確定義各 site 的 master / tserver 分布
- 規劃 RF=3 與 region-aware placement
- 預留測試用 client node

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

### YC-DEP-03 YugabyteDB 測試前置條件

| 欄位 | 內容 |
| --- | --- |
| Objective | 完成 YugabyteDB test case 所需前置設定 |
| Scope | schema、seed data、YSQL 連線、metrics、placement policy |
| Deliverable | 初始化 SQL、測試帳號、placement 設定 |
| 完成標準 | 可直接開始執行 `POC_TEST_DESIGN.md` 中 YugabyteDB test cases |

實作項目：

- 建立 `account` 表與 seed data
- 建立測試 user 與連線字串
- 配置 placement policy / tablespace
- 驗證 follower read 測試所需條件

## 8. Common Test Case 落地執行項目

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
- 將測試結果歸檔至 `results/` |

## 9. IaC 落地需求

### IAC-01 Terraform 變數抽象

- site pair：`idc-edc`、`idc-gcp`
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

## 10. 執行順序

1. 建立 Terraform 模板
2. 建立 Ansible baseline
3. 完成網路 precheck
4. 完成 TiDB / YugabyteDB 自動化部署
5. 完成 schema 與 seed data 初始化
6. 完成 workload runner 與 metrics 收集
7. 完成 failure injection 腳本
8. 依 `POC_TEST_DESIGN.md` 執行 test cases
9. 整理結果與輸出報告

## 11. 開工前仍需補齊資訊

以下資訊若補齊，可直接進入實作：

- vSphere 環境資訊：Datacenter、Cluster、Datastore、Template 名稱
- GCP 專案資訊：Project ID、VPC、Subnet、Service Account
- 各 site 可用主機數或 VM quota
- 各 site 允許開放的 port 清單
- 是否已有 Bastion / Jump Host
- 是否已有監控系統可直接接入
- 測試 client 預計使用語言或工具
- 是否需要將結果匯入既有報表平台

## 12. 建議下一步

1. 先建立 `infra/terraform` 與 `infra/ansible` 目錄骨架
2. 先決定第一階段 PoC 先跑 `IDC-EDC` 還是 `IDC-GCP`
3. 先定 TiDB / YugabyteDB 的最小節點數與 VM 規格
4. 再開始產出 Terraform / Ansible 初版
