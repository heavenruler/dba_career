---
doc_id: "101850f77b5ef2dedab91a52e2ed7742"
title: "腾讯音乐：说说Redis脑裂问题？Redis 脑裂问题是指，在 Redis 哨兵模式或集群模式中，由于网络原因，导致主节 - 掘金"
aliases:
  - "腾讯音乐：说说Redis脑裂问题？Redis 脑裂问题是指，在 Redis 哨兵模式或集群模式中，由于网络原因，导致主节 - 掘金"
url: "https://juejin.cn/post/7358670107901886501"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "数据库"
  - "SRE"
  - "故障切换"
  - "数据丢失"
  - "面试"
generated: true
---

# 腾讯音乐：说说Redis脑裂问题？Redis 脑裂问题是指，在 Redis 哨兵模式或集群模式中，由于网络原因，导致主节 - 掘金

> [!info] Provenance
> - doc_id: `101850f77b5ef2dedab91a52e2ed7742`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7358670107901886501)
> - PDF: [open local PDF](../../collector/101850f77b5ef2dedab91a52e2ed7742.pdf)

## Summary

本文解释了 Redis 哨兵模式或集群模式中的脑裂现象：主节点与哨兵、从节点失去通信后，哨兵误判主节点宕机并选出新主节点，导致集群中出现两个主节点。文章进一步说明了旧 Master 在恢复后转为 Slave 时重新同步数据的过程，以及在此过程中原客户端写入可能丢失的原因，并给出通过 min-slaves-to-write 和 min-slaves-max-lag 限制写入来降低数据丢失风险的方法。

## Knowledge Outline

- 脑裂定义 — Redis, 数据库, 故障切换
- 数据丢失 — Redis, 数据丢失, 故障分析
- 同步过程 — Redis, 数据库, RDB, 数据丢失
- 解决方法 — Redis, 数据库, 配置, 高可用, 数据保护
- 课后思考 — Redis, Zookeeper, 架构设计, 思考题

## Repository Paths

- PDF: `collector/101850f77b5ef2dedab91a52e2ed7742.pdf`
- Extracted: `generated/extracted/101850f77b5ef2dedab91a52e2ed7742/full.md`
- Filtered: `generated/filtered/101850f77b5ef2dedab91a52e2ed7742/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
