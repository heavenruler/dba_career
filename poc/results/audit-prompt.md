# PoC v4.7 文件審計 — Codex Prompt

> **用法**：開 codex，貼下方整段（從 `你是 ...` 起到本檔末），讓它對 5 個 markdown 產報告。報告**不直接修改檔案**。

---

你是 PoC v4.7 TPC-C benchmark 文件審計員。本 PoC 比較分散式 DB（TiDB、CockroachDB、YugabyteDB）在相同硬體（4 vCPU / 15 GiB RAM / single XFS disk）下的吞吐 / latency / 資源使用。

請對下列 5 個檔案進行**逐檔審計**，並產出**結構化 markdown 報告**：

待審檔案（皆位於 `/Users/wn.lin/vscode-git/dba_career/poc/results/`）：
1. `README.md`
2. `tidb-tc1/S-BASE/pipeline-log.md`
3. `crdb-tc1/S-BASE/pipeline-log.md`
4. `cockroach-tc1/S-BASE/pipeline-log.md` ← 舊版資料，僅核對是否有「已移轉至 crdb-tc1」標註
5. `yuga-tc1/S-BASE/pipeline-log.md`

## 審計六大維度（每個 finding 必須標註類別）

| 代號 | 維度 | 檢查重點 |
|------|------|----------|
| **D1** | 錯誤登錄數據 | tpmC / latency / %iowait 等表格數字內部一致性（如某段聲稱 tpmC 9034 但另一段引用為 9134）；單位／時間戳格式錯亂；round-by-round 表與 5-round mean 是否能對齊重算 |
| **D2** | 語意正確性 | isolation level 機制描述是否與官方文件一致；DB 行為斷言是否有 artifact 數據支持；因果鏈（e.g.「因 %iowait 高所以 IO-bound」）是否站得住腳 |
| **D3** | 文件可讀性 | 標題層級、表格欄位、引用樣式是否一致；中英混排是否乾淨；冗長段落／重複表述；新讀者是否能在 5 分鐘內抓到結論 |
| **D4** | 完整性 | 是否每組 `(db, iso)` 都有「環境 / 結果 / DB-host 飽和分析 / 對比 / 結論」標準段落；TPCC_TS 是否齊全；結果目錄路徑是否真實存在 |
| **D5** | 跨檔一致性 | 同硬體跨檔引用是否同數字（如 `crdb-tc1` 提到 TiDB 的對比，要與 `tidb-tc1` 內的原始數字相符）；isolation 矩陣 status 在 README 與各 pipeline-log 是否同步 |
| **D6** | 改進建議 | 缺漏的圖表、未答疑的後續 question、可加強的 reproducibility 註記 |

## 輸出格式（嚴格遵守）

```markdown
# PoC v4.7 文件審計報告 — <yyyy-mm-dd>

## 1. 審計概覽
- 檔案數：5
- 總 findings：N（critical X / major Y / minor Z）
- 對應 git HEAD：<short SHA>（git log -1 --format=%h）
- 上次審計報告（如有）：…

## 2. Critical Findings（資料錯誤 / 機制錯誤，必修）
### F-001 [D1] <短描述> — <檔案>
- 位置：L<行號>（必要時標多處）
- 現況：…
- 證據：（**必須引用 artifact 路徑** `runs/threads-X/round-Y/go-tpc-stdout.txt` 之原始數據或官方文件 URL）
- 建議：…

### F-002 …

## 3. Major Findings（語意 / 完整性，建議修）
…

## 4. Minor Findings（可讀性 / 建議）
…

## 5. 跨檔一致性矩陣
| 比較項 | tidb-tc1 | crdb-tc1 | yuga-tc1 | 一致？ |
|--------|----------|----------|----------|--------|
| TiDB RC t128 tpmC | … | … | n/a | ✓/✗ |
| CRDB RC t128 tpmC | n/a | … | n/a | ✓/✗ |
| isolation matrix status | … | … | … | ✓/✗ |
| … | | | | |

## 6. 下次審計建議追蹤項
- …
```

## 操作守則
- **不要直接 edit 檔案**，僅產報告
- 對任何「斷言 vs artifact 數據」的不一致，**重算原始 `go-tpc-stdout.txt` 驗證**（grep `^tpmC:` / `^\[Summary\]`）
- 對機制描述（isolation / retry / refresh）的疑點，**引用官方文件 URL**（CRDB / TiDB / YugabyteDB docs）
- finding 嚴重度標準：
  - **critical** = 影響結論的數據錯誤 / 機制錯誤
  - **major** = 段落缺漏 / 跨檔不一致 / 引用錯誤
  - **minor** = 排版 / 用詞 / 補強建議
- 報告完成後，將檔案存到 `/Users/wn.lin/vscode-git/dba_career/poc/results/audit/audit-<yyyy-mm-dd>.md`（不存在則建立 `audit/` 目錄）

## 邊界
- 不要修改任何 pipeline-log.md / README.md
- 不要 commit、不要 push
- 不要訪問 `*.lock-*`、`runlocks/`、其他 artifact 子目錄以外的檔案

開始審計。
