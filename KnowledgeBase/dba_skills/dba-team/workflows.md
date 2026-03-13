# dba-team Workflows

## 1. Workflow Principles

`dba-team` 的 workflow 用來確保每次回應都經過一致的 intake、路由、知識查詢、記憶處理與答案整合，避免不同專家之間回答品質落差過大。

所有 workflow 都共享以下內部階段：

1. `request intake`
2. `requirement clarification`
3. `expert routing`
4. `knowledge reference lookup`
5. `multi-expert review`
6. `answer synthesis`
7. `memory read/write`
8. `final output formatting`

## 2. Shared Internal Stages

### 2.1 request intake

- 由 `dba-assistant` 接收需求。
- 解析主題、資料庫類型、環境、交付形式、風險等級。
- 先判斷屬於問答、設計、故障、遷移、文件哪一類。

### 2.2 requirement clarification

- 若關鍵資訊不足，列出假設與缺口。
- 優先萃取最小必要資訊，如版本、拓撲、目標、限制。
- 若可在保守假設下繼續，先產出初版方案，再註明待確認項。

### 2.3 expert routing

- 單一產品、單一主題：分派單一專家。
- 多產品或高風險：加上 `dba-director`。
- 需要輸出整理與追蹤：由 `dba-assistant` 負責收斂。

### 2.4 knowledge reference lookup

- 先檢查 `references/` 是否已有 SOP、案例、設計筆記。
- 若有，優先沿用既有標準。
- 若沒有，產出答案時標記「建議補充 reference」。

### 2.5 multi-expert review

- 涉及跨產品、相容性、風險時啟動。
- 比對假設、限制、風險、替代方案。
- 若意見衝突，由 `dba-director` 統一決策或並列 trade-off。

### 2.6 answer synthesis

- 由 `dba-assistant` 或 `dba-director` 整合輸出。
- 統一輸出順序：結論 → 假設 → 步驟 → 驗證 → 風險 → 後續建議。

### 2.7 memory read/write

- 回答前讀與主題相關的 `memory/`。
- 回答後若有新決策、已確認環境或使用者偏好，寫回 memory。

### 2.8 final output formatting

- 優先輸出可執行內容：shell、SQL、YAML、JSON、SOP checklist。
- 如需文件型交付，使用章節化格式。

## 3. Workflow 1: 一般 DBA 問答流程

### 3.1 觸發條件

- 單一問題詢問
- 需求偏技術解釋、操作指令、最佳實務
- 不涉及大規模架構變更

### 3.2 參與角色

- 必要角色：`dba-assistant`
- 視產品加掛：`oracle-expert` / `mysql-expert` / `postgresql-expert` / `tidb-expert` / `tdsql-expert` / `mongodb-expert` / `redis-expert` / `clickhouse-expert`
- 高風險時：`dba-director`

### 3.3 執行步驟

1. `dba-assistant` 解析問題與產品類型。
2. 讀取 `memory/env.json` 與 `memory/preferences.json` 的必要欄位。
3. 查詢 `references/` 是否已有相同 SOP 或 FAQ。
4. 路由到對應專家產出技術答案。
5. 若答案涉及風險或重大前提，補上假設與驗證步驟。
6. 若產生新偏好或確認新環境資訊，更新 memory。

### 3.4 輸出格式

- 結論
- 適用前提 / 假設
- 可執行命令 / SQL / 設定
- 驗證方式
- 風險提醒

### 3.5 是否需要寫入 memory

- 預設：選擇性寫入
- 寫入條件：確認新環境資訊、產生常用偏好、形成可重用結論

## 4. Workflow 2: 架構設計流程

### 4.1 觸發條件

- 選型、容量規劃、HA / DR、拓撲設計
- 跨產品比較與 trade-off 分析
- 需要決策文件或設計文件

### 4.2 參與角色

- 必要角色：`dba-assistant`, `dba-director`
- 視方案加掛 1~N 位產品專家

### 4.3 執行步驟

1. `dba-assistant` 收集需求：工作負載、SLA、資料量、成長率、預算、平台限制。
2. 讀取 `memory/env.json` 與 `history.json.decisions`。
3. 查 `references/` 的既有架構筆記、SOP、PoC 結果。
4. 由對應專家提出候選方案與限制。
5. `dba-director` 評估可行性、風險、成本、維運複雜度、時程。
6. 整合主方案、替代方案、適用條件與不採用理由。
7. 將最終決策摘要寫入 `history.json.decisions`。

### 4.4 輸出格式

- Executive conclusion
- Requirements and assumptions
- Architecture options
- Recommended design
- HA / DR / backup strategy
- Risks and trade-offs
- Implementation phases

### 4.5 是否需要寫入 memory

- 必須寫入
- 至少更新 `history.json.decisions`
- 如有新平台資訊，同步更新 `env.json`

## 5. Workflow 3: 故障排查流程

### 5.1 觸發條件

- 線上故障
- 效能突增、延遲、鎖等待、複寫中斷、容量異常
- 需要 RCA 或臨時止血建議

### 5.2 參與角色

- 必要角色：`dba-assistant`
- 產品專家至少一位
- 若涉及多系統影響、資料風險、重大停機：`dba-director`

### 5.3 執行步驟

1. `dba-assistant` 先判定事件等級與影響面。
2. 讀取 `history.json.incidents` 查是否有相似案例。
3. 讀取 `env.json` 確認拓撲、版本、監控與限制。
4. 對應專家提供 triage 順序：觀測指標、log、系統指令、SQL 檢查。
5. 先給止血方案，再給根因分析方向。
6. 若為重大事件，由 `dba-director` 決定升級策略、變更風險與 rollback 原則。
7. 結案後將 incident 與修正建議寫入 history。

### 5.4 輸出格式

- 事件判斷
- 立即處置步驟
- 檢查命令 / SQL
- 可能根因
- 風險與 rollback 提醒
- RCA 與後續改善項

### 5.5 是否需要寫入 memory

- 建議寫入
- 重大事件必寫 `history.json.incidents`

## 6. Workflow 4: migration / upgrade / PoC 流程

### 6.1 觸發條件

- 資料庫升級、跨產品遷移、PoC 評估、相容性驗證

### 6.2 參與角色

- 必要角色：`dba-assistant`, `dba-director`
- 來源與目標資料庫專家各至少一位

### 6.3 執行步驟

1. `dba-assistant` 收集來源 / 目標版本、資料量、停機窗口、回退條件。
2. 讀取 `history.json.migrations` 與 `decisions`。
3. 查 `references/` 是否已有 benchmark、PoC、相容性筆記。
4. 來源專家提供現況盤點與風險項。
5. 目標專家提供落地架構、相容性差異與調整項。
6. `dba-director` 統整分階段遷移策略、驗證指標、rollback 設計。
7. 將結果寫入 `history.json.migrations` 與必要決策欄位。

### 6.4 輸出格式

- Migration / upgrade conclusion
- Scope and assumptions
- Compatibility assessment
- Execution plan
- Validation checklist
- Rollback plan
- Risks and open items

### 6.5 是否需要寫入 memory

- 必須寫入
- 更新 `history.json.migrations`
- 必要時更新 `history.json.decisions` 與 `env.json`

## 7. Workflow 5: 文件產出流程

### 7.1 觸發條件

- 需求為 SOP、設計文件、維運手冊、交接文件、review note

### 7.2 參與角色

- 必要角色：`dba-assistant`
- 視主題加入對應產品專家
- 若文件屬決策或評審文件，加入 `dba-director`

### 7.3 執行步驟

1. `dba-assistant` 確認文件類型、讀者對象、深度與格式。
2. 讀取 `preferences.json` 的輸出偏好。
3. 查 `references/` 中可重用模板與既有 SOP。
4. 由專家補齊內容：步驟、風險、驗證、回退、限制。
5. 若文件牽涉正式決策，交由 `dba-director` 做 final review。
6. 產出標準格式文件，必要時將模板回寫到 `references/`。

### 7.4 輸出格式

- 文件目的
- 適用範圍
- 前置條件
- 執行步驟
- 驗證與回退
- 風險與附註

### 7.5 是否需要寫入 memory

- 視情況寫入
- 若產生長期可重用模板，建議更新 `references/`，history 保留索引即可

## 8. Workflow Selection Guide

| scenario | primary workflow | memory priority | typical lead role |
| --- | --- | --- | --- |
| 單點問題、命令查詢 | 一般 DBA 問答流程 | `env`, `preferences` | `dba-assistant` |
| 新系統、選型、HA 規劃 | 架構設計流程 | `env`, `history.decisions` | `dba-director` |
| 服務異常、複寫中斷、效能事件 | 故障排查流程 | `env`, `history.incidents` | 對應產品專家 |
| 升級、遷移、PoC | migration / upgrade / PoC 流程 | `history.migrations`, `decisions` | `dba-director` |
| SOP、文件、報告 | 文件產出流程 | `preferences`, `references` | `dba-assistant` |

## 9. Role Routing Matrix

此矩陣用來補充 16 角色在不同需求類型下的預設路由規則，讓 `dba-assistant` 可快速判斷主責角色、協作角色與升級條件。

| request pattern | primary role | supporting roles | escalate to director when |
| --- | --- | --- | --- |
| 一般需求 intake、需求不清、需整理輸出 | `dba-assistant` | 視情況加入任一專家 | 需要正式決策、跨產品或重大風險 |
| 跨產品選型、總體架構、roadmap | `dba-director` | `performance-engineer`, `ha-dr-expert`, 相關產品專家 | 預設即由 director 主導 |
| Oracle 架構、RAC、Data Guard、AWR | `oracle-expert` | `ha-dr-expert`, `migration-architect` | 涉及授權、跨平台選型、重大升級 |
| MySQL、InnoDB、replication、MGR | `mysql-expert` | `performance-engineer`, `ha-dr-expert`, `migration-architect` | 涉及平台替換、跨區治理 |
| PostgreSQL、vacuum、replication、PITR | `postgresql-expert` | `performance-engineer`, `ha-dr-expert`, `migration-architect` | 涉及重大架構或平台替換 |
| TiDB、HTAP、placement、MySQL 相容 | `tidb-expert` | `mysql-expert`, `performance-engineer`, `migration-architect` | 需做 PoC 決策、導入成本高 |
| TDSQL、產品能力、相容性 | `tdsql-expert` | `mysql-expert`, `migration-architect` | 官方限制待查、需平台級決策 |
| MongoDB replica set、sharding、aggregation | `mongodb-expert` | `performance-engineer`, `ha-dr-expert` | 要作主資料庫或跨區治理 |
| Redis cache、Sentinel、Cluster、persistence | `redis-expert` | `performance-engineer`, `ha-dr-expert` | 涉及關鍵資料保存或平台政策 |
| ClickHouse schema、ingest、MergeTree、OLAP | `clickhouse-expert` | `performance-engineer`, `platform-automation-expert` | 涉及資料平台選型或湖倉整合 |
| SQL Server、AG、backup、T-SQL tuning | `sql-server-expert` | `ha-dr-expert`, `performance-engineer` | 涉及授權成本、跨平台遷移 |
| MariaDB、Galera、MySQL 分支差異 | `mariadb-expert` | `mysql-expert`, `migration-architect` | 涉及分支策略、平台治理 |
| 跨 DB 效能瓶頸、benchmark、容量規劃 | `performance-engineer` | 對應產品專家 | 需以成本 / 架構重設解決 |
| HA、DR、backup、restore drill、RPO/RTO | `ha-dr-expert` | 對應產品專家, `migration-architect` | 成本與 SLA 衝突、跨區重大設計 |
| migration、upgrade、cutover、rollback | `migration-architect` | 來源 / 目標產品專家, `ha-dr-expert` | 時程、停機窗口、風險難以平衡 |
| Ansible、Terraform、Kubernetes、平台自動化 | `platform-automation-expert` | 對應產品專家, `ha-dr-expert` | 涉及平台標準與組織治理 |

## 10. Collaboration Playbooks

### 10.1 常見雙專家組合

| primary role | supporting role | common scenario |
| --- | --- | --- |
| `mysql-expert` | `tidb-expert` | MySQL to TiDB migration / compatibility review |
| `postgresql-expert` | `ha-dr-expert` | PITR、跨區備援、failover drill |
| `oracle-expert` | `migration-architect` | Oracle upgrade / heterogeneous migration |
| `clickhouse-expert` | `performance-engineer` | ingest / query benchmark 與 schema tuning |
| `redis-expert` | `performance-engineer` | hot key、big key、latency 事件 |
| `sql-server-expert` | `ha-dr-expert` | AG、backup、DR runbook |
| `mariadb-expert` | `mysql-expert` | MariaDB / MySQL 分支差異與遷移 |
| `platform-automation-expert` | `ha-dr-expert` | backup / restore automation 與平台標準化 |

### 10.2 三方以上協作觸發條件

- 同時涉及來源 DB、目標 DB、切換策略
- 同時涉及產品能力、效能驗證與 HA / DR 保證
- 需要架構方案、落地自動化與正式文件同時交付
- 需要 benchmark / PoC 結論作為正式決策依據

## 11. Maintenance Notes

1. 若新增專家角色，只需補充 routing 條件，不必重寫所有 workflow。
2. 若導入新資料庫產品，先補 `prompts/` 與 `references/`，再更新對應 workflow 的專家清單。
3. 若 workflow 已穩定，可將常用模板下沉到 `references/`，供專家直接引用。
