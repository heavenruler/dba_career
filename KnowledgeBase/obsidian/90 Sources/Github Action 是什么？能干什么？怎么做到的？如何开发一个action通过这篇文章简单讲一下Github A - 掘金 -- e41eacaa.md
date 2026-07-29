---
doc_id: "e41eacaaad9129ff0d437bf1ff5abdbe"
title: "Github Action 是什么？能干什么？怎么做到的？如何开发一个action通过这篇文章简单讲一下Github A - 掘金"
aliases:
  - "Github Action 是什么？能干什么？怎么做到的？如何开发一个action通过这篇文章简单讲一下Github A - 掘金"
url: "https://juejin.cn/post/7348653890587557925"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "GitHub Actions"
  - "CI/CD"
  - "DevOps"
  - "自动化"
  - "Docker"
  - "Puppeteer"
  - "JavaScript"
  - "工作流"
generated: true
---

# Github Action 是什么？能干什么？怎么做到的？如何开发一个action通过这篇文章简单讲一下Github A - 掘金

> [!info] Provenance
> - doc_id: `e41eacaaad9129ff0d437bf1ff5abdbe`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7348653890587557925)
> - PDF: [open local PDF](../../collector/e41eacaaad9129ff0d437bf1ff5abdbe.pdf)

## Summary

本文介绍 GitHub Action 的定义、常见 CI/CD 自动化场景、自定义 action 开发方式、workflow 事件配置、Puppeteer 在自动化与性能诊断中的能力，并给出 Docker 镜像构建与远程部署的 GitHub Actions 配置示例。

## Knowledge Outline

- GitHub Action 是什么 — GitHub Actions, CI/CD, 自动化
- 可自动化的发布工作 — npm, CI/CD, secret, 自动发包
- Bot 与通知场景 — webhook, bot, secret, 自动化通知
- CI 检查与单元测试 — CI, lint, 单元测试, 代码质量
- 组织级数据统计 — GitHub Actions, 数据统计, JavaScript, 组织管理
- 签到助手与重复工作 — 自动化, 重复工作, 工具开发
- PR 自动处理 — PR, label, GitHub Actions, 代码审查
- 定时任务配置 — GitHub Actions, YAML, schedule, cron
- 监听 PR 事件 — GitHub Actions, YAML, pull_request_target
- 监听 Push 事件 — GitHub Actions, YAML, push
- 自定义 Action Workflow 示例 — GitHub Actions, YAML, action, workflow
- Workflow 配置说明 — GitHub Actions, YAML, with, 版本管理, action.yml
- Action 核心代码 — JavaScript, GitHub Actions, @actions/core, @actions/github
- Action 发布方式 — @vercel/ncc, Docker, GitHub Actions, 发布
- Puppeteer 能力总结 — Puppeteer, Chrome Headless, 自动化测试, 性能分析, SSR
- github-script 开发方式 — actions/github-script, JavaScript, YAML, 自动化通知
- GitLab CI 回顾 — GitLab CI, GitHub Actions, tag, CI/CD
- CI 配置安全与迁移思考 — GitLab CI, GitHub Actions, secret, 安全, CI/CD
- 自动构建镜像流程 — GitHub Actions, Docker, Docker Hub, 自动部署
- Docker 镜像构建与推送 — GitHub Actions, Docker, Docker Hub, YAML, CI/CD
- Docker 自动部署 — GitHub Actions, Docker, docker-compose, SSH, 自动部署
- 团队自动化工具目标 — CI, GitHub Actions, 团队工具, 自动化
- 参考场景摘录 — GitHub Actions, vitest, CI, PR, IoT

## Repository Paths

- PDF: `collector/e41eacaaad9129ff0d437bf1ff5abdbe.pdf`
- Extracted: `generated/extracted/e41eacaaad9129ff0d437bf1ff5abdbe/full.md`
- Filtered: `generated/filtered/e41eacaaad9129ff0d437bf1ff5abdbe/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
