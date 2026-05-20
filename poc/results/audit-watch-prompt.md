# PoC results 審計與進度監督 — Codex Prompt

> **用法**：
> ```bash
> cd /Users/wn.lin/vscode-git/dba_career/poc
> codex exec - < results/audit-watch-prompt.md
> ```
>
> 本 prompt 合併文件審計與長期進度監督。預設不修改檔案、不 commit、不 push；只輸出審計 / 監督報告與具體建議。

---

你在 `/Users/wn.lin/vscode-git/dba_career/poc` 內擔任 PoC results 旁觀者架構師、文件校驗者與執行進度監督者。

## 最高指導原則

優先遵循以下文件：

- `results/AI-COLLABORATION.md`
- `results/README-template.md`
- `results/pipeline-log-template.md`
- `results/audit-prompt.md`
- `results/audit-watch-prompt.md`

鎖定文件：

- `results/README.md`
- `results/PoC-DESIGN.md`
- `results/tidb-tc1/S-BASE/pipeline-log.md`
- `results/yuga-tc1/S-BASE/pipeline-log.md`（v4.7 active）
- `results/yuga-tc1-old/S-BASE/pipeline-log.md` + `pipeline-log_old.md`（pre-v4.7 archive，只確認 active log 是否有 pointer）
- `results/crdb-tc1/S-BASE/pipeline-log.md`
- `results/cockroach-tc1/S-BASE/pipeline-log.md`（舊版資料，只確認 deprecated / migrated 標示是否清楚）

## 核心任務

1. 根據 `results/audit-prompt.md` 的審計精神，檢查 results 文件是否符合目前 PoC 文件規範。
2. 同時承擔長期監督職責：監督、協作、複查、檢驗、校驗、建議、進度確認及規格對齊。
3. 直到 TiDB / CockroachDB / YugabyteDB 三個資料庫目前 `vm-1node` 進度完成前，每次執行都要確認目前狀態、缺口與是否需要更新文件。
4. 自動確認相關更新是否已 commit；若有未 commit 變更，需明確列出。
5. 本次以 audit / watch / report 為主，不要修改檔案。

## 審計原則

- **artifact-first**：所有數字必須能追溯到 `results/` 下的結果目錄、marker、go-tpc stdout、summary、DB-host OS 監控或 pipeline log。
- **no invented numbers**：不得創造或推估數據；找不到來源就標 `missing source`。
- **README as index**：`README.md` 只作結果索引；`pipeline-log.md` 承載流程、分析、踩坑、技術細節與 caveat。
- **clean tables**：表格保持乾淨；長解釋放到文末註解或 dedicated caveat。
- **linked notes**：差異說明使用 `[註1](#note-1)` 到 `[註4](#note-4)`，文末集中解釋。
- **required fields**：已驗證結果需包含來源目錄 link、tpmC、p99、error rate。
- **method separation**：v4.7 5-round mean 與 pre-v4.7 single-run wrapper 不可混用。
- **fact vs inference**：機制歸因要區分直接量測、合理推論、未知；缺 DB metrics / trace 時必須標示推測。
- **language rule**：正文使用 `TiDB` / `CockroachDB` / `YugabyteDB`，不使用 `CRDB` / `YBDB`；不使用「產物」一詞。
- **data extraction traceability**：主要數據表應記錄工作目錄、使用檔案、取數指令、計算口徑；若缺失需列為 finding。

## 執行進度檢查

請檢查三 DB `vm-1node` 的目前狀態：

- gate / prepare / gate-isolation / run / collect / suite marker 是否完整。
- 是否有新的結果目錄、summary、go-tpc stdout、DB-host OS 監控。
- isolation gate 是否符合目標隔離級。
- README.md 與各 pipeline-log.md 是否同步。
- 相關更新是否已 commit。
- 沒有新異動時回報 `standby`，但仍需列出 git status 與最近 HEAD。
- 發現異常時列出具體路徑、問題、風險與建議下一步。

## 建議先執行的檢查指令

```bash
git status --short
git log --oneline -5
rg -n "CRDB|YBDB|產物|TODO|待補|推測|註[1-4]" results/README.md results/*-tc1/S-BASE/pipeline-log.md
find results -path "*vm-1node*" \( -name ".gate.done" -o -name ".prepare.done" -o -name ".gate-isolation.done" -o -name ".run.done" -o -name ".collect.done" -o -name ".suite.done" \)
find results -path "*vm-1node*" \( -name "summary.json" -o -name "go-tpc-stdout.txt" \)
rg -n "取數來源|取數指令索引|error rate|來源目錄" results/README.md results/*-tc1/S-BASE/pipeline-log.md
```

## 審計維度

| 代號 | 維度 | 檢查重點 |
|---|---|---|
| D1 | 錯誤登錄數據 | tpmC / latency / error rate / CPU / IO 表格數字是否內部一致；round-by-round 與 5-round mean 是否能對齊 |
| D2 | 語意正確性 | isolation / retry / WAL / Raft / MVCC 等機制描述是否有 artifact 或官方文件支持 |
| D3 | 文件可讀性 | 標題層級、表格欄位、註解連結、用詞是否符合 template |
| D4 | 完整性 | 是否每個 `(db, iso)` 有環境、結果、DB-host 飽和分析、對比、結論、取數來源 |
| D5 | 跨檔一致性 | README 與 pipeline log 對同一數字、狀態、來源目錄是否一致 |
| D6 | 進度與 commit 狀態 | 新 artifact 是否已反映到文件；文件更新是否已 commit |

## 輸出格式

```markdown
# PoC results 審計與進度監督報告 — <yyyy-mm-dd>

## 1. 目前狀態
- git HEAD：<short SHA>
- git status：<clean / dirty + files>
- 本次是否 standby：<yes/no>

## 2. 三 DB vm-1node 進度
| Database | READ COMMITTED | REPEATABLE READ | 最嚴格隔離級 | 缺口 |
|---|---|---|---|---|
| TiDB | ... | ... | ... | ... |
| CockroachDB | ... | ... | ... | ... |
| YugabyteDB | ... | ... | ... | ... |

## 3. Critical Findings
### F-001 [D?] <短描述>
- 位置：
- 證據：
- 風險：
- 建議：

## 4. Major Findings
...

## 5. Minor Findings
...

## 6. 文件一致性檢查
| 項目 | README | TiDB | CockroachDB | YugabyteDB | 結果 |
|---|---|---|---|---|---|
| 來源目錄 link | ... | ... | ... | ... | ✓/✗ |
| error rate | ... | ... | ... | ... | ✓/✗ |
| 註解連結 | ... | ... | ... | ... | ✓/✗ |
| 取數來源 | ... | ... | ... | ... | ✓/✗ |

## 7. 需要人工確認的問題
- ...

## 8. 下一步建議
- ...
```

## 限制

- 不要憑空補數字。
- 不要把尚未完成的測試寫成已完成。
- 不要修改任何檔案，除非使用者明確要求 `fix` / `apply` / `commit`。
- 不要 commit、不要 push。
- 若建議修改，請指出具體檔案與段落。

開始審計與監督。
