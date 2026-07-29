---
doc_id: "6b159e0502dedddad0a2c78d220d598b"
title: "阿里面试：10WQPS高并发，怎么限流？这份答案，让我当场拿了offer"
aliases:
  - "阿里面试：10WQPS高并发，怎么限流？这份答案，让我当场拿了offer"
url: "https://mp.weixin.qq.com/s/5M8vO5rLpt9uXmxYC4Z8vw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "架构设计"
  - "高并发"
  - "限流"
  - "系统设计面试"
  - "Nginx"
  - "漏桶算法"
  - "令牌桶算法"
  - "滑动窗口"
  - "固定窗口"
  - "Java"
generated: true
---

# 阿里面试：10WQPS高并发，怎么限流？这份答案，让我当场拿了offer

> [!info] Provenance
> - doc_id: `6b159e0502dedddad0a2c78d220d598b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/5M8vO5rLpt9uXmxYC4Z8vw)
> - PDF: [open local PDF](../../collector/6b159e0502dedddad0a2c78d220d598b.pdf)

## Summary

本文主要整理高并发限流的常见算法、适用场景、优缺点，以及 Nginx ngx_http_limit_req_module 的漏桶限流配置与核心逻辑，属于系统设计、架构设计、SRE/DevOps 与面试准备相关内容。

## Knowledge Outline

- 限流的目的 — 限流, 高并发, 系统稳定性
- 限流的思想 — 限流, 系统可用性, 雪崩防护
- 四大限流算法 — 限流算法, 固定窗口, 滑动窗口, 漏桶算法, 令牌桶算法
- 固定窗口原理 — 固定窗口, 计数器限流, 限流算法
- 固定窗口临界问题 — 固定窗口, 突刺现象, 性能风险
- 固定窗口其他问题 — 固定窗口, 突发流量, 限流精度
- 滑动窗口原理 — 滑动窗口, 限流算法, 突刺现象
- 滑动窗口步骤 — 滑动窗口, 限流算法, 动态调整
- 滑动窗口优点 — 滑动窗口, 限流精度, 突发流量
- 滑动窗口缺点 — 滑动窗口, 分布式系统, 时钟同步
- 漏桶算法原理 — 漏桶算法, 限流算法, 流量整形
- 漏桶作用 — 漏桶算法, 削峰, 缓冲
- 漏桶实现步骤 — 漏桶算法, 实现步骤, 限流
- 漏桶适用场景 — 漏桶算法, 适用场景, API网关, Nginx
- 令牌桶原理 — 令牌桶算法, 限流算法, 突发流量
- 令牌桶规则 — 令牌桶算法, 漏桶算法, 突发流量
- 令牌桶实现步骤 — 令牌桶算法, 实现步骤, 限流
- Guava RateLimiter — Guava, RateLimiter, Java, 令牌桶算法
- 令牌桶优缺点 — 令牌桶算法, 优缺点, 时间控制
- Nginx 限流模块 — Nginx, ngx_http_limit_req_module, 漏桶算法, 网关限流
- Nginx 基本限流配置 — Nginx, limit_req_zone, limit_req, 配置
- Nginx 配置说明 — Nginx, limit_req_zone, 配置说明
- Nginx 突发流量 — Nginx, burst, 突发流量
- Nginx 立即拒绝 — Nginx, nodelay, 限流拒绝
- Nginx 自定义状态码 — Nginx, 429, Too Many Requests
- Nginx 不同键限流 — Nginx, 请求路径限流, User-Agent, 配置
- Nginx Header 限流 — Nginx, Header限流, user-id, limit_req_zone
- Nginx 核心逻辑 — Nginx, ngx_http_limit_req_module, 漏桶算法, 源码

## Repository Paths

- PDF: `collector/6b159e0502dedddad0a2c78d220d598b.pdf`
- Extracted: `generated/extracted/6b159e0502dedddad0a2c78d220d598b/full.md`
- Filtered: `generated/filtered/6b159e0502dedddad0a2c78d220d598b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
