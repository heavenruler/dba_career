---
doc_id: "52e38072515ecdc8bacde815def89053"
title: "Password Management in MySQL 8: Switching Between Authentication Plugins"
aliases:
  - "Password Management in MySQL 8: Switching Between Authentication Plugins"
url: "https://www.mydbops.com/blog/password-management-in-mysql-8"
source_domain: "www.mydbops.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "MySQL 8.4"
  - "DBA"
  - "password management"
  - "authentication plugin"
  - "caching_sha2_password"
  - "mysql_native_password"
  - "database security"
generated: true
---

# Password Management in MySQL 8: Switching Between Authentication Plugins

> [!info] Provenance
> - doc_id: `52e38072515ecdc8bacde815def89053`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.mydbops.com/blog/password-management-in-mysql-8)
> - PDF: [open local PDF](../../collector/52e38072515ecdc8bacde815def89053.pdf)

## Summary

MySQL 8.4 預設 authentication plugin 改為 caching_sha2_password，文章說明密碼管理功能、caching_sha2_password 的 authentication flow、優缺點、plugin 轉換情境，以及常見資料庫管理與監控工具的相容性。

## Knowledge Outline

- MySQL 8 Password Management Overview — MySQL, password management, authentication
- Password Management Features — MySQL, password policy, account security
- caching_sha2_password Plugin — caching_sha2_password, SHA-256, MySQL authentication
- Authentication Flow — authentication flow, password cache, MySQL
- Key Benefits — security, performance, RSA, SSL
- Managing Authentication Plugin — plugin migration, MySQL, password handling
- Create User With caching_sha2_password — CREATE USER, GRANT, caching_sha2_password
- Convert mysql_native_password To caching_sha2_password — ALTER USER, mysql_native_password, caching_sha2_password
- Convert caching_sha2_password To mysql_native_password — ALTER USER, mysql_native_password, compatibility
- Tool Compatibility — ProxySQL, Percona Toolkit, Orchestrator, PMM, Percona Server, compatibility
- Advantages — SHA-256, brute-force, password cache, RSA
- Disadvantages — compatibility, SSL, RSA, data breach, migration risk
- Summary — MySQL 8, password management, security

## Repository Paths

- PDF: `collector/52e38072515ecdc8bacde815def89053.pdf`
- Extracted: `generated/extracted/52e38072515ecdc8bacde815def89053/full.md`
- Filtered: `generated/filtered/52e38072515ecdc8bacde815def89053/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
