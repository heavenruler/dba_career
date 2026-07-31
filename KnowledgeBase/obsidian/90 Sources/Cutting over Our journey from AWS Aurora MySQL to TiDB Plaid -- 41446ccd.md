---
doc_id: "41446ccd753567640b5543201715fb85"
title: "Cutting over: Our journey from AWS Aurora MySQL to TiDB | Plaid"
knowledge_type: source
status: reviewed
primary_expert: "Solution Architecture"
expert_domains:
  - "Solution Architecture"
  - "DBA"
  - "SRE Platform"
classification_source: generated
source_kind: "llm_filtered"
source_domain: "plaid.com"
url: "https://plaid.com/blog/switching-to-tidb/"
generated: true
---

# Cutting over: Our journey from AWS Aurora MySQL to TiDB | Plaid

> [!info] Provenance
> - doc_id: `41446ccd753567640b5543201715fb85`
> - source_kind: `llm_filtered`
> - original: [來源連結](https://plaid.com/blog/switching-to-tidb/)
> - Review Record: [[41446ccd753567640b5543201715fb85]]
> - PDF: [[Attachments/Sources/41446ccd753567640b5543201715fb85.pdf|Open PDF]]

## 專家建議

- primary_expert: **Solution Architecture**
- expert_domains: Solution Architecture, DBA, SRE Platform
- reason: Architecture migration case with validation and rollback

## Generated Summary

> [!warning] Generated interpretation
> 下列摘要不是來源原文；技術主張請回到 Evidence 與 PDF 核對。

Plaid 分享從 AWS Aurora MySQL 遷移到 TiDB 的動機、技術規模、服務切換流程、驗證與 rollback 策略、動態 runbook 自動化，以及遷移中的成效與教訓。主題涵蓋資料庫平台替換、分散式 SQL、SRE/可靠性、資料一致性驗證、DevOps 自動化與跨團隊溝通。

## Knowledge Outline

- Project Overview
- Motivation
- Technical Landscape
- Why Move Off Aurora MySQL
- Timeline
- Service Transition Phases
- Remove Incompatibilities
- Replicate Data
- Validate
- Switchover
- Acceleration Strategy
- Centralize Work

## Extractive Evidence

### `41446ccd753567640b5543201715fb85:0001`

`doc_id: 41446ccd753567640b5543201715fb85` · `source_kind: llm_filtered`

```text
# 摘要

Plaid 分享從 AWS Aurora MySQL 遷移到 TiDB 的動機、技術規模、服務切換流程、驗證與 rollback 策略、動態 runbook 自動化，以及遷移中的成效與教訓。主題涵蓋資料庫平台替換、分散式 SQL、SRE/可靠性、資料一致性驗證、DevOps 自動化與跨團隊溝通。

# Project Overview

Switching database platforms is one of the most daunting challenges in modern
infrastructure. Database platform replacements demand rigorous planning to
maintain data consistency, ensure uptime, and preserve performance and feature
compatibility. But in January of 2023, we kicked off a “Future of SQL” project to lay the
online relational database foundation for Plaid’s growth over the next 5 to 10 years.
We’ve now transitioned the majority of our services from AWS Aurora MySQL to TiDB
with minimal service disruption and are seeing the benefits from our investment.
```

### `41446ccd753567640b5543201715fb85:0002`

`doc_id: 41446ccd753567640b5543201715fb85` · `source_kind: llm_filtered`

```text
elational database foundation for Plaid’s growth over the next 5 to 10 years.
We’ve now transitioned the majority of our services from AWS Aurora MySQL to TiDB
with minimal service disruption and are seeing the benefits from our investment.

In this post, we share our process for approaching and delivering a project that’s at
the core of Plaid’s reliability and engineering velocity, with the goal of providing a
roadmap for others facing similar challenges in infrastructure and company-wide
replatforming.

Below, we’ll explore our motivation for moving to TiDB, how we transitioned each
service, and how we’ve refined and accelerated our process over time. We hope our
journey can serve as a blueprint for other organizations looking to modernize their
data infrastructure.

# Motivation
```

### `41446ccd753567640b5543201715fb85:0003`

`doc_id: 41446ccd753567640b5543201715fb85` · `source_kind: llm_filtered`

```text
# Motivation

As the founder of the Storage Team at Plaid, I saw the investment we were putting
into Aurora MySQL and the limitations we faced compared to other systems we self-
host. Plaid’s Storage Team provides a scalable and reliable platform for storing online
data at Plaid and focuses on investments in relational, NoSQL, and caching storage
systems.

Idevised the structure for assessing our alternatives along with Joy Zheng, our
Architecture Lead, and our deep technical expert on databases Mingjian Liu, and then
set an ambitious timeline for the team that we would do a quarter of research, a
quarter of prototyping, and aim to complete our service transitions to a new platform
before the Amazon’s MySQL 5.7 deprecation! To ensure the project delivered high
value to the business, we had the design constraint that this project couldn’t last
more than two years company-wide.
```

## Repository Paths

- PDF: `collector/41446ccd753567640b5543201715fb85.pdf`
- Extracted: `generated/extracted/41446ccd753567640b5543201715fb85/full.md`
- Filtered: `generated/filtered/41446ccd753567640b5543201715fb85/knowledge.json`

<!-- Generated source page: do not edit. Use the Review Record or promote a new note. -->
