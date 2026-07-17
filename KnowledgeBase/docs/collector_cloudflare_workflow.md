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

先從 Cloudflare R2 取得一次遠端 object inventory：

```bash
KB_R2_BUCKET=kb-wn make fetch_collector_inventory
```

再 dry-run 比對；遠端已存在的 key 一律跳過：

```bash
make upload_collector_dry_run
```

正式批次作業會重新取得 inventory、上傳差集，最後再取得一次 inventory：

```bash
KB_R2_BUCKET=kb-wn make upload_collector
```

流程只使用 Cloudflare Wrangler OAuth 與 Cloudflare R2 API，不使用 AWS CLI。`collector/r2_inventory.tsv` 是遠端 object list；`collector/uploaded.tsv` 是本機成功上傳紀錄。判斷規則：

- inventory 有 key 且 size 相同：跳過，不覆寫
- inventory 有 key 但 size 不同：衝突並停止該檔案
- inventory 沒有 key：才執行 remote put

只有明確需要覆寫時才使用：

```bash
KB_R2_BUCKET=<bucket> DRY_RUN=0 FORCE=1 scripts/upload_collector_r2.sh collector/<doc_id>.pdf
```

## 4. 驗證上傳狀態

```bash
make audit_collector_upload
python3 scripts/audit_collector_upload_state.py --json
```

判準以遠端 inventory 為主：

- `remote_missing_count=0`
- `remote_size_mismatch_count=0`
- `bad_inventory_row_count=0`

`missing_upload_state_count` 只代表本機歷史紀錄不完整，不再被解讀為遠端未上傳。`remote_present_untracked_count` 代表遠端存在、size 相同，但本機沒有成功上傳紀錄。

## 5. Commit 範圍

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
