---
doc_id: "8806df80070e0504041848adeb3d0e1b"
title: "主从报错GTID_MODE = ON cannot be set to ANONYMOUS"
aliases:
  - "主从报错GTID_MODE = ON cannot be set to ANONYMOUS"
url: "https://mp.weixin.qq.com/s/wOHpCZ6u8tp_QjZjM3jxAA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "GTID"
  - "主从复制"
  - "故障分析"
  - "relay_log_recovery"
  - "配置"
  - "可用性"
generated: true
---

# 主从报错GTID_MODE = ON cannot be set to ANONYMOUS

> [!info] Provenance
> - doc_id: `8806df80070e0504041848adeb3d0e1b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/wOHpCZ6u8tp_QjZjM3jxAA)
> - PDF: [open local PDF](../../collector/8806df80070e0504041848adeb3d0e1b.pdf)

## Summary

本文分析了在 GTID 已开启但主从仍使用传统 POSITION 的场景下，从库异常重启后 I/O 线程回退到错误位点，导致 relay log 缺失 GTID event，最终触发匿名事务报错的原因，并给出 `relay_log_recovery=ON` 和改用 `GTID AUTO_POSITION` 的规避建议。

## Knowledge Outline

- 错误现象 — MySQL, 主从复制, 故障分析, 报错
- 匿名事务与GTID_MODE — MySQL, GTID, 匿名事务, 复制
- 复制位点存储 — MySQL, 主从复制, POSITION, master_info_repository, sync_master_info
- 异常原因 — MySQL, GTID, relay log, 故障分析, 主从复制
- 复现与规避 — MySQL, 主从复制, 复现, 配置, SQL
- 规避方案 — MySQL, 主从复制, 恢复, relay_log_recovery, MGR

## Repository Paths

- PDF: `collector/8806df80070e0504041848adeb3d0e1b.pdf`
- Extracted: `generated/extracted/8806df80070e0504041848adeb3d0e1b/full.md`
- Filtered: `generated/filtered/8806df80070e0504041848adeb3d0e1b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
