---
doc_id: "d7fe63bdf2283b3983577c28e356c225"
title: "美团面试： ‘异地多活’ 都不用 ， 你们 项目 怎么实现 高可用呢？"
aliases:
  - "美团面试： ‘异地多活’ 都不用 ， 你们 项目 怎么实现 高可用呢？"
url: "https://mp.weixin.qq.com/s/oW-8AhbW5thOsN_upA4DBw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "高可用"
  - "异地多活"
  - "容灾"
  - "架构设计"
  - "单元化架构"
  - "数据库"
  - "数据同步"
  - "饿了么"
  - "SRE"
  - "系统设计面试"
generated: true
---

# 美团面试： ‘异地多活’ 都不用 ， 你们 项目 怎么实现 高可用呢？

> [!info] Provenance
> - doc_id: `d7fe63bdf2283b3983577c28e356c225`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/oW-8AhbW5thOsN_upA4DBw)
> - PDF: [open local PDF](../../collector/d7fe63bdf2283b3983577c28e356c225.pdf)

## Summary

本文围绕高可用架构演进、同城灾备、同城双活、两地三中心、异地多活与单元化架构展开，并以饿了么异地多活实践说明地理围栏分片、流量路由、数据同步、冲突处理、故障切换与基础中间件设计。

## Knowledge Outline

- 高可用定义 — 高可用, 可用性, MTBF, MTTR
- 主从副本与多点部署 — 数据库, 主从复制, 负载均衡, 单点故障
- 同城灾备 — 同城灾备, 机房容灾, 冗余
- 冷备热备对比 — 冷备, 热备, RTO, RPO
- 热备恢复步骤 — 热备, 故障切换, MTTR, 数据库从库
- 同城双活读写分离 — 同城双活, 读写分离, 双主同步, 容灾
- 两地三中心 — 两地三中心, 城市级容灾, 异步热备
- 异地多活网络延迟挑战 — 异地多活, 网络延迟, 跨机房调用
- 延迟数据对比 — 延迟, 性能, 异地多活, 饿了么
- 异地多活服务边界 — 服务边界, 跨机房调用, 单元化
- 单元化架构 — 单元化架构, 业务闭环, 异地多活
- 单元化核心思想 — 路由分片, 多主, 数据同步, 故障切换
- 分片路由原则 — 分片路由, 数据冲突, 异地双活
- 业务类型分片 — 业务分片, 服务隔离, 服务边界
- 用户哈希分片 — 用户分片, 一致性哈希, 路由
- 地理分片 — 地理分片, 区域隔离, LBS
- 关键技术难点 — 数据同步, 冲突处理, 数据归属, Sharding Key
- 全局数据处理 — 全局数据, 强一致, Paxos, Raft, 依赖治理
- 异地多活关键问题 — 异地多活, 区域划分, 数据复制, 故障转移
- 饿了么业务特征 — 饿了么, 业务分析, 地理位置, 实时性
- 饿了么架构原则 — 饿了么, 架构原则, 可用性优先, 数据正确性
- 地理围栏分片 — 地理围栏, Shard, ezone, failover
- 地理围栏常见疑问 — 地理围栏, 用户移动, 用户ID分片, 跨机房调用
- API Router 路由 — API Router, 流量路由, Shard ID, ezone
- 分层路由与 SOA Proxy — 分层路由, SOA Proxy, Sharding Key, 服务路由
- 数据同步机制 — 数据同步, DRC, MySQL, 主键冲突, 冲突解决
- 全局强一致方案 — ZooKeeper, Redis, MQ, Global Zone, 强一致, DAL
- 切换异常保护 — 故障切换, 异常保护, DAL, DRC, 数据正确性
- 业务改造关键点 — 业务改造, 业务可感知, 数据修复, ezone
- 多活基础中间件 — 中间件, API Router, Global Zone Service, SOA Proxy, DRC, DAL
- 中间件职责 — API Router, GZS, SOA Proxy, DRC, DAL, 数据复制

## Repository Paths

- PDF: `collector/d7fe63bdf2283b3983577c28e356c225.pdf`
- Extracted: `generated/extracted/d7fe63bdf2283b3983577c28e356c225/full.md`
- Filtered: `generated/filtered/d7fe63bdf2283b3983577c28e356c225/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
