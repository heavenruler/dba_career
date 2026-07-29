---
doc_id: "be275f1ba6718211207a8bea411b237f"
title: "验证 MySQL MGR 双机房双活架构可行性"
aliases:
  - "验证 MySQL MGR 双机房双活架构可行性"
url: "https://mp.weixin.qq.com/s/vnO1qXz8DumPgpN4R0WDzA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "MGR"
  - "Group Replication"
  - "雙活架構"
  - "高可用"
  - "容災"
  - "故障切換"
  - "資料一致性"
  - "DBA"
generated: true
---

# 验证 MySQL MGR 双机房双活架构可行性

> [!info] Provenance
> - doc_id: `be275f1ba6718211207a8bea411b237f`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/vnO1qXz8DumPgpN4R0WDzA)
> - PDF: [open local PDF](../../collector/be275f1ba6718211207a8bea411b237f.pdf)

## Summary

本文驗證 MySQL Group Replication 在雙機房雙活場景下的可行性，涵蓋單主/多主模式、單向/雙向異步複製、故障切換、節點恢復與資料一致性校驗，並給出測試結論與自動化測試腳本片段。

## Knowledge Outline

- 背景與問題 — MySQL, MGR, 雙活架構, 高可用
- 設計目標 — 架構驗證, 自動化測試, 故障切換
- 主要功能 — dbdeployer, 複製鏈路, 故障恢復, 資料校驗
- 測試結論 — MySQL Shell, ClusterSet, MySQL Router, GTID, skip_replica_start
- 使用方法 — 命令, 測試腳本, 部署
- 腳本配置 — Python, MGR, 測試配置, 複製通道
- MGR 節點模型 — Python, MySQL CLI, 錯誤日誌
- 初始化測試表 — SQL, 測試資料表, 資料一致性
- 複製通道配置 — MySQL Replication, CHANGE REPLICATION SOURCE, GTID, 異步複製
- 雙向複製配置 — 雙向複製, active-active, 複製通道
- 測試資料寫入與同步校驗 — 資料同步, INSERT, 校驗
- 故障模擬與恢復 — 故障模擬, 節點恢復, START GROUP_REPLICATION, START REPLICA
- 測試場景 — 單向複製, 雙向複製, failover, 測試流程

## Repository Paths

- PDF: `collector/be275f1ba6718211207a8bea411b237f.pdf`
- Extracted: `generated/extracted/be275f1ba6718211207a8bea411b237f/full.md`
- Filtered: `generated/filtered/be275f1ba6718211207a8bea411b237f/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
