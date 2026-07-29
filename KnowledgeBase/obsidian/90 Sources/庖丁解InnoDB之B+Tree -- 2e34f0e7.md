---
doc_id: "2e34f0e79a7ff1abef3d20cbbd74f695"
title: "庖丁解InnoDB之B+Tree"
aliases:
  - "庖丁解InnoDB之B+Tree"
url: "https://mp.weixin.qq.com/s/LMLOfDOFMs6rAJbcu04lOA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "B+Tree"
  - "資料庫核心"
  - "索引"
  - "並發控制"
  - "故障恢復"
  - "效能"
  - "儲存引擎"
generated: true
---

# 庖丁解InnoDB之B+Tree

> [!info] Provenance
> - doc_id: `2e34f0e79a7ff1abef3d20cbbd74f695`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/LMLOfDOFMs6rAJbcu04lOA)
> - PDF: [open local PDF](../../collector/2e34f0e79a7ff1abef3d20cbbd74f695.pdf)

## Summary

本文介紹 InnoDB 中 B+Tree 的定位、資料組織、查詢與修改流程、節點分裂合併、Latch 並發控制、故障恢復與 IBD 檔案空間管理。

## Knowledge Outline

- 文章範圍 — InnoDB, B+Tree, 資料庫核心
- B+Tree 基礎 — B+Tree, 索引, 磁碟資料庫, 效能
- 分裂與合併 — B+Tree, 節點分裂, 節點合併, 複雜度
- 聚簇索引與二級索引 — InnoDB, 聚簇索引, 二級索引, 回表
- MVCC 與索引 — InnoDB, MVCC, Undo Log, ReadView, 二級索引
- Lock 與 Latch — InnoDB, 並發控制, Lock, Latch, ARIES/KVL, Ghost Record
- 物理故障恢復 — InnoDB, 故障恢復, Redo Log, Undo Log, Mtr
- Record 格式 — InnoDB, Record, 資料格式, MVCC
- Page 組織 — InnoDB, Page, Record Directory, 資料結構
- Page Directory — InnoDB, Page Directory, 二分查找, 頁內搜尋
- B+Tree 定位 — InnoDB, B+Tree, 查詢流程, Buffer Pool, Cursor
- 修改插入刪除 — InnoDB, Update, Insert, Delete, 樂觀操作, 悲觀操作
- 節點分裂實作 — InnoDB, 節點分裂, btr_page_split_and_insert, Auto Increment, 空間利用率
- 節點合併實作 — InnoDB, 節點合併, merge_threshold, 刪除
- Latch 策略 — InnoDB, Latch, 並發控制, Lock Coupling, Blink
- SMO 與樂觀悲觀 — InnoDB, SMO, 並發控制, 樂觀寫入, 悲觀寫入
- Subtree 鎖 — InnoDB, index lock, block lock, sx lock, Subtree
- 文件空間組織 — InnoDB, IBD, Page, Extent, 檔案組織, IO效能
- Extent 與 Segment — InnoDB, Extent, Segment, XDES, Inode Page, 空間管理

## Repository Paths

- PDF: `collector/2e34f0e79a7ff1abef3d20cbbd74f695.pdf`
- Extracted: `generated/extracted/2e34f0e79a7ff1abef3d20cbbd74f695/full.md`
- Filtered: `generated/filtered/2e34f0e79a7ff1abef3d20cbbd74f695/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
