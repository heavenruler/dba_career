# KnowledgeBase

DBA 個人知識庫的 PDF → markdown → chunk pipeline。涵蓋範疇不限於 DBA：架構設計 / SRE / 心理 / 職涯面試 / 研究方法等任意有資訊密度的內容都收。

## 概念對照

| 路徑 | 角色 |
|---|---|
| `collector/*.pdf` | **來源 PDF**（檔名 = `md5(content).pdf`） |
| `output_with_md5.txt` | **manifest**：每 3 行 `title / url / md5`，`----` 分隔 |
| `scripts/*.py` | pipeline 各階段 |
| `Makefile` | 操作入口 |
| `docs/tier_a_sources.md` | 缺口分析（45 項權威來源） |
| `generated/extracted/<md5>/` | PDF 抽出的 markdown（含 frontmatter / page markers / sha256） |
| `generated/filtered/<md5>/` | LLM filter 後的結構化 knowledge JSON |
| `generated/kb/{documents,chunks,missing_documents,source_audit}.jsonl` | RAG 用的最終產物 |

`generated/` 全部 gitignored，可從 `collector/` + `output_with_md5.txt` 重建。

---

## 新增文章後的操作（首選）

```bash
cd KnowledgeBase

# 0. PDF 入庫（FireShot 會自動寫 manifest；手動複製的見「邊角案例」）
mv ~/Downloads/FireShot/*.pdf collector/

# 1. 一鍵同步（reconcile → extract → OCR → rebuild chunks → audit）
make sync
```

`make sync` 全部子步驟 **idempotent**（重跑無害）；900 篇庫存空跑約 8 秒。新增 N 篇 PDF 約 +`N×1.5s`（無 OCR）或 +`N×30s`（含 OCR）。

LLM filter **不含**在 sync（耗時與配額大）；要跑請另用 `make filter_doc` / `make filter_test`。

---

## 完整 7 步驟（手動拆解 sync）

### Step 0. PDF 入庫

| 情境 | 動作 |
|---|---|
| A. FireShot 抓網頁 | `mv ~/Downloads/FireShot/*.pdf collector/` — FireShot 同時寫好 manifest |
| B. 手動複製 | PDF 必須以 `md5(content).pdf` 命名：`mv file.pdf collector/$(md5 -q file.pdf).pdf` |

### Step 1. 補 manifest

```bash
make reconcile_manifest
```

從 PDF 內嵌 `pdfinfo` Title/Subject 反推，append 到 `output_with_md5.txt` 結尾。已存在的 doc_id 不重複寫。情境 A 也建議跑當 sanity check。

### Step 2. 修壞 md5（可選）

```bash
make md5_fix
```

僅在 manifest 有 placeholder（如 `nnn`）或 md5 與 PDF 內容不符時跑。

### Step 3. 抽文字（incremental）

```bash
make extract_pdf
```

預設 `--skip-existing`：已抽過的 PDF 會跳過，**只跑新增的**。強制重抽：

```bash
python3 scripts/extract_pdf.py --doc-id <md5>           # 單篇
python3 scripts/extract_pdf.py --all --force            # 全量（不建議：會洗 OCR 成果）
```

輸出格式（嚴謹模式）：

```
generated/extracted/<md5>/
├── full.md           # YAML frontmatter + <!-- page:N --> 邊界
└── metadata.json     # sha256 / page_count / char_count / avg_chars_per_page / needs_ocr
```

### Step 4. OCR 圖像 PDF（incremental）

```bash
make ocr_pdf
```

自動只挑 `needs_ocr=true AND ocr_used=false` 的 doc 跑（tesseract `chi_sim+chi_tra+eng`，250 dpi）。若遇 `Image too large`（超長截圖）：

```bash
python3 scripts/ocr_pdf.py --doc-id <md5> --dpi 120
python3 scripts/ocr_pdf.py --doc-id <md5> --dpi 90   # 極端長截圖
```

OCR 完成後 `metadata.json` 會多 `ocr_used=true / ocr_engine`。

### Step 5. LLM filter（可選，per-doc）

只對值得深度去噪的 doc 跑。Provider 預設 codex（無需 API key）。

```bash
make filter_doc DOC_ID=<md5>                                    # 跑一篇（不刪舊）
make filter_test DOC_ID=<md5>                                   # 強制刪舊重跑
make filter_doc DOC_ID=<md5> PROVIDER=openai MODEL=gpt-5.4-mini # 改 OpenAI
```

跑完印出 token 用量 + codex 5h / 7d 額度：

```
usage  tokens in=29752 (cached=2432) out=1796 reasoning=66 total=31548 |
       5h window used=2.0% remaining=98.0% resets@2026-05-22 03:59 |
       7d window used=11.0% remaining=89.0% resets@2026-05-27 09:44 | plan=plus
```

**Prompt 規範：extractive-only**
- `section.content` 必須是原文逐字片段（不改寫 / 不意譯 / SQL 連縮排照抄）
- 移除：廣告 / 作者卡 / 頁眉頁腳 / URL / 時間戳 / 訂閱引導
- heading / summary / tags 可自由命名

**5h window 預算**：900 doc 全跑一輪約 30M tokens，會跑滿 5h window，需分批。

### 全量批次跑：`./todo.sh`

預先生成的執行清單（896 docs，按 char_count 大→小排序）：

```bash
./todo.sh --dry-run   # 預覽會跑哪些 doc
./todo.sh             # 開跑（Ctrl-C 可隨時停，重跑接續）
```

**完成標注 / 防重複機制**：

| 機制 | 行為 |
|---|---|
| `.todo.state`（gitignored） | 每篇 filter 成功 → append `<doc_id> <UTC time> ok` |
| Pre-check | 每篇開跑前查 state + `knowledge.json` 是否存在 → 任一為真就 SKIP |
| Backfill | 若發現某 doc 已有 knowledge.json 但 state 沒記 → 自動補進 state（`backfilled` 標記） |
| Recovery | 想強制重跑某篇：手動 `grep -v <doc_id> .todo.state > tmp && mv tmp .todo.state` + `rm -rf generated/filtered/<doc_id>` |

**錯誤策略**：個別 fail 寫進 `filter_failed.log` 不中斷；codex 5h window 額度滿時整批會接連 fail，停掉等下個 window 再跑。

**進度查看**：

```bash
wc -l .todo.state                            # 已完成幾篇
tail -5 .todo.state                          # 最近 5 篇完成時間
ls generated/filtered/ | wc -l               # 實際 knowledge.json 數
tail -20 filter_progress.log                 # 完整 log
```

### Step 6. 重建 chunks

```bash
# 全量（秒級，safest；filter 過的自動讀 filtered/，否則讀 extracted/）
rm -rf generated/kb && make build_chunks

# 或單 doc partial update（不影響其他 doc）
make build_chunks DOC_ID=<md5>
```

### Step 7. Sanity check

```bash
make audit_sources
python3 -m json.tool < generated/kb/source_audit_summary.json
wc -l generated/kb/documents.jsonl generated/kb/chunks.jsonl
```

---

## 邊角案例

| 狀況 | 處理 |
|---|---|
| 新 PDF 是既有 doc_id 重複 | extract 自動 skip；要重抽用 `--force` |
| 新 manifest 條目重複既有 doc_id | 直接 grep + 手動刪後寫的；或寫腳本同 commit `8e31221` 那次 dedup |
| 新 PDF 沒 Title/Subject metadata | reconcile_manifest 會跳過；手動 append 三行進 `output_with_md5.txt`：<br>`title\nurl\n<md5>\n----` |
| 抽後 char_count 低但 needs_ocr=false | 看 `avg_chars_per_page`；50-200 通常是混排，可手動跑 OCR 試 |
| FireShot 寫的 title 亂碼 | 直接改 `output_with_md5.txt` 該 block 的第 1 行，重跑 `make build_chunks` 即可（不必重抽） |

---

## 目前統計（截至 2026-05-21）

- **PDFs**：897（collector/）
- **Documents**：897（generated/kb/documents.jsonl，全部 status=ok）
- **Chunks**：14,573（generated/kb/chunks.jsonl，每塊含 `page_start`/`page_end`/`chunk_types`/`primary_category`/`tags`）
- **OCR**：119 篇圖像 PDF 已完成（tesseract chi_sim+chi_tra+eng）
- **Filter**：2 篇試跑（`44862a...`、`98be07...`）

分類分布（chunks）：

```
高可用與複製 3,614   架構案例與分庫分表 2,202
SQL 與查詢優化 3,171   監控與故障處理 864
部署升級與配置 2,750   資料遷移與同步 818
                        InnoDB 核心原理 404
                        安全與權限 381
                        培訓與參考 218
                        備份恢復與容災 153
```

來源缺口（見 `docs/tier_a_sources.md`）：MongoDB / 備份恢復 / 安全權限 / 雲端 RDS — 微信公眾號占 79%，無官方手冊 / 書籍 / 學術 paper。

---

## Make targets 一覽

```
make sync                NEW: reconcile + extract + OCR + rebuild + audit (一鍵)
make filter_doc DOC_ID=  LLM filter 單 doc（不刪舊）
make filter_test [DOC_ID=]  強制刪舊重跑 LLM filter（預設 44862a...）
make extract_pdf [DOC_ID=]  抽 PDF→markdown（嚴謹模式）
make ocr_pdf [DOC_ID=]   OCR 圖像 PDF
make reconcile_manifest  補 manifest（orphan PDF）
make md5_fix             修 manifest 的 md5 placeholder
make build_chunks [DOC_ID=]  建/重建 chunks（DOC_ID 為 partial update）
make audit_sources       manifest ↔ collector ↔ extracted 對齊報告
make clean_generated     rm -rf generated/
make help                完整 help
```

---

## 常見問題

**Q: build_chunks documents.jsonl 數量 != PDF 數？**
- 修前可能是 manifest 重複 doc_id（已 dedup at `8e31221`）或 build_chunks 漏 orphan（已修 at `cdd3cf0`）；現在 897 PDFs = 897 documents = 897 extracted dirs，完全對齊。
- 重新對齊：`rm -rf generated/kb && make build_chunks`

**Q: 為什麼 `ls -la generated/extracted | wc -l = 900`？**
- `ls -la` 多 3 行（`total N` / `.` / `..`）。真實目錄數請用 `find . -maxdepth 1 -mindepth 1 -type d | wc -l` 或 `ls -d */ | wc -l`。

**Q: filter 後 chunks 的 page_start/page_end 變 None？**
- filter 結果（knowledge.json）沒 `<!-- page:N -->` marker，page tracking 在 filter 階段流失。若需指 PDF 頁碼回查，建議：用 extracted/ chunks 做語義檢索，用 filtered/ chunks 做精煉摘要。

**Q: LLM filter 全 900 doc 要花多久？**
- 約 30M tokens，跑滿 5h window 後需排到下一個窗口（每窗 5 hours）。建議分批，先挑 chunks 過長（>1500 字）或 noise ratio 高的 doc 試。

---

## Pipeline 依賴

- Python 3 標準庫（無第三方 dependency）
- `pdftotext` / `pdfinfo`（poppler）：`brew install poppler`
- `tesseract` + 語言包：`brew install tesseract tesseract-lang`
- `codex` CLI（LLM filter 預設 provider）：`https://github.com/openai/codex` — 用 ChatGPT plan 登入即可
- （可選）`OPENAI_API_KEY` 環境變數（用 OpenAI Responses API 作 filter）
