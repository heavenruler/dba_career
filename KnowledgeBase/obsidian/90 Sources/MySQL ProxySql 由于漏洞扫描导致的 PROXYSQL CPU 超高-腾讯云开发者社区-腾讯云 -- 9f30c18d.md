---
doc_id: "9f30c18db7a9308c4d4fc06a8b4e45c1"
title: "MySQL ProxySql 由于漏洞扫描导致的 PROXYSQL CPU 超高-腾讯云开发者社区-腾讯云"
aliases:
  - "MySQL ProxySql 由于漏洞扫描导致的 PROXYSQL CPU 超高-腾讯云开发者社区-腾讯云"
url: "https://cloud.tencent.com/developer/article/1706112"
source_domain: "cloud.tencent.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "ProxySQL"
  - "MySQL"
  - "漏洞扫描"
  - "CPU高负载"
  - "故障分析"
  - "性能调优"
  - "排障"
  - "SRE"
generated: true
---

# MySQL ProxySql 由于漏洞扫描导致的 PROXYSQL CPU 超高-腾讯云开发者社区-腾讯云

> [!info] Provenance
> - doc_id: `9f30c18db7a9308c4d4fc06a8b4e45c1`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cloud.tencent.com/developer/article/1706112)
> - PDF: [open local PDF](../../collector/9f30c18db7a9308c4d4fc06a8b4e45c1.pdf)

## Summary

文章分析了 ProxySQL 在漏洞扫描期间 CPU 突然飙高的原因，指出扫描会触发 X11 端口上的敏感词探测并导致死循环；同时强调不要盲目加大 mysql-threads，而应先判断 CPU 高峰是业务峰值、BUG 还是规则过多引起。

## Knowledge Outline

- 故障现象 — ProxySQL, MySQL, CPU高负载, 故障分析, 压测
- 漏洞扫描触发 — ProxySQL, 漏洞扫描, MySQL, password, 故障分析
- 解决与排查 — ProxySQL, mysql-threads, 性能调优, CPU, 排障, SRE

## Repository Paths

- PDF: `collector/9f30c18db7a9308c4d4fc06a8b4e45c1.pdf`
- Extracted: `generated/extracted/9f30c18db7a9308c4d4fc06a8b4e45c1/full.md`
- Filtered: `generated/filtered/9f30c18db7a9308c4d4fc06a8b4e45c1/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
