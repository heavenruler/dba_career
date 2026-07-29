---
doc_id: "92db090625bfc7b86caa1cf54d6814d2"
title: "Terraform — Best Practices. Best practices for using Terraform. | by Ashish Patel | DevOps Mojo | Medium"
aliases:
  - "Terraform — Best Practices. Best practices for using Terraform. | by Ashish Patel | DevOps Mojo | Medium"
url: "https://medium.com/devops-mojo/terraform-best-practices-top-best-practices-for-terraform-configuration-style-formatting-structure-66b8d938f00c"
source_domain: "medium.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Terraform"
  - "Infrastructure as Code"
  - "DevOps"
  - "Cloud Computing"
  - "平台工程"
  - "安全實務"
  - "模組化"
  - "測試"
  - "版本控制"
generated: true
---

# Terraform — Best Practices. Best practices for using Terraform. | by Ashish Patel | DevOps Mojo | Medium

> [!info] Provenance
> - doc_id: `92db090625bfc7b86caa1cf54d6814d2`
> - source_kind: `llm_filtered`
> - source: [original URL](https://medium.com/devops-mojo/terraform-best-practices-top-best-practices-for-terraform-configuration-style-formatting-structure-66b8d938f00c)
> - PDF: [open local PDF](../../collector/92db090625bfc7b86caa1cf54d6814d2.pdf)

## Summary

本文整理 Terraform 使用最佳實務，重點包含檔案與目錄結構、命名與格式慣例、遠端 state 與 secrets 安全、模組設計、版本控制、測試、資源保護、表達式複雜度控制與 CI/CD 中使用 Docker 執行 Terraform。

## Knowledge Outline

- Terraform 概述 — Terraform, IaC, DevOps
- 一致檔案結構 — Terraform, 目錄結構, IaC
- Terraform 設定檔分離 — Terraform, 檔案結構
- 標準模組結構 — Terraform, 模組化, 文件
- 應用程式目錄分離 — Terraform, 目錄結構, 服務拆分
- 環境目錄分離 — Terraform, 環境管理, workspace, 模組化
- 靜態檔案與模板 — Terraform, 模板, 檔案結構
- 程式碼結構建議 — Terraform, HCL, 程式碼風格
- 命名與格式慣例 — Terraform, 命名規範, 可讀性
- 一般命名規範 — Terraform, 命名規範, AWS
- 變數規範 — Terraform, variables, 命名規範
- 輸出規範 — Terraform, outputs, 文件
- 內建格式化 — Terraform, terraform fmt, 格式化
- 安全實務概述 — Terraform, 安全, 雲端
- 使用遠端 State — Terraform, remote state, 安全, state
- Backend State Locking — Terraform, state locking, S3, DynamoDB, Azure Blob Storage
- 不要在 State 存 Secrets — Terraform, secrets, 安全, Vault
- 降低 Blast Radius — Terraform, 風險控制, DevOps
- 持續稽核 — Terraform, 安全稽核, InSpec, Serverspec
- Sensitive Flag Variables — Terraform, sensitive, 安全
- Sensitive 變數範例 — Terraform, HCL, sensitive
- 使用 tfvars — Terraform, tfvars, secrets
- 使用模組 — Terraform, 模組化, 重用
- Shared Modules — Terraform, modules, Terraform Registry
- Tagged Versions — Terraform, 版本管理, modules
- Shared Module Providers — Terraform, providers, backends, modules
- 模組輸出 — Terraform, outputs, modules, dependencies
- Inline Submodules — Terraform, inline modules, 模組化
- Root Module 資源數量 — Terraform, root module, state, 風險控制
- 版本控制 — Terraform, Git, 版本控制, DevOps
- 測試 — Terraform, testing, static analysis, integration testing, DevOps
- 使用最新版 Terraform — Terraform, 版本升級
- 保護 Stateful Resources — Terraform, databases, stateful resources, 安全
- Self Variable — Terraform, self variable
- 限制表達式複雜度 — Terraform, HCL, local values, 可讀性
- 使用 Docker — Terraform, Docker, CI/CD, DevOps

## Repository Paths

- PDF: `collector/92db090625bfc7b86caa1cf54d6814d2.pdf`
- Extracted: `generated/extracted/92db090625bfc7b86caa1cf54d6814d2/full.md`
- Filtered: `generated/filtered/92db090625bfc7b86caa1cf54d6814d2/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
