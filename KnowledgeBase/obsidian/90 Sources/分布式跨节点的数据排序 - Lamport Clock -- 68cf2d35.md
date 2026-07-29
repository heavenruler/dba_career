---
doc_id: "68cf2d356d223e40052e1a97cbd82a56"
title: "分布式跨节点的数据排序 - Lamport Clock"
aliases:
  - "分布式跨节点的数据排序 - Lamport Clock"
url: "https://mp.weixin.qq.com/s/73rYku-eQbjDNNsj5pbxDA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Lamport Clock"
  - "分布式系統"
  - "因果關係"
  - "偏序"
  - "全序"
  - "MVCC"
  - "一致性前綴讀"
  - "CDC"
  - "資料庫"
  - "架構設計"
generated: true
---

# 分布式跨节点的数据排序 - Lamport Clock

> [!info] Provenance
> - doc_id: `68cf2d356d223e40052e1a97cbd82a56`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/73rYku-eQbjDNNsj5pbxDA)
> - PDF: [open local PDF](../../collector/68cf2d356d223e40052e1a97cbd82a56.pdf)

## Summary

本文講 Lamport Clock 如何用邏輯時間戳捕捉事件的 Happen Before 關係，進而在分布式系統中實現跨節點的因果排序與部分維度的全序；同時也說明它無法辨識並發關係，不能單獨解決所有衝突決策問題。文中用 MVCC、版本鍵、群聊 groupId、CDC 與一致性前綴讀等例子說明其實作與應用邊界。

## Knowledge Outline

- 為什麼需要 Lamport Clock — Lamport Clock, 分布式系统, 时鐘漂移, 因果關係
- Lamport Clock 的核心原理 — Lamport Clock, Happen Before, 因果關係, 並發關係
- 版本鍵與實作 — Lamport Clock, MVCC, Versioned Key, 程式碼, 資料結構
- Client 與 Node 的 clock 遞增 — Lamport Clock, NodeId, LWW, 全序, 并发冲突
- 偏序、groupId 與一致性前綴讀 — Lamport Clock, 偏序, groupId, 一致性前缀讀, CDC
- 應用與限制 — Lamport Clock, 應用場景, 局限性, 總結

## Repository Paths

- PDF: `collector/68cf2d356d223e40052e1a97cbd82a56.pdf`
- Extracted: `generated/extracted/68cf2d356d223e40052e1a97cbd82a56/full.md`
- Filtered: `generated/filtered/68cf2d356d223e40052e1a97cbd82a56/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
