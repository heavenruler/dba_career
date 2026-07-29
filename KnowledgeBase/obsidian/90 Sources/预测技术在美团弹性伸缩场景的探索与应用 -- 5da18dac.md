---
doc_id: "5da18daca984cbdc2c24f7078f1716b5"
title: "预测技术在美团弹性伸缩场景的探索与应用"
aliases:
  - "预测技术在美团弹性伸缩场景的探索与应用"
url: "https://mp.weixin.qq.com/s/7dwa3S2ziUed59O_idJq_A"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "SRE"
  - "弹性伸缩"
  - "负载预测"
  - "QoS"
  - "可观测性"
  - "性能模型"
  - "机器学习"
  - "云平台"
generated: true
---

# 预测技术在美团弹性伸缩场景的探索与应用

> [!info] Provenance
> - doc_id: `5da18daca984cbdc2c24f7078f1716b5`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/7dwa3S2ziUed59O_idJq_A)
> - PDF: [open local PDF](../../collector/5da18daca984cbdc2c24f7078f1716b5.pdf)

## Summary

本文围绕企业大规模 Web 服务的弹性伸缩，分析了负载预测与 QoS 保障的难点，提出 PASS 系统，采用在线/离线模型集成的 ELPA 预测框架、基于历史日志的性能模型，以及排队论兜底的 Hybrid Auto-scaling 方案，并在美团 225 个应用上验证了端到端效果。

## Knowledge Outline

- 背景与问题 — 弹性伸缩, QoS, 负载预测, 排队论, 强化学习
- 预测实验发现 — 预测, 时序数据, 在线预测, 离线预测, QoS, 负载波动
- 弹性伸缩方法分析 — 弹性伸缩, 阈值法, 目标追踪, 排队论, 强化学习, 尾延迟, QoS
- PASS 架构 — PASS, 弹性伸缩, 预测系统, QPS, QoS, 性能模型
- ELPA 与性能模型 — ELPA, 在线模型, 离线模型, 性能模型, 日志分析, 振幅校准, 研究方法
- 兜底策略与评估 — 兜底策略, 排队论, 端到端评估, 实验结果, QoS, 尾延迟, 容量规划
- 经验总结 — 经验总结, 算法选型, 落地性, 时序预测, 工程实践

## Repository Paths

- PDF: `collector/5da18daca984cbdc2c24f7078f1716b5.pdf`
- Extracted: `generated/extracted/5da18daca984cbdc2c24f7078f1716b5/full.md`
- Filtered: `generated/filtered/5da18daca984cbdc2c24f7078f1716b5/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
