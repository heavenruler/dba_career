---
doc_id: "28eb86116fab2803d090537fee290113"
title: "TiDB 的高可用实践：一文了解代理组件 TiProxy 的原理与应用"
aliases:
  - "TiDB 的高可用实践：一文了解代理组件 TiProxy 的原理与应用"
url: "https://mp.weixin.qq.com/s/g_ma7dOaWRP8hacsCCJ6fA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "TiProxy"
  - "高可用"
  - "負載均衡"
  - "連接遷移"
  - "故障轉移"
  - "服務發現"
  - "流量捕捉與回放"
  - "SRE"
  - "資料庫"
generated: true
---

# TiDB 的高可用实践：一文了解代理组件 TiProxy 的原理与应用

> [!info] Provenance
> - doc_id: `28eb86116fab2803d090537fee290113`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/g_ma7dOaWRP8hacsCCJ6fA)
> - PDF: [open local PDF](../../collector/28eb86116fab2803d090537fee290113.pdf)

## Summary

本文介绍 TiProxy 作为 TiDB 官方高可用代理组件的定位、主要能力、适用场景，以及安装配置、连接迁移和流量捕捉回放的实践步骤；同时提醒其在高延迟敏感场景下可能带来一定性能损失。

## Knowledge Outline

- TiProxy 概述 — TiDB, TiProxy, 高可用, 負載均衡, 架構
- TiProxy 定位 — TiDB, TiProxy, 負載均衡, 服務發現
- 主要能力 — TiProxy, 连接迁移, 故障转移, 服務發現, 一鍵部署
- 适用场景 — TiProxy, 高可用, 扩缩容, 滚动升级, 性能, 延迟, TPS
- 安装与配置 — TiProxy, TiDB, TiUP, 配置, 证书, graceful-wait-before-shutdown
- 部署与验证 — TiProxy, 部署, 虚拟IP, TiUP, 验证连接
- 连接迁移演示 — TiProxy, 连接迁移, 扩容, 缩容, sysbench, QPS
- 流量捕捉与回放 — TiProxy, 流量捕捉, 流量回放, 测试验证, 容量评估
- 结论 — TiProxy, 负载均衡, 性能测试, 流量回放, 高可用

## Repository Paths

- PDF: `collector/28eb86116fab2803d090537fee290113.pdf`
- Extracted: `generated/extracted/28eb86116fab2803d090537fee290113/full.md`
- Filtered: `generated/filtered/28eb86116fab2803d090537fee290113/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
