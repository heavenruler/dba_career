---
doc_id: "d394fdc6ce7ee33faaf1410ed7239637"
title: "MyBatis动态SQL中的\"引号陷阱\"：一个让排序失效的隐蔽Bug"
aliases:
  - "MyBatis动态SQL中的\"引号陷阱\"：一个让排序失效的隐蔽Bug"
url: "https://mp.weixin.qq.com/s/xjg57MLbTmfGpv-ytqt2JQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MyBatis"
  - "动态SQL"
  - "OGNL"
  - "Java"
  - "SQL"
  - "故障排查"
  - "防御性编程"
generated: true
---

# MyBatis动态SQL中的"引号陷阱"：一个让排序失效的隐蔽Bug

> [!info] Provenance
> - doc_id: `d394fdc6ce7ee33faaf1410ed7239637`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/xjg57MLbTmfGpv-ytqt2JQ)
> - PDF: [open local PDF](../../collector/d394fdc6ce7ee33faaf1410ed7239637.pdf)

## Summary

文章说明了 MyBatis 动态 SQL 中引号嵌套会改变 OGNL 解析结果，进而导致字符串与字符比较失效、排序条件部分生效的问题，并给出反转引号、统一传参类型、equals 比较、测试与日志排查等做法。

## Knowledge Outline

- 现象 — MyBatis, 动态SQL, 故障排查
- 引号解析 — MyBatis, OGNL, 字符串, 字符, Java
- 修复方案 — MyBatis, 动态SQL, 修复, SQL日志, 正则
- 防御实践 — MyBatis, 防御性编程, 测试, 日志监控, SQL
- 结语 — MyBatis, 动态SQL, 排查经验, 认知偏差

## Repository Paths

- PDF: `collector/d394fdc6ce7ee33faaf1410ed7239637.pdf`
- Extracted: `generated/extracted/d394fdc6ce7ee33faaf1410ed7239637/full.md`
- Filtered: `generated/filtered/d394fdc6ce7ee33faaf1410ed7239637/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
