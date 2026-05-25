# AI 協作準則 — PoC results 文件與執行校驗

> 本文件定義 Codex / Claude Code session 在本 PoC 專案中的協作方式。目標不是讓 AI 取代判斷，而是讓 AI 協助整理 artifact、校驗流程、降低人工遺漏，並把技術分析與文件貢獻變成可追溯成果，避免任何邏輯 / 數據 / 流程 或其他相關技術可見的瑕疵及錯誤發生。

## 使用定位

| 角色 | 主要用途 | 不應做的事 |
|---|---|---|
| Codex session | repo 內檔案修改、git diff 檢查、模板落地、文件重構、局部驗證 | 不憑空補數據、不覆蓋未確認變更 |
| Claude Code session | 第二視角審閱、語意一致性檢查、報告口徑校正、長文件重構建議 | 不把推論寫成事實、不跳過 artifact 驗證 |
| 人工 reviewer | 決定測試口徑、確認 caveat 是否可接受、批准 commit / merge | 不直接採用未驗證 AI 結論 |

## 基本原則

- **artifact-first**：所有數據必須能回到 `results/<db>-tc1/S-BASE/...` 下的執行目錄、marker、log、summary 或 pipeline log。
- **template-first**：README 與 pipeline log 必須依照 `README-template.md` / `pipeline-log-template.md` 維持一致格式。
- **no invented numbers**：AI 不得自行推估或創造 tpmC、p99、error rate、CPU、IO、round 數據。
- **distinguish fact from inference**：OS 指標直接支持的是觀察；DB 內部機制若缺 metrics / trace，只能標為推測。
- **short table, long note**：主表只放數字、狀態、來源與短判讀；踩坑、限制、技術細節放到文末註解或 dedicated caveat。
- **one source per result**：每個已驗證結果必須有來源目錄 link，不可只寫口頭結論。
- **protect dirty worktree**：修改前先看 `git status --short`，只 stage/commit 本次要求範圍。

## 文件重構流程

1. 讀取目前狀態：
   ```bash
   git status --short
   rg -n "^#|^##|^###|^\\|" results/README.md results/*-tc1/S-BASE/pipeline-log.md
   ```

2. 檢查 artifact：
   ```bash
   find results -path "*vm-1node*" -name ".suite.done" -o -name ".run.done" -o -name "go-tpc-stdout.txt"
   ```

3. 對照模板：
   - `results/README-template.md`
   - `results/pipeline-log-template.md`

4. 修改文件：
   - README 作為索引。
   - pipeline log 作為完整分析。
   - 差異解釋使用 `[註1](#note-1)` 到 `[註4](#note-4)`。

5. 校驗：
   ```bash
   rg -n "CRDB|YBDB|產物|TODO|待補|推測|註[1-4]" results/README.md results/*-tc1/S-BASE/pipeline-log.md
   git diff --stat
   ```

6. 提交：
   ```bash
   git add <本次修改檔案>
   git commit -m "<type>: <summary>"
   ```

## 防幻覺檢查清單

| 檢查項 | 要求 |
|---|---|
| 數字來源 | 每個 tpmC / p99 / error rate 都要能追到 log、summary 或 pipeline log |
| 執行口徑 | v4.7 5-round mean 與 pre-v4.7 single-run 不可混用 |
| 隔離級 | READ COMMITTED / REPEATABLE READ / SERIALIZABLE 必須有 gate 或設定證據 |
| error rate | 不只看 tpmC；高吞吐若伴隨 retry / abort，必須註記 |
| 機制解釋 | WAL / Raft / Pebble / MVCC / retry 等機制需區分「量測」與「推論」 |
| 來源連結 | README 的 `來源目錄` 必須是 Markdown link 且目錄存在 |
| 表格語言 | 表格中不放長段 caveat，改用註記欄 |
| 命名語言 | 正文使用 CockroachDB / YugabyteDB，不使用 CRDB / YBDB |

## 互相校驗模式

### Codex → Claude Code

Codex 完成初版修改後，交給 Claude Code 做第二視角審閱：

```text
請審閱本 repo 的 PoC results 文件變更，重點不是改寫文風，而是找出：

1. 是否有數字沒有 artifact 支持。
2. 是否把 pre-v4.7 single-run 結果與 v4.7 5-round mean 混用。
3. 是否有表格內 caveat 太長，應移到文末註解。
4. 是否有機制推論被寫成事實。
5. 是否有 README 與 pipeline-log.md 對同一數據說法不一致。
6. 是否仍出現 CRDB / YBDB / 產物 等不符合文件規則的文字。

請輸出：
- findings，按嚴重度排序
- 需要修正的檔案與段落
- 建議修法
- 不確定但需要人工確認的問題

不要自行發明數字；只根據 repo 內 artifact 與文件內容判斷。
```

### Claude Code → Codex

Claude Code 提出建議後，交給 Codex 落地修改與驗證：

```text
請根據上一個審閱 session 的 findings 修改 repo 文件。

限制：
- 只修改被點名的文件與段落。
- 不新增未經 artifact 支持的新數字。
- 表格維持 template 設計語言。
- 長解釋移到文末註解或 caveat 段落。
- 修改後執行 rg / git diff 檢查，確認沒有不合規文字。

完成後回報：
- 修改檔案
- 修正摘要
- 驗證指令與結果
- 是否需要 commit
```

## 執行監控 prompt

```text
請作為旁觀者架構師監控本 PoC 執行進度。

你需要定期檢查：
- gate / prepare / gate-isolation / run / collect / suite marker 是否完成
- 是否產生 summary / go-tpc stdout / DB-host OS 監控檔
- isolation gate 是否符合目標隔離級
- 是否存在中斷、manual resume、重跑、purge data 或 process cleanup 的必要性
- 新 artifact 是否需要更新 README.md 或 pipeline-log.md

規則：
- 沒有新變化時只回報 standby。
- 發現異常時列出具體檔案路徑與建議確認問題。
- 不把尚未完成的測試寫成已完成。
- 不換算工時，只看流程與資料品質。
```

## 文件重構 prompt

```text
請根據以下模板重構 results 文件：

- results/README-template.md
- results/pipeline-log-template.md

重構目標：
- README.md 作為乾淨結果索引。
- pipeline-log.md 作為詳細流程與分析文件。
- 主表只保留數字、來源、狀態、短判讀。
- 踩坑、技術細節、機制推論、比較限制、資料品質 caveat 放到文末註解或 dedicated caveat。

註解規則：
- 表格內使用 `註記` 欄。
- 表格外段落在句尾使用 `[註1](#note-1)` 等連結。
- 文末使用 `<a id="note-1"></a>` anchor。
- `註1~註4` 全文件共用，不針對單一表格重新編號。

必檢：
- 每個已驗證結果都要有來源目錄 link。
- 已驗證結果要包含 tpmC、p99、error rate。
- pre-v4.7 結果不得冒充 v4.7 baseline。
- 機制推論必須標示推測或待補 metrics / trace。
```

## 資料抽取與驗算 prompt

```text
請只做資料抽取與驗算，不改文件。

目標：
- 從指定結果目錄抽取 tpmC、p50、p95、p99、error count、error rate。
- 驗算 pipeline-log.md / README.md 內對應數字是否一致。
- 確認欄位口徑是 5-round mean、單次 run、或其他來源。

限制：
- 不推估缺失數字。
- 找不到來源就標記 missing source。
- latency 欄位需說明是 NEW_ORDER p50/p95/p99，還是其他交易類型。
- error rate 需說明分母，例如 NEW_ORDER total、all transaction total、或 go-tpc summary 可得的總量。

輸出：
- artifact 路徑
- 抽取方法
- 驗算表
- 不一致項目
- 建議修正，但不要直接修改檔案
```

## 異常根因分析 prompt

```text
請針對指定 case 做異常根因分析。

輸入：
- 結果目錄
- 觀察到的異常，例如 tpmC drop、p99 spike、error rate 升高、run 中斷、marker 缺失

分析順序：
1. 先確認 marker chain 是否完整。
2. 檢查 go-tpc stdout 是否有 NEW_ORDER_ERR / retry / timeout。
3. 檢查 DB-host mpstat / iostat / vmstat / sar。
4. 檢查 gate-isolation 是否符合目標隔離級。
5. 區分直接量測、合理推論、仍需補證據三類。

輸出格式：
- 直接事實
- 可支持的推論
- 不能下結論的部分
- 建議補採的 artifact 或 metrics
- 是否需要重跑
```

## Session handoff prompt

```text
請產生 handoff note 給下一個 AI session。

內容必須包含：
- 目前目標
- 已完成事項
- 未完成事項
- 重要檔案路徑
- 目前 git status
- 不能碰或需要避開的檔案
- 下一步建議
- 已知 caveat / 人工待確認問題

要求：
- 不要重新分析所有內容。
- 聚焦讓下一個 session 可以不中斷接手。
- 若有未 commit 變更，明確列出檔案與原因。
```

## 報告前審計 prompt

```text
請做報告前審計，目標是找出會讓 PoC 結論失真的問題。

審計項目：
- README.md 的最高 tpmC 是否與 pipeline-log.md 一致。
- 已驗證結果是否都有來源目錄 link。
- error rate 是否缺失或分母不清。
- pre-v4.7 結果是否被誤列為 v4.7 baseline。
- 差異分析是否有註記並連到文末註解。
- 機制推論是否標示為推測或待補證據。
- 是否還有 CRDB / YBDB / 產物 等不合規文字。

輸出：
- Blocker：會導致結論錯誤，必須修
- Warning：容易誤讀，建議修
- Note：可延後處理
```

## AI 使用方式地圖

| 使用情境 | 建議 session | 主要輸出 |
|---|---|---|
| 長文件重構 | Codex 主改，Claude Code 審閱 | markdown patch、diff summary |
| 數據驗算 | Claude Code 或 Codex read-only | mismatch list、missing source |
| 執行監控 | Codex | marker status、異常提醒 |
| 根因分析 | Claude Code 先分析，Codex 補查 artifact | fact / inference / unknown 分層 |
| 報告前審計 | Claude Code 第二視角 | blocker / warning / note |
| session 交接 | 任一 session | handoff note |

## AI 貢獻衡量

| 貢獻面向 | 可驗證成果 |
|---|---|
| 文件一致性 | README / pipeline log 依模板維持相同結構與語言 |
| 資料可追溯 | 每個結論可連到結果目錄、marker、log 或註解 |
| 減少人工作業遺漏 | 自動提示 missing marker、missing summary、isolation gate 不一致 |
| 降低幻覺風險 | 強制 artifact-first、no invented numbers、fact vs inference |
| 技術深度累積 | 將 retry、MVCC、WAL、Raft、fsync、CPU / IO bound 等機制整理為可審閱 caveat |
| 協作效率 | Codex 負責落地與驗證；Claude Code 負責第二視角審閱；人工 reviewer 負責決策 |

## 最低完成標準

一次 AI session 若修改 results 文件，至少要做到：

- 說明修改了哪些檔案。
- 說明採用哪些 artifact 或 pipeline log。
- 明確列出仍需人工確認的問題。
- 提供 `git diff --stat`。
- 不自動 commit 未被要求提交的內容。
