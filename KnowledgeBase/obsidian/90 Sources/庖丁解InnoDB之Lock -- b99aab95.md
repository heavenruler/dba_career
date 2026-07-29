---
doc_id: "b99aab95e87290f8dd024f1f1f0c67ce"
title: "庖丁解InnoDB之Lock"
aliases:
  - "庖丁解InnoDB之Lock"
url: "http://mysql.taobao.org/monthly/2025/10/02/"
source_domain: "mysql.taobao.org"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "数据库内核"
  - "Lock"
  - "MVCC"
  - "事务隔离"
  - "并发控制"
  - "死锁检测"
  - "性能优化"
generated: true
---

# 庖丁解InnoDB之Lock

> [!info] Provenance
> - doc_id: `b99aab95e87290f8dd024f1f1f0c67ce`
> - source_kind: `llm_filtered`
> - source: [original URL](http://mysql.taobao.org/monthly/2025/10/02/)
> - PDF: [open local PDF](../../collector/b99aab95e87290f8dd024f1f1f0c67ce.pdf)

## Summary

本文介绍 MySQL InnoDB 的隔离级别、Lock + MVCC 并发控制、Select/Update/Delete/Insert 加锁过程、锁信息维护、锁等待与死锁检测、锁释放唤醒、隐式锁、故障恢复及物理层修改对 Lock 的影响。

## Knowledge Outline

- 隔离性與並發控制 — 事务隔离, 并发控制, InnoDB
- Lock + MVCC — MVCC, ReadView, Snapshot Read, Lock Read
- 混用快照讀與加鎖讀 — SQL, MVCC, 一致性
- 加鎖讀示例 — SQL, Lock Read
- 隔離級別差異 — Read Committed, Repeatable Read, Serializable, MVCC
- InnoDB Lock 類型 — Record Lock, Gap Lock, Next Key Lock
- Select Update Delete 加鎖規則 — row_search_mvcc, 加锁规则
- 合適的鎖 — X_LOCK, S_LOCK, Read Committed, Repeatable Read
- 掃描到的記錄 — 索引, 执行计划, Delete Mark, B+Tree
- 縮小加鎖範圍 — 锁优化, 并发性能, Next Key Lock
- 唯一二級索引檢查 — 唯一索引, Duplicate Key, Delete Mark, 二级索引
- RC 下唯一性鎖擴大 — Read Committed, Next Key Lock, 唯一性, 死锁
- Insert Instant Locking — Insert, LOCK_INSERT_INTENTION, Implicit Lock, Latch
- Lock 信息維護 — lock_t, trx_t, lock_sys_t, rec_hash
- Lock 申請與等待 — lock_rec_lock, Fast Path, Slow Path, 锁等待
- 鎖模式兼容 — LOCK_S, LOCK_X, 兼容矩阵
- 鎖類型兼容 — Next Key Lock, Gap Lock, LOCK_INSERT_INTENTION, 兼容矩阵
- 死鎖檢測 — 死锁, innodb_lock_wait_timeout, 锁等待
- 8.0.18 死鎖檢測改造 — MySQL 8.0.18, 死锁检测, innodb_deadlock_detect
- Lock 釋放與喚醒 — lock_grant, FCFS, CATS, 锁调度
- 隱式鎖 — 隐式锁, Trx ID, lock_rec_convert_impl_to_expl
- 故障恢復中的隱式鎖 — 故障恢复, Redo Log, Undo Log, 隐式锁
- 物理層修改 — 物理层, Heap No, rec_hash, Lock Sys Mutex
- 總結 — 总结, InnoDB Lock

## Repository Paths

- PDF: `collector/b99aab95e87290f8dd024f1f1f0c67ce.pdf`
- Extracted: `generated/extracted/b99aab95e87290f8dd024f1f1f0c67ce/full.md`
- Filtered: `generated/filtered/b99aab95e87290f8dd024f1f1f0c67ce/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
