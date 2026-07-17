# Collector Cloudflare Workflow

目標：新增 PDF 時先隔離，再入庫、重建 KB、上傳 Cloudflare R2。`collector/*.pdf`、`collector/*.md`、`collector/*.tsv` 都不 commit。

## 0. 現況

- `collector/*.pdf`: 897
- `generated/kb/documents.jsonl`: 897
- `generated/kb/chunks.jsonl`: 8772
- `collector/.wrangler/`: 本機 cache，已忽略

## 1. 隔離新檔案

```bash
BATCH=collector/imported/$(date +%Y%m%d-%H%M%S)
mkdir -p "$BATCH"
mv ~/Downloads/FireShot/*.pdf "$BATCH"/
```

檢查後再入庫：

```bash
find collector/imported -maxdepth 2 -type f -name '*.pdf'
mv collector/imported/<batch>/*.pdf collector/
```

## 2. 新增與重建

```bash
make sync
python3 -m json.tool < generated/kb/source_audit_summary.json
wc -l generated/kb/documents.jsonl generated/kb/chunks.jsonl
```

若 FireShot 沒寫 URL metadata，手動補 `output_with_md5.txt`：

```text
title
url
<md5>
----
```

## 3. 上傳 Cloudflare R2

先 dry-run：

```bash
scripts/upload_collector_r2.sh collector/*.pdf
```

正式上傳：

```bash
KB_R2_BUCKET=<bucket> DRY_RUN=0 scripts/upload_collector_r2.sh collector/*.pdf
```

只上傳新 batch：

```bash
KB_R2_BUCKET=<bucket> DRY_RUN=0 scripts/upload_collector_r2.sh collector/<doc_id-1>.pdf collector/<doc_id-2>.pdf
```

上傳成功會寫入 `collector/uploaded.tsv`，下次依 `sha256` 跳過。需要重傳時：

```bash
KB_R2_BUCKET=<bucket> DRY_RUN=0 FORCE=1 scripts/upload_collector_r2.sh collector/<doc_id>.pdf
```

## 4. Commit 範圍

只 commit:

- `output_with_md5.txt`
- `README.md` / docs / scripts 的流程變更
- 需要保留的 `kb_agent/indexes/*.jsonl`

不要 commit:

- `collector/*.pdf`
- `collector/*.md`
- `collector/*.tsv`
- `generated/`
- `.todo.state`
