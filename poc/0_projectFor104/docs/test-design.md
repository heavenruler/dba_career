# 分散式資料庫架構 PoC Test Cases

## 1. 測試目標與範圍

驗證 TiDB 與 YugabyteDB 在 2-site（IDC + GCP）Active-Active 架構下的實際行為，聚焦：

- 高併發同 row 衝突的 detection / resolution 行為
- Multi-site 寫入的 commit path 延遲差異
- Follower read / stale read 可用性
- 節點故障時的 leader election 與 RTO
- 網路中斷時的 quorum 行為與 split-brain 防護
- 計劃性流量切換與斷線後單站獨立運作

**不納入本階段：** 正式導入架構定案、生產級容量估算、完整成本試算、正式 SLA/SLO 承諾。

---

## 2. 測試環境

### 2.1 站點對應

| Region | Site | IP Range | VMs |
|--------|------|----------|-----|
| Region A | IDC | 172.24.*.* | vm01, vm02, vm03 |
| Region B | GCP | 10.160.*.* | vm04, vm05 |

### 2.2 拓樸（依 Route 決定控制面位置）

架構細節與 Route A / B / C 說明見：
- TiDB：[`docs/architecture/tidb.md`](./architecture/tidb.md)
- YugabyteDB：[`docs/architecture/yugabytedb.md`](./architecture/yugabytedb.md)

| 系統 | SQL 節點 | 控制面（PD / master） | 儲存節點（TiKV / tserver） |
|------|---------|----------------------|--------------------------|
| TiDB | 3（vm01, vm04, vm05） | 3，位置依 Route | 5（vm01~05） |
| YugabyteDB | 5 tserver（YSQL 內建） | 3，位置依 Route | 5（vm01~05） |

### 2.3 測試資料模型

```sql
CREATE TABLE account (
  id         BIGINT PRIMARY KEY,
  tenant_id  BIGINT NOT NULL,
  balance    BIGINT NOT NULL,
  version    BIGINT NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
CREATE INDEX idx_tenant_id ON account(tenant_id);
```

初始化：1,000,000 rows；預留 hot rows `id IN (1,2,3,4,5)`。

### 2.4 負載產生器

- 工具：`k6`、`sysbench` 或自製 workload runner（兩套系統統一）
- 每站至少 1 組 client，各自連本站 SQL 入口
- 每筆 request 須記錄：開始/結束時間、site、txn 類型、error code、retry 次數

---

## 3. Common Test Cases

### TC-01　Concurrent Update 同一 row

**Objective：** 驗證衝突 detection / resolution，比較 retry、abort、lock wait 行為。

**Setup：** 兩站 client 同時對 `account.id = 1` 執行 update，concurrency 逐步提高（32 / 64 / 128），持續 ≥10 min。

**Transaction pattern：**
```sql
BEGIN;
SELECT balance, version FROM account WHERE id = 1 FOR UPDATE;
UPDATE account SET balance = balance + 1, version = version + 1,
  updated_at = CURRENT_TIMESTAMP WHERE id = 1;
COMMIT;
```

**Metrics：** write conflict rate、serialization failure、deadlock / lock wait timeout、retry count、error code 分布、p95 latency

**Pass：** 高併發下可持續完成交易，衝突錯誤可辨識且 retry 後成功率可量測。
**Fail：** 大量不可解釋錯誤、長時間卡死、或無法區分衝突與系統異常。

---

### TC-02　Multi-Site Write Latency

**Objective：** 驗證 commit path 是否跨 site quorum，比較兩站寫入延遲差異。

**Setup：** IDC 與 GCP client 各自對相同資料集發送寫入，transaction pattern 一致。

**Metrics：** commit latency（per site）、p95 / p99 latency、Region / tablet leader 位置、cross-site network bytes

**Pass：** 可明確量出兩站延遲差異，且能對應 leader / quorum 路徑解釋。
**Fail：** 無法穩定重現延遲差異，或觀測資料不足以解釋 commit path。

---

### TC-03　Follower Read Delay

**Objective：** 驗證 follower read / stale read 實際可用性與 staleness。

**Setup：** 固定頻率更新同一筆資料；另一組 client 以三種模式交替查詢（leader read / follower read / stale read）。

**Metrics：** read latency（per mode）、stale lag、read-your-write 成立率

**Pass：** 可清楚量出三種讀取模式的延遲與一致性差異。
**Fail：** 讀取來源無法穩定判斷、staleness 無法量測。

---

### TC-04　Node Failure

**Objective：** 量測 leader election 時間與寫入恢復窗口（RTO）。

**Setup：** 壓測進行中，識別 hot region / tablet 的 leader 所在節點後直接 kill process 或關機。

**Metrics：** time to new leader、write unavailability window、client error 數量、failover 期間 retry count

**Pass：** 故障後可重新選主並恢復服務，RTO 與錯誤型態可量測。
**Fail：** 長時間無法恢復、寫入不可用時間不可控、或 failover 行為無法解釋。

---

### TC-05　Network Partition（單站內）

**Objective：** 驗證 quorum 行為，確認系統 fail-closed 以避免 split-brain。

**Setup：** 以 `iptables` 隔離 leader 與部分 follower，期間持續執行讀寫。

**Metrics：** 少數分區接受寫入情況、leader 重新選舉時間、reconnect 後資料一致性

**Pass：** 少數分區不接受不安全寫入，呈現 fail-closed 或可預期 quorum 行為。
**Fail：** 出現 split-brain、雙寫、或分區期間接受不安全寫入。

---

## 4. TiDB Product-Specific Test Cases

參考架構：[`docs/architecture/tidb.md`](./architecture/tidb.md)

### TiDB-01　TSO 與 Commit Latency 關聯

**Objective：** 分離 PD TSO 取得成本與 TiKV quorum 成本，判斷 TSO 是否為延遲瓶頸。

**Setup：** 分別執行單 key 與多 key transaction；在 Route A（PD 在 IDC）與 Route B（PD 在 GCP）各跑一次。

**Metrics：** TSO 取得延遲、2PC prewrite / commit latency、PD metrics、p95 commit latency（per route）

**Pass：** 可分離 TSO 成本，並判斷其對 commit latency 的影響比例。
**Fail：** 無法從 metrics 辨識 TSO 對 commit latency 的貢獻。

---

### TiDB-02　Follower Read 與 Stale Read 對照

**Objective：** 比較 follower read（強一致 `ReadIndex`）與 stale read 的實際延遲與一致性差異。

**Setup：** 持續更新同一批資料，以 leader read / follower read / stale read 三種模式查詢。

**Metrics：** `ReadIndex` 延遲、stale read latency、讀一致性結果

**Pass：** 能明確量出三種模式的延遲與一致性差異，`ReadIndex` 成本可辨識。
**Fail：** 行為無法穩定重現，或 `ReadIndex` 成本無法與 leader read 區分。

---

### TiDB-03　ADD INDEX 對線上寫入影響

**Objective：** 驗證 online DDL backfill 期間對熱表寫入的實際影響。

**Setup：** 對持續寫入中的 `account` 表執行 `ADD INDEX`。

**Metrics：** backfill 期間寫入 p95 latency、write conflict、DDL 完成時間

**Pass：** DDL 可在線完成，對寫入的影響可量測且在可接受範圍。
**Fail：** DDL 造成明顯 blocking、不可接受的寫入中斷、或無法完成。

---

## 5. YugabyteDB Product-Specific Test Cases

參考架構：[`docs/architecture/yugabytedb.md`](./architecture/yugabytedb.md)

### YB-01　HLC / Transaction Restart 行為

**Objective：** 驗證高衝突下 transaction restart 與 serialization failure 特徵，量測 retry 成本。

**Setup：** 對同一 row 執行高併發 update（同 TC-01 pattern）。

**Metrics：** restart error 分布、serialization failure 比例、retry 後成功率、abort rate

**Pass：** 可明確觀察 restart / serialization error 模式，retry 成本可量測。
**Fail：** 高衝突下錯誤型態不明、retry 行為不可預測。

---

### YB-02　Geo-Placement 與 Region Failover

**Objective：** 驗證 tablespace placement policy 是否直接影響可寫性與 failover 結果。

**Setup：** 套用 Route A 或 Route B 的 tablespace policy，模擬單 site 不可用。

**Metrics：** site 故障後可寫性、tablet leader 重分布時間、RTO、client error rate

**Pass：** placement policy 與 failover 結果有直接可量測的關聯。
**Fail：** 故障後行為無法預測，或 placement 設定無法支撐預期可寫性。

---

### YB-03　Follower Read 行為

**Objective：** 量化 follower read 的延遲收益與 stale lag 行為。

**Setup：** 固定頻率寫入，分別以 leader read 與 follower read 查詢。

**Metrics：** follower read 可用條件、stale lag、read latency（per mode）

**Pass：** 可量化 follower read 的延遲收益與 stale lag 邊界。
**Fail：** 無法穩定使用 follower read，或讀延遲 / 一致性特徵無法辨識。

---

## 6. 核心 Metrics

| 指標 | 驗收重要性 | 若缺少的風險 |
|------|-----------|------------|
| `p95 latency` | 反映大多數請求的實際延遲體驗 | 低估系統在壓力下對使用者的影響 |
| `p99 latency` | 揭露 leader 切換、GC、鎖衝突造成的尾延遲 | 忽略實際影響 SLA 的尖峰請求 |
| `commit latency` | 判斷 multi-site write 成本是否適合 OLTP | 無法確認跨站寫入是否可行 |
| `retry count` | 評估 client 整合成本與系統穩定性 | 誤判系統穩定，實際靠大量 retry 撐住 |
| `conflict rate` | 衡量 transaction model 對熱點場景的適應性 | 高衝突場景的可用性被高估 |
| `abort rate` | 區分「可 retry 解決」與「交易實際失敗」 | 應用層補償邏輯壓力被低估 |
| `stale lag` | 驗證 follower / stale read 的資料新鮮度 | 無法判斷此能力是否可安全上線 |
| `time to new leader` | 評估 HA 共識層恢復能力（RTO 核心） | 無法量化故障切換對業務的實際影響 |
| `write unavailability window` | 量化業務實際不可寫的時間長度 | 僅看 leader election 時間，低估中斷影響 |
| `cross-region network bytes` | 評估 multi-site 架構的網路成本可行性 | 功能可行但成本不可行的選型風險 |

---

## 7. 驗收建議

本階段不定義絕對門檻，但測試結束後需能回答：

- 哪套系統在高衝突寫入下 retry / abort 最可控？
- 哪套系統在 multi-site commit latency 最穩定？
- Follower read / stale read 是否具備可操作性與可預測性？
- Node failure 與 site partition 時，寫入不可用窗口是否可接受？
- 斷線後是否確認 fail-closed（無 split-brain）？
- Route A 與 Route B 的延遲差異（control plane 位置影響）是否可量化？

---

## 8. 後續待補

| 項目 | 狀態 |
|------|------|
| 部署拓樸定義 | ✅ 見 `docs/architecture/` |
| Route A / B 設定步驟 | ✅ 見 `docs/execution-runbook.md` Section 14 |
| Multi-site scenario TC | ✅ 見下方 Section 9 |
| 測試腳本實作 | ⏳ 待補 |
| Metrics 收集方式 | ⏳ 待補 |
| 驗收門檻數值 | ⏳ 待補 |
| 測試時程與執行順序 | ⏳ 待補 |

---

## 9. Multi-Site Scenario Test Cases

### 情境對照

| # | 專線 | 流量 | 適用 Route | 驗證重點 |
|---|------|------|-----------|---------|
| S1 | 正常 | IDC 50% / GCP 50% | A 或 B | 兩站同時寫入的延遲差異與穩定性 |
| S2 | 正常 | 全切至 GCP（計劃性） | A 或 B | 流量遷移期間無寫入中斷 |
| S3 | 中斷 | 流量維持在 IDC | **Route A** | IDC 獨立運作；GCP fail-closed |
| S4 | 中斷 | 流量維持在 GCP | **Route B** | GCP 獨立運作；IDC fail-closed |

S3 與 S4 需分兩次部署分別驗證（Route A / B 互斥）。

---

### TC-MS-01　S1 — 雙站各 50% 流量

**Objective：** 驗證兩站同時承載寫入時的延遲差異與 Raft replication 穩定性，並對照 control plane 位置的影響。

**Setup：** IDC client 連 IDC SQL 入口；GCP client 連 GCP SQL 入口；各承擔 50% 寫入，持續 ≥10 min。建議 Route A 與 Route B 各跑一次以比較 TSO / master 位置造成的延遲差異。

**Metrics：** 各站 p95 / p99 write latency、commit latency、TSO / master RTT、cross-site network bytes、conflict rate

**Pass：** 兩站皆可穩定寫入，延遲差異可對應 control plane 位置解釋。
**Fail：** 任一站出現非預期錯誤，或延遲差異無法解釋。

---

### TC-MS-02　S2 — 計劃性將流量從 IDC 切換至 GCP

**Objective：** 驗證計劃性流量切換期間無寫入中斷，GCP 承擔全量後穩定運作。

**Setup：** 初始 IDC 100% 流量，逐步遷移至 GCP（100/0 → 50/50 → 0/100），模擬 LB / DNS 切換。

**Metrics：** 切換期間 write error 數量、latency spike、retry count；GCP 全量後 p95 write latency

**Pass：** 切換期間寫入不中斷（允許短暫 retry），全切後 GCP 運作穩定。
**Fail：** 切換期間出現不可恢復錯誤、長時間中斷、或全切後 GCP 持續異常。

---

### TC-MS-03　S3 — 專線中斷，IDC 繼續運作

**前提：必須使用 Route A。** PD / master quorum 在 IDC；每個 Raft group ≥2 replica 在 IDC。

**Objective：** 驗證 IDC 斷線後可獨立寫入；GCP 呈現 fail-closed。

**Setup：** 兩站皆有 client 持續寫入（從 S1 狀態起），以 `iptables` 切斷 IDC↔GCP 連線，持續觀察 10 min，恢復後驗證資料一致性。

**Metrics：** IDC write 可用性、GCP write 是否 fail-closed、斷線後 Raft group 狀態、reconnect 後資料 diff

**Pass：** IDC 持續寫入；GCP 停止寫入且無資料不一致。
**Fail：** IDC 中斷、GCP 仍接受寫入（split-brain），或 reconnect 後資料衝突。

> **注意：** 若使用 Route B 執行本 TC，IDC 只剩 1 個控制面節點而失去 quorum，IDC 會停止、GCP 繼續，這是 Route B 的設計行為，非缺陷。

---

### TC-MS-04　S4 — 專線中斷，GCP 繼續運作

**前提：必須使用 Route B。** PD / master quorum 在 GCP；每個 Raft group ≥2 replica 在 GCP。

**Objective：** 驗證 GCP 斷線後可獨立寫入；IDC 呈現 fail-closed。

**Setup：** 兩站皆有 client 持續寫入（從 S1 狀態起），以 `iptables` 切斷 IDC↔GCP 連線，持續觀察 10 min，恢復後驗證資料一致性。

**Metrics：** GCP write 可用性、IDC write 是否 fail-closed、斷線後 Raft group 狀態、reconnect 後資料 diff

**Pass：** GCP 持續寫入；IDC 停止寫入且無資料不一致。
**Fail：** GCP 中斷、IDC 仍接受寫入（split-brain），或 reconnect 後資料衝突。

> **注意：** 若使用 Route A 執行本 TC，GCP 無 PD / master quorum 而停止，IDC 繼續，這是 Route A 的設計行為。

---

### S3 / S4 執行前置驗證

執行 TC-MS-03 / TC-MS-04 前，確認 placement 已生效：

**TiDB**
```bash
# 確認 TiKV label
pd-ctl store --jq '.stores[] | {id: .store.id, labels: .store.labels, address: .store.address}'
# 確認 placement rule
pd-ctl config placement-rules show
# 確認 Region replica 分布
pd-ctl region --jq '.regions[] | {id: .id, peers: [.peers[] | .store_id]}'
```

**YugabyteDB**
```bash
# 確認 master placement
yb-admin -master_addresses <masters> list_all_masters
# 確認 tablet replica 分布
yb-admin -master_addresses <masters> list_tablets_for_table ysql.<db> account
# 確認 tablespace
SELECT spcname, spcoptions FROM pg_tablespace;
```
