---
doc_id: "c88bc9dc70d233d3bbe555aa91b89b8e"
title: "面试官最爱问：你线上 QPS 是多少？你怎么知道的？"
aliases:
  - "面试官最爱问：你线上 QPS 是多少？你怎么知道的？"
url: "https://mp.weixin.qq.com/s/j6ntmudbsISfYkMKonqUqA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "面试"
  - "QPS"
  - "Prometheus"
  - "Grafana"
  - "Spring Boot"
  - "Kubernetes"
  - "性能调优"
  - "架构设计"
  - "监控"
  - "微服务"
generated: true
---

# 面试官最爱问：你线上 QPS 是多少？你怎么知道的？

> [!info] Provenance
> - doc_id: `c88bc9dc70d233d3bbe555aa91b89b8e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/j6ntmudbsISfYkMKonqUqA)
> - PDF: [open local PDF](../../collector/c88bc9dc70d233d3bbe555aa91b89b8e.pdf)

## Summary

这篇文章围绕 QPS 的基础概念、QPS/TPS/RT 关系、峰值 QPS 估算、Spring Boot + Prometheus + Grafana 的监控接入、以及千万级流量下的扩容与分层优化方案展开，并给出面试回答模板与踩坑提示。

## Knowledge Outline

- QPS 基础与公式 — QPS, TPS, RT, 性能公式, 面试
- 监控接入 — Spring Boot, Prometheus, Actuator, Micrometer, 监控, QPS
- 部署与优化 — Grafana, PromQL, Kubernetes, HPA, 微服务, 限流, 缓存, 分库分表, 弹性伸缩
- 面试回答模板 — 面试, QPS, Prometheus, Grafana, 面试回答, 系统设计, 监控, 优化

## Repository Paths

- PDF: `collector/c88bc9dc70d233d3bbe555aa91b89b8e.pdf`
- Extracted: `generated/extracted/c88bc9dc70d233d3bbe555aa91b89b8e/full.md`
- Filtered: `generated/filtered/c88bc9dc70d233d3bbe555aa91b89b8e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
