# KnowledgeBase Vault

這個 Vault 是 `KnowledgeBase` 的人類知識層，不是原始資料與 RAG 產物的副本。

## 分區

- `00 Inbox/`：尚未歸類的想法。
- `10 Maps/`：MOC、來源目錄與主題入口。
- `20 Concepts/`：概念、方法、原理與永久筆記。
- `30 Runbooks/`：可執行 SOP、命令與回滾程序。
- `40 Cases/`：事故、架構案例與決策紀錄。
- `50 Career/`：面試、履歷、職涯與溝通。
- `90 Sources/`：由 pipeline 產生的來源頁，請勿手動編輯。
- `Templates/`：人工筆記模板。

## 更新來源頁

在 `KnowledgeBase/` 執行：

```bash
make obsidian
make obsidian_check
```

`make obsidian` 只重建 `90 Sources/`、`10 Maps/Source Catalog.md` 與
`10 Maps/Tag Index.md`。人工筆記不會被刪除或覆寫。

來源頁保留 `doc_id`、URL、PDF 路徑、source kind 與 filtered tags。人工筆記引用
來源時，使用來源頁的 wikilink，讓 Obsidian backlinks 保留證據鏈。
