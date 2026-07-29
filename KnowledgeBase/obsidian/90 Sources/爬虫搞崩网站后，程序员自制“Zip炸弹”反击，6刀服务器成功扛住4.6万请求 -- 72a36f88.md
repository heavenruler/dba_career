---
doc_id: "72a36f88fa5f3dd55625c60c045a0f3c"
title: "爬虫搞崩网站后，程序员自制“Zip炸弹”反击，6刀服务器成功扛住4.6万请求"
aliases:
  - "爬虫搞崩网站后，程序员自制“Zip炸弹”反击，6刀服务器成功扛住4.6万请求"
url: "https://mp.weixin.qq.com/s/sZonRHd9SQku8n6zH5hmmQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "SRE"
  - "安全"
  - "爬虫"
  - "事故覆盘"
  - "效能调优"
generated: true
---

# 爬虫搞崩网站后，程序员自制“Zip炸弹”反击，6刀服务器成功扛住4.6万请求

> [!info] Provenance
> - doc_id: `72a36f88fa5f3dd55625c60c045a0f3c`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/sZonRHd9SQku8n6zH5hmmQ)
> - PDF: [open local PDF](../../collector/72a36f88fa5f3dd55625c60c045a0f3c.pdf)

## Summary

本文記錄作者在低成本小型伺服器上承受 Hacker News 流量洪峰的實戰經驗，包含伺服器配置、流量時間線、快取與資料庫壓力處理，以及用 zip bomb 反制惡意爬蟲的做法與限制。

## Knowledge Outline

- 背景與死亡之擁 — SRE, 事故覆盘, 流量洪峰
- 服务器配置與時間線 — SRE, 性能调优, 缓存, MySQL, 流量
- zip bomb 原理 — 安全, 爬虫, 压缩, HTTP
- 反擊流程與程式碼 — 安全, 爬虫, 中介軟體, 程式碼
- 限制與結論 — 安全, 爬虫, 风控, 限制

## Repository Paths

- PDF: `collector/72a36f88fa5f3dd55625c60c045a0f3c.pdf`
- Extracted: `generated/extracted/72a36f88fa5f3dd55625c60c045a0f3c/full.md`
- Filtered: `generated/filtered/72a36f88fa5f3dd55625c60c045a0f3c/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
