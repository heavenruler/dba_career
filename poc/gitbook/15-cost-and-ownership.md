# 15. 成本與責任歸屬

> 最後驗證：2026-07-11｜5 年 TCO 僅提供建模框架；所有金額、折扣、用量與匯率均 TBD，不得以 PoC 推估報價。

## 五年 TCO 三情境

| 成本類別 | 情境 A：單區試行 | 情境 B：雙區 A/S | 情境 C：雙區 A/A-RO 或 A/A |
|---|---|---|---|
| 基礎設施 | compute、storage、network、monitoring | A + 異地 quorum/standby/網路 | B + 跨區讀寫、額外容量與流量 |
| 軟體/支援 | 授權或訂閱、支援等級、升級支援 | 同左，依節點/容量/支援範圍 TBD | 同左，依跨區架構 TBD |
| 人力 | DBA、平台、應用調整、教育訓練 | A + DR 演練與 on-call | B + 衝突治理、資料一致性與效能調校 |
| 一次性 | discovery、相容性、遷移、rehearsal | A + failover/restore rehearsal | B + A/A 契約、壓測與演練 |
| 風險準備 | 容量緩衝、事件處理、退出成本 | A + 備份與 DR 缺口 | B + WAN/衝突/一致性風險 |

`5 年 TCO = 一次性成本 + Σ(年度平台 + 年度軟體/支援 + 年度人力 + 年度網路/儲存 + 風險準備)`

| 必填輸入 | Owner | 狀態 |
|---|---|---|
| 服務流量、資料量、成長率、保留期 | 應用/資料 owner | TBD |
| CPU、RAM、儲存 IOPS、備份量、跨區 egress | 平台、DBA | TBD |
| 授權/訂閱、支援、專業服務與合約條款 | 採購、法務 | TBD |
| 人力成本、on-call、訓練、遷移 wave 數 | 維運主管、應用 owner | TBD |
| RTO/RPO、風險容忍度與退出要求 | 業務 owner、風險管理 | TBD |

## RACI

| 工作 | DBA | 平台/SRE | 應用 owner | 資安 | 採購/法務 | 業務 owner |
|---|---|---|---|---|---|---|
| 架構與容量基線 | A/R | R | C | C | I | I |
| 應用契約與相容性 | C | C | A/R | C | I | C |
| 安全硬閘與資料分類 | C | R | C | A/R | C | I |
| 備份、restore、DR 演練 | A/R | R | C | C | I | I |
| 遷移/cutover/rollback | A/R | R | R | C | I | A |
| TCO 與合約 | C | C | C | C | A/R | A |
| 上線 Go/No-go | R | R | R | R | C | A |

`A=Accountable, R=Responsible, C=Consulted, I=Informed`；實名角色、替補與 escalation chain 待組織確認。[待驗證]

## 證據與限制

- [決策] 既有計畫將 5 年 TCO 列為後續調查，非已完成工作；本文件不引入任何價格。[2026-06-16 會議](../1_MeetingMinutes/0616.md)
- [待驗證] 初期試行流量曾被列為約 5-10% 的討論方向，非核定容量或預算。[TiDB x 104 摘節](../1_MeetingMinutes/0611-TiDBx104-summary.md)
- [待驗證] 三個情境的需求、合約、資產折舊與雲端/IDC 成本尚未盤點。

## 決策與待決

| 決策 | 狀態 | Owner |
|---|---|---|
| 選擇要比較的情境與共同容量假設 | 待核定 | 業務 owner、DBA |
| 完成供應商與自建成本輸入 | 待補 | 採購、平台 |
| 核定 RACI 人名、值班與升級責任 | 待核定 | 維運主管 |
