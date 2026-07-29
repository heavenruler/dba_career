---
doc_id: "ada26a457f24c63b95c3b4cd08ffc1d8"
title: "xtrabackup原理及实施"
aliases:
  - "xtrabackup原理及实施"
url: "https://zhuanlan.zhihu.com/p/435853859"
source_domain: "zhuanlan.zhihu.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "Percona XtraBackup"
  - "InnoDB"
  - "備份恢復"
  - "增量備份"
  - "熱備份"
  - "流備份"
  - "MyISAM"
  - "運維"
generated: true
---

# xtrabackup原理及实施

> [!info] Provenance
> - doc_id: `ada26a457f24c63b95c3b4cd08ffc1d8`
> - source_kind: `llm_filtered`
> - source: [original URL](https://zhuanlan.zhihu.com/p/435853859)
> - PDF: [open local PDF](../../collector/ada26a457f24c63b95c3b4cd08ffc1d8.pdf)

## Summary

這篇文章系統整理了 XtraBackup / innobackupex 的備份與恢復原理，涵蓋 InnoDB 的 redo log 與 LSN、全備與增量備份、prepare / recovery 與 restore 的差異、流備份、部分庫表備份、並行備份，以及一些實務注意事項。

## Knowledge Outline

- 備份原理 — MySQL, Percona XtraBackup, InnoDB, 备份恢复, redo log, LSN, MyISAM
- MyISAM 注意 — MySQL, MyISAM, InnoDB, 主从复制, 备份恢复, 锁表
- 增量备份 — MySQL, Percona XtraBackup, InnoDB, 增量备份, LSN, xtrabackup_logfile, 远程备份
- 恢复与还原 — MySQL, InnoDB, crash recovery, 增量备份, 热备份, 备份恢复
- 流备份与部分恢复 — MySQL, Percona XtraBackup, 流备份, 远程备份, 部分恢复, 表空间导入导出, InnoDB
- 并行与实现细节 — MySQL, Percona XtraBackup, 并行备份, IO限制, 实现细节, InnoDB

## Repository Paths

- PDF: `collector/ada26a457f24c63b95c3b4cd08ffc1d8.pdf`
- Extracted: `generated/extracted/ada26a457f24c63b95c3b4cd08ffc1d8/full.md`
- Filtered: `generated/filtered/ada26a457f24c63b95c3b4cd08ffc1d8/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
