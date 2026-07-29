---
doc_id: "0a126f19f7fb8815e609b1bd7ddf1a8e"
title: "MySQL 5.7 半同步复制优缺点、配置及实操记录"
aliases:
  - "MySQL 5.7 半同步复制优缺点、配置及实操记录"
url: "https://www.modb.pro/db/1955920423942631424"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "半同步复制"
  - "主从复制"
  - "数据库配置"
  - "性能调优"
  - "高可用"
generated: true
---

# MySQL 5.7 半同步复制优缺点、配置及实操记录

> [!info] Provenance
> - doc_id: `0a126f19f7fb8815e609b1bd7ddf1a8e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1955920423942631424)
> - PDF: [open local PDF](../../collector/0a126f19f7fb8815e609b1bd7ddf1a8e.pdf)

## Summary

本文整理 MySQL 5.7 半同步复制的核心优点、主要风险、插件与参数配置、注意事项，以及在主从环境中的状态验证示例。

## Knowledge Outline

- 核心优点 — MySQL, 半同步复制, 数据一致性, 高可用
- 主要问题 — MySQL, 半同步复制, 风险, 性能
- 具体配置步骤 — MySQL, 半同步复制, 插件安装, 主从复制
- 注意事项 — MySQL, 半同步复制, 监控, 组复制
- my-master配置文件 — MySQL, 半同步复制, my.cnf, 配置文件
- my-slave配置文件 — MySQL, 半同步复制, my.ini, 配置文件
- my-master验证 — MySQL, 半同步复制, 验证, 状态检查
- my-slave验证 — MySQL, 半同步复制, 验证, 状态检查

## Repository Paths

- PDF: `collector/0a126f19f7fb8815e609b1bd7ddf1a8e.pdf`
- Extracted: `generated/extracted/0a126f19f7fb8815e609b1bd7ddf1a8e/full.md`
- Filtered: `generated/filtered/0a126f19f7fb8815e609b1bd7ddf1a8e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
