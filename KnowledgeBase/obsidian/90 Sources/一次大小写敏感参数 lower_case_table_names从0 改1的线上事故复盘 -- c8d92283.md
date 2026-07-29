---
doc_id: "c8d92283c776a448e787474ab2df7c00"
title: "一次大小写敏感参数 lower_case_table_names从0 改1的线上事故复盘"
aliases:
  - "一次大小写敏感参数 lower_case_table_names从0 改1的线上事故复盘"
url: "https://mp.weixin.qq.com/s/1afZy_37kYP2q-dI70ygQg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "事故复盘"
  - "lower_case_table_names"
  - "数据库运维"
  - "线上故障"
  - "备份恢复"
  - "MySQL 8.0"
generated: true
---

# 一次大小写敏感参数 lower_case_table_names从0 改1的线上事故复盘

> [!info] Provenance
> - doc_id: `c8d92283c776a448e787474ab2df7c00`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/1afZy_37kYP2q-dI70ygQg)
> - PDF: [open local PDF](../../collector/c8d92283c776a448e787474ab2df7c00.pdf)

## Summary

这篇文章围绕 MySQL 的 `lower_case_table_names` 参数变更事故展开，核心价值在于说明不同环境大小写策略不一致会导致线上表名解析失败，以及直接从 0 改 1 可能把现有实例弄到不可用。正文给出了安全迁移的完整思路：先恢复参数、做逻辑与物理备份、重建实例、在正确参数下导入数据并验证。最后补充了 MySQL 8.0.21 起对该参数的限制和部署时的最佳实践。

## Knowledge Outline

- 环境差异 — MySQL, 数据库运维, lower_case_table_names, 环境配置
- 报错现象 — MySQL, 线上故障, 大小写敏感, 报错
- 误操作扩大故障 — MySQL, 事故复盘, 错误操作, 风险
- 安全修复流程 — MySQL, 恢复流程, 备份, 重建导入, 验证
- 8.0限制与结论 — MySQL 8.0, 限制, 最佳实践, 总结

## Repository Paths

- PDF: `collector/c8d92283c776a448e787474ab2df7c00.pdf`
- Extracted: `generated/extracted/c8d92283c776a448e787474ab2df7c00/full.md`
- Filtered: `generated/filtered/c8d92283c776a448e787474ab2df7c00/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
