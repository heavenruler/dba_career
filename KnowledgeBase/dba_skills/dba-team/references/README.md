# references 說明

## 1. references 目錄用途

`references/` 是 `dba-team` 的知識庫目錄，用來保存可重用、可查證、可維護的資料庫與架構知識。它不是暫存區，而是團隊共同依賴的半結構化知識來源。

此目錄的目標：

- 讓 prompts 有一致的知識基礎可引用
- 讓 workflows 可以優先套用既有標準與 SOP
- 將已沉澱的經驗從 `memory/` 提升為可維護知識

## 2. 建議放置的內容類型

建議將以下內容放入 `references/`：

- 官方文件摘要
- 架構設計筆記
- SOP 與 runbook
- 故障案例與 RCA 摘要
- SQL / shell / ansible / terraform 範本
- benchmark / PoC 結果
- 升級、遷移、回退清單
- 容量規劃、監控閾值、review checklist

## 3. 建議分類方式

可依需求逐步擴充子目錄，例如：

```text
references/
├── vendor/
├── architecture/
├── sop/
├── incidents/
├── templates/
├── poc/
└── reviews/
```

若目前規模不大，也可先以檔名分類，不必過早拆分子目錄。

目前專案已提供 `references/templates/` 作為初始模板包，供架構設計、incident RCA、migration、SOP、PoC 與自動化交付直接套用。

## 4. 命名規範

建議採用以下命名規則：

- 全小寫英文與 kebab-case
- 檔名包含主題與類型
- 必要時加上版本、平台或日期

範例：

- `mysql-mgr-deployment-sop.md`
- `postgresql-pitr-runbook.md`
- `oracle-19c-upgrade-review-2026-03.md`
- `tidb-poc-benchmark-q1-2026.md`
- `redis-bigkey-troubleshooting.md`

## 5. 分類規範

每份 reference 建議至少包含：

- `title`
- `scope`
- `applicable_versions`
- `environment`
- `summary`
- `steps` 或 `findings`
- `risks`
- `related_files`
- `last_updated`

若為範本型文件，可加入：

- `variables`
- `example_commands`
- `validation`
- `rollback`

## 6. 更新原則

1. 優先更新已存在文件，避免同主題多份版本漂移。
2. 若是歷史事件沉澱為標準知識，再搬入 `references/`。
3. 更新時需同步調整適用版本與限制說明。
4. 若內容來自官方文件摘要，需註記來源與查證日期。
5. 若 PoC 或 benchmark 已過期，需標記 `deprecated` 或重跑驗證。

## 7. 去重原則

為避免重複知識與矛盾結論，建議：

1. 同一主題優先保留一份主文件，再用相關連結指向延伸內容。
2. 若內容只是不同環境版本差異，應集中在同文件中分章節描述。
3. 若相同 SOP 出現多份複本，保留最新且經驗證版本，其餘改成索引或刪除。
4. `memory/history.json` 若已有完整結論，可將其整理成 reference，再在 history 留下索引。

## 8. 如何被 prompts 與 workflows 引用

### 8.1 prompts 引用方式

各專家 prompt 在下列情況應優先引用 `references/`：

- 需要標準部署流程
- 需要既有故障案例或 SOP
- 需要 benchmark / PoC / review 佐證
- 需要公司內部模板與規範

### 8.2 workflows 引用方式

workflow 於 `knowledge reference lookup` 階段應先檢查本目錄：

- 問答流程：查 FAQ、SOP、常用命令模板
- 架構流程：查設計筆記、PoC、benchmark
- 故障流程：查 incident 與 runbook
- migration / upgrade / PoC：查相容性筆記、驗證清單、歷史結果
- 文件流程：查模板與既有文件格式

## 9. 實務建議

- 新知識先簡短落地，再逐步補全，不要等到完美才寫。
- 與其存很多碎片，不如維護少量高品質主文件。
- 每份文件要能回答「何時用、怎麼用、限制是什麼」。
- 若 references 不足，應在任務結束時標記待補項，讓知識庫可持續演進。
