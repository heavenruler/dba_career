---
doc_id: "0b89d4063faab9584c2a02a17afec5d7"
title: "使用 Blue-Green Deploy 把 Mysql 5.7 升級到 8.0 | by Justin Hollly | Medium"
aliases:
  - "使用 Blue-Green Deploy 把 Mysql 5.7 升級到 8.0 | by Justin Hollly | Medium"
url: "https://justinhollly.medium.com/%E4%BD%BF%E7%94%A8-blue-green-deploy-%E6%8A%8A-mysql-5-7-%E5%8D%87%E7%B4%9A%E5%88%B0-8-0-4272eacc7ffc"
source_domain: "justinhollly.medium.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "AWS RDS"
  - "Blue-Green Deployment"
  - "資料庫升級"
  - "整合測試"
  - "SRE"
  - "DevOps"
  - "職場經驗"
generated: true
---

# 使用 Blue-Green Deploy 把 Mysql 5.7 升級到 8.0 | by Justin Hollly | Medium

> [!info] Provenance
> - doc_id: `0b89d4063faab9584c2a02a17afec5d7`
> - source_kind: `llm_filtered`
> - source: [original URL](https://justinhollly.medium.com/%E4%BD%BF%E7%94%A8-blue-green-deploy-%E6%8A%8A-mysql-5-7-%E5%8D%87%E7%B4%9A%E5%88%B0-8-0-4272eacc7ffc)
> - PDF: [open local PDF](../../collector/0b89d4063faab9584c2a02a17afec5d7.pdf)

## Summary

這篇文章分享使用 AWS RDS Blue-Green Deployment 將 MySQL 5.7 升級到 8.0 的實作經驗，包含升級動機、藍綠部署流程、事前檢查項目、整合測試策略、寫入測試環境的 workaround、切換失敗的資料衝突案例，以及最後的反省。

## Knowledge Outline

- 升級動機 — MySQL, AWS RDS, Blue-Green Deployment, 資料庫升級
- 官方流程 — AWS RDS, Blue-Green Deployment, MySQL, 資料庫升級, SRE
- 風險評估 — MySQL, Sequelize, 相容性, charset, collation, storage engine
- 升級與測試 — MySQL, AWS RDS, 整合測試, Postman, IaC, 資料衝突, Blue-Green Deployment
- 反省 — MySQL, 部署策略, GitHub, 資料庫升級, ORM

## Repository Paths

- PDF: `collector/0b89d4063faab9584c2a02a17afec5d7.pdf`
- Extracted: `generated/extracted/0b89d4063faab9584c2a02a17afec5d7/full.md`
- Filtered: `generated/filtered/0b89d4063faab9584c2a02a17afec5d7/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
