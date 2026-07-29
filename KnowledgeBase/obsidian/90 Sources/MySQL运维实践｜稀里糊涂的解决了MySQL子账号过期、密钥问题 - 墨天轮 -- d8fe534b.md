---
doc_id: "d8fe534bcb7c4945ecc285d3f14d044e"
title: "MySQL运维实践｜稀里糊涂的解决了MySQL子账号过期、密钥问题 - 墨天轮"
aliases:
  - "MySQL运维实践｜稀里糊涂的解决了MySQL子账号过期、密钥问题 - 墨天轮"
url: "https://www.modb.pro/db/1881545691021979648"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "运维实践"
  - "故障排查"
  - "JDBC"
  - "Nacos"
  - "账号管理"
  - "权限管理"
generated: true
---

# MySQL运维实践｜稀里糊涂的解决了MySQL子账号过期、密钥问题 - 墨天轮

> [!info] Provenance
> - doc_id: `d8fe534bcb7c4945ecc285d3f14d044e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1881545691021979648)
> - PDF: [open local PDF](../../collector/d8fe534bcb7c4945ecc285d3f14d044e.pdf)

## Summary

本文记录一次 nacos 启动失败排查，涉及 MySQL JDBC Public Key Retrieval 配置、业务账号授权查询、mysql.user 中密码过期相关字段检查，以及通过 alter user 修改账号密码后恢复服务。

## Knowledge Outline

- 故障现象 — Nacos, MySQL, JDBC, 故障日志
- 错误信息提取 — 错误分析, MySQL, Nacos
- 排查思路 — 故障排查, 运维经验
- Public Key Retrieval 原因与配置 — MySQL 8.0, JDBC, Public Key Retrieval, Nacos
- 授权查询 — MySQL, 授权, show grants
- 子账号过期查询 — MySQL, 账号管理, 密码过期, mysql.user
- mysql.user 字段 — MySQL, mysql.user, 账号管理
- 修改密码 — MySQL, alter user, flush privileges, Nacos
- 总结 — 故障复盘, 运维经验

## Repository Paths

- PDF: `collector/d8fe534bcb7c4945ecc285d3f14d044e.pdf`
- Extracted: `generated/extracted/d8fe534bcb7c4945ecc285d3f14d044e/full.md`
- Filtered: `generated/filtered/d8fe534bcb7c4945ecc285d3f14d044e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
