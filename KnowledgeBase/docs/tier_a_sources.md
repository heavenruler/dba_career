# Tier_a 權威來源蒐集清單（pre-build KB 缺口補齊）

> 本 collector（897 PDF）以中文技術部落格為主（微信公眾號 79%），缺乏權威基礎層。本清單列出建議優先蒐集的官方文檔、書籍、學術論文。  
> 完成蒐集後，建議把檔案放到 `collector/tier_a/`（與既有 collector/ 區隔），並在 manifest / chunks metadata 加 `tier: a`，RAG 檢索時 tier_a 優先。

## 優先級說明

- **P0**：DBA 日常 ops 必查，無此資料 RAG 無法回答權威問題
- **P1**：架構設計與升級評估必備
- **P2**：深度研究與面試準備

---

## 1. 官方手冊（P0）

| # | 來源 | 版本 | 取得方式 | 預估頁數 | 備註 |
|---|---|---|---|---:|---|
| 1 | MySQL Reference Manual | 8.0 LTS（生產主流）+ 8.4 LTS | dev.mysql.com/doc/refman/8.0/en/mysql-refman-8.0-en.a4.pdf | ~5500 | `Backup and Recovery` / `Replication` / `InnoDB Locking` 三章為核心 |
| 2 | MySQL Reference Manual | 5.7（仍有舊環境） | dev.mysql.com/doc/refman/5.7/en/mysql-refman-5.7-en.a4.pdf | ~5000 | 僅取 differences 章節 |
| 3 | PostgreSQL Documentation | 17（最新）+ 16（LTS-like） | postgresql.org/files/documentation/pdf/17/postgresql-17-A4.pdf | ~3500 | `Backup and Restore` / `High Availability` / `Internals` 為核心 |
| 4 | MongoDB Manual | 7.0 / 8.0 | mongodb.com 官方 docs（無 PDF，需爬蟲或 `mongodb-manual` repo） | – | `Replica Sets` / `Sharded Clusters` / `Operations` 章 |
| 5 | Redis Documentation | 7.4 | redis.io/docs（無官方 PDF）；可從 redis/redis-doc GitHub repo 蒐集 markdown | – | `Persistence` / `Replication` / `Sentinel` / `Cluster` 章 |
| 6 | Oracle Database Concepts | 19c | docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/database-concepts.pdf | ~600 | Backup&Recovery User's Guide 另文件 |
| 7 | Oracle Backup and Recovery User's Guide | 19c | docs.oracle.com/en/database/oracle/oracle-database/19/bradv/backup-and-recovery-users-guide.pdf | ~700 | DBA 必備 |
| 8 | InnoDB Cluster (Group Replication) Manual | 8.0 | dev.mysql.com/doc/refman/8.0/en/mysql-innodb-cluster.html → wkhtmltopdf | – | 高可用核心 |
| 9 | Percona XtraBackup User Manual | 8.0 | docs.percona.com/percona-xtrabackup/8.0/ → PDF | ~200 | 備份標準工具 |
| 10 | ProxySQL Documentation | 2.x | proxysql.com/documentation/（無 PDF，需爬） | – | 補強 `DatabaseManagement/ProxySQL` 殼 |
| 11 | TiDB Documentation | 7.5 LTS / 8.5 | docs.pingcap.com/tidb/v7.5/ → PDF export | ~1500 | 已有少量中文 PDF 但官方更權威 |
| 12 | ClickHouse Documentation | 24.x | clickhouse.com/docs（無 PDF，需 docs repo） | – | 補 OLAP 缺口 |

## 2. 雲端官方 best practice（P0）

| # | 來源 | 取得方式 | 備註 |
|---|---|---|---|
| 13 | Amazon RDS for MySQL User Guide | docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-ug.pdf | ~1500 頁 |
| 14 | Amazon Aurora User Guide | docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-ug.pdf | ~1200 頁 |
| 15 | GCP Cloud SQL 文檔 | cloud.google.com/sql/docs | 無 PDF，需爬 |
| 16 | Azure Database for MySQL Flexible Server | learn.microsoft.com/azure/mysql/ | 無 PDF |
| 17 | 阿里雲 PolarDB / RDS 官方白皮書 | help.aliyun.com/zh/polardb/ | 用 wkhtmltopdf |

## 3. 經典書籍（P1）

| # | 書名 | 作者 / 版本 | ISBN / 來源 | 備註 |
|---|---|---|---|---|
| 18 | **High Performance MySQL** | Schwartz et al. 4e (2021) | ISBN 978-1492080510 | DBA 必讀；O'Reilly 學習平台或購買 |
| 19 | **Designing Data-Intensive Applications** | Martin Kleppmann (2017) | ISBN 978-1449373320 | 分散式系統一致性 / 複製 / 一致 hash 一本搞定 |
| 20 | **Database Internals** | Alex Petrov (2019) | ISBN 978-1492040347 | B-tree / LSM / Raft / Paxos 圖解 |
| 21 | **MySQL Internals Manual** | MySQL 官方 | dev.mysql.com/doc/internals/en/ → PDF | 免費 |
| 22 | **PostgreSQL: Up and Running** | Regina Obe 3e | ISBN 978-1491963418 | PG 入門 |
| 23 | **MongoDB: The Definitive Guide** | Bradshaw et al. 3e | ISBN 978-1491954461 | MongoDB 系統性入門 |
| 24 | **Redis in Action** | Josiah Carlson | ISBN 978-1617290855 | Redis 設計模式 |
| 25 | **Oracle Database 19c Performance Tuning Recipes** | Sam R. Alapati | ISBN 978-1484256183 | |
| 26 | **Database Reliability Engineering** | Campbell & Majors (2017) | ISBN 978-1491925942 | DBRE 文化 / SLO |
| 27 | **MySQL Cookbook** | Paul DuBois 4e | ISBN 978-1492093169 | SQL 食譜書 |

## 4. 學術 paper（P1-P2）

| # | Paper | 來源 | 為何重要 |
|---|---|---|---|
| 28 | **Raft: In Search of an Understandable Consensus Algorithm** | raft.github.io/raft.pdf | MGR / etcd / TiKV 基礎 |
| 29 | **Paxos Made Simple** | lamport.azurewebsites.net/pubs/paxos-simple.pdf | 共識演算法經典 |
| 30 | **ARIES: A Transaction Recovery Method** | C. Mohan (1992) | InnoDB redo/undo 設計依據 |
| 31 | **Spanner: Google's Globally-Distributed Database** | research.google/pubs/pub39966/ | TiDB / CockroachDB 啟發 |
| 32 | **Calvin: Fast Distributed Transactions** | cs.yale.edu/homes/thomson/publications/calvin-sigmod12.pdf | 確定性事務 |
| 33 | **Aurora: Design Considerations** | SIGMOD 2017 | 雲原生資料庫架構 |
| 34 | **F1: A Distributed SQL Database That Scales** | research.google/pubs/pub41344/ | 全球分散式 SQL |
| 35 | **The Log-Structured Merge-Tree (LSM-Tree)** | O'Neil et al. (1996) | RocksDB / Cassandra / ClickHouse 基礎 |
| 36 | **Dynamo: Amazon's Highly Available Key-value Store** | SOSP 2007 | 最終一致性 / 一致 hash |

## 5. 規範與安全（P1）

| # | 來源 | 取得方式 | 備註 |
|---|---|---|---|
| 37 | CIS MySQL Benchmark | cisecurity.org（需註冊） | 加固清單 |
| 38 | CIS PostgreSQL Benchmark | cisecurity.org | 同上 |
| 39 | CIS MongoDB Benchmark | cisecurity.org | 同上 |
| 40 | DISA STIG MySQL | public.cyber.mil | 軍規等級加固 |
| 41 | SQL:2023 標準摘要章節 | ISO/IEC 9075-2:2023（需購買） | 或用 Modern SQL（modern-sql.com）整理 |

## 6. 中文補強來源（P2）

| # | 來源 | 取得方式 | 備註 |
|---|---|---|---|
| 42 | 《MySQL 是怎樣運行的》小孩子 4 | ISBN 978-7115551733 | InnoDB 圖解，中文化好理解 |
| 43 | 阿里 / 騰訊 雲端資料庫白皮書 | 各自官網下載中心 | 對齊既有 collector 的中文語境 |
| 44 | 《MySQL 實戰 45 講》極客時間（林曉斌） | 付費課程文字稿 | 中文 DBA 經典 |
| 45 | MySQL Lab（mysql.taobao.org/monthly） | 已有 2 篇於 collector | 全站爬蟲化（~150 期月報） |

---

## 蒐集策略

1. **立即可下載（免費 PDF）**：1, 2, 3, 6, 7, 13, 14, 21, 28-36 → 我可寫 `scripts/fetch_tier_a.py` 但你選了「只要清單」，所以這部分自取
2. **需爬蟲渲染**：4, 5, 8, 10, 11, 12, 15-17, 41 → 建議用 `wkhtmltopdf` 或 `playwright` 站點抓取
3. **需購買 / 訂閱**：18-27, 37-41 → 採購流程
4. **shipping order**：先 1, 3, 7, 13, 14, 28, 35 → 立即填補「備份恢復」「高可用基礎」「雲端 RDS」三大缺口
