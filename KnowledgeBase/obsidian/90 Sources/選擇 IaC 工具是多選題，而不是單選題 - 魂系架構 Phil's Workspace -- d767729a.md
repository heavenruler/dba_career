---
doc_id: "d767729aa8c1ba344a005fd2c957e3a0"
title: "選擇 IaC 工具是多選題，而不是單選題 - 魂系架構 Phil's Workspace"
aliases:
  - "選擇 IaC 工具是多選題，而不是單選題 - 魂系架構 Phil's Workspace"
url: "https://blog.pichuang.com.tw/20230301-iac-personal-experiences.html"
source_domain: "blog.pichuang.com.tw"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "IaC"
  - "Terraform"
  - "Ansible"
  - "Azure"
  - "Kubernetes"
  - "VMware vSphere"
  - "Linux"
  - "Windows"
  - "平台工程"
  - "DevOps"
  - "雲端"
  - "基礎架構自動化"
generated: true
---

# 選擇 IaC 工具是多選題，而不是單選題 - 魂系架構 Phil's Workspace

> [!info] Provenance
> - doc_id: `d767729aa8c1ba344a005fd2c957e3a0`
> - source_kind: `llm_filtered`
> - source: [original URL](https://blog.pichuang.com.tw/20230301-iac-personal-experiences.html)
> - PDF: [open local PDF](../../collector/d767729aa8c1ba344a005fd2c957e3a0.pdf)

## Summary

本文討論 Infrastructure as Code 工具選擇應依平台、階段與管理目標混用，而非單選。重點涵蓋 Declarative / Imperative 差異、Azure / VMware vSphere / Kubernetes / Linux / Windows 的 IaC 工具取捨，以及 Terraform、Ansible、Azure CLI、Shell Script 在平台部署與平台管理中的分工。

## Knowledge Outline

- IaC 工具選擇觀點 — IaC, 工具選型, DevOps
- Declarative 與 Imperative — Declarative, Imperative, Kubernetes, IaC
- Private ARO 範例背景 — Azure, Azure Red Hat OpenShift, IaC
- 平台與工具組合 — IaC, Ansible, Terraform, Azure, VMware, Kubernetes, Linux, Windows
- Azure IaC 對策 — Azure, Azure Resource Manager, Terraform, Ansible, Azure CLI
- Azure 平台部署階段 — Azure, Terraform, Azure CLI, Ansible, 平台部署
- Azure 工具混用 — Azure, Ansible, Azure CLI, Azure.Azcollection, 工具選型
- Azure 平台管理階段 — Azure, Ansible, Terraform, 平台管理, Agentless
- VMware vSphere IaC — VMware vSphere, Ansible, Terraform, IaC
- Kubernetes IaC 對策 — Kubernetes, kubectl, helm, Ansible, 平台管理
- Kubernetes 外部服務管理 — Kubernetes, Cluster API, 平台工程, 架構設計
- Kubernetes 解決方案對照 — Kubernetes, OpenShift, Azure, VMware, Terraform, Ansible
- OpenShift Day 2 Operations — OpenShift, Day 2 Operations, Ansible, Service Mesh, Etcd
- Linux IaC 對策 — Linux, Ansible, Shell Script, CLI, Terraform
- Windows IaC 對策 — Windows, Ansible, PowerShell, WinRM
- Windows WinRM 設定 — Windows, WinRM, PowerShell, Ansible, Terraform
- TLDR — Terraform, Ansible, GitHub Copilot, ChatGPT
- 新服務研究流程 — Shell Script, Ansible, CLI, 學習方法
- Ansible 與 Shell Script 分工 — Ansible, Shell Script, JSON, YAML
- Terraform 與 Ansible 分工 — Terraform, Ansible, Azure, AKS, 資源相依性
- 單一 IaC 選擇 — Ansible, Agentless, IaC
- Azure 工具選擇順序 — Azure, Terraform, Azure CLI, Ansible, REST API
- Docker Compose 與 IaC — docker-compose, IaC, 版本控制
- AI 輔助撰寫 IaC — GitHub Copilot, ChatGPT, Terraform, Ansible, Shell Script
- Agentless 偏好 — Ansible, Puppet, Saltstack, Chef, Agentless

## Repository Paths

- PDF: `collector/d767729aa8c1ba344a005fd2c957e3a0.pdf`
- Extracted: `generated/extracted/d767729aa8c1ba344a005fd2c957e3a0/full.md`
- Filtered: `generated/filtered/d767729aa8c1ba344a005fd2c957e3a0/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
