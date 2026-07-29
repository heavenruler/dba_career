---
doc_id: "62f94a5713ff62a9daed28d8d820eb8a"
title: "MySQL 密码防暴力破解插件：Connection Control"
aliases:
  - "MySQL 密码防暴力破解插件：Connection Control"
url: "https://www.modb.pro/db/1957258003443363840"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "数据库安全"
  - "DBA"
  - "Connection Control"
  - "防暴力破解"
  - "参数配置"
  - "源码分析"
generated: true
---

# MySQL 密码防暴力破解插件：Connection Control

> [!info] Provenance
> - doc_id: `62f94a5713ff62a9daed28d8d820eb8a`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1957258003443363840)
> - PDF: [open local PDF](../../collector/62f94a5713ff62a9daed28d8d820eb8a.pdf)

## Summary

本文介绍 MySQL Connection Control 插件的防暴力破解机制、适用场景、插件效果、安装卸载方法、相关参数与状态变量、禁用方式、注意事项，以及基于源码片段说明其触发延迟的实现逻辑。

## Knowledge Outline

- 功能与适用场景 — MySQL, 数据库安全, 防暴力破解
- 插件效果 — MySQL, Connection Control, 验证效果
- 延迟连接状态 — MySQL, SHOW PROCESSLIST, 连接状态
- 安装插件 — MySQL, 插件安装, Connection Control
- 卸载插件 — MySQL, 插件卸载, Connection Control
- 相关参数 — MySQL, 参数配置, Connection Control
- 状态变量 — MySQL, 状态变量, information_schema
- 禁用延迟功能 — MySQL, Connection Control, 禁用
- 注意事项 — MySQL, 数据库安全, 连接数, 风险
- 调用时机 — MySQL, 源码分析, 认证流程
- 认证与连接占用思路 — MySQL, 数据库安全, 账号权限, 连接控制
- 延迟实现逻辑 — MySQL, 源码分析, Connection Control
- 延迟时间与 USERHOST 规则 — MySQL, 延迟算法, USERHOST
- USERHOST 示例 — MySQL, USERHOST, information_schema

## Repository Paths

- PDF: `collector/62f94a5713ff62a9daed28d8d820eb8a.pdf`
- Extracted: `generated/extracted/62f94a5713ff62a9daed28d8d820eb8a/full.md`
- Filtered: `generated/filtered/62f94a5713ff62a9daed28d8d820eb8a/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
