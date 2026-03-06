# A Modern Guide to MySQL Performance Monitoring

MetricFire Blogger — Oct 11, 2023 · 17 min read

## Key Takeaways

- MySQL is one of the most widely adopted database technologies, known for speed, reliability, and ANSI SQL compatibility.
- MySQL provides features such as resource groups, partitioning, high-concurrency optimizations, server-side thread pools, and performance schema that impact performance.
- Monitoring MySQL performance is essential to ensure application responsiveness, optimize queries and resource usage, and detect security or scalability issues.
- Effective monitoring involves selecting the right metrics and using the appropriate tools to collect, store, visualize, and alert on performance data.

## Introduction

MySQL is the backbone of many web, mobile, desktop, and cloud applications. Built with a strong focus on speed and reliability, MySQL is often chosen for applications that require distributed operations, fast development cycles, and rapid scalability.

As applications grow more complex and data volumes increase, monitoring MySQL performance becomes critical. Monitoring helps you preempt issues, optimize queries, provision resources appropriately, and improve user experience.

This guide explains key concepts for monitoring MySQL databases, important metrics to track, where to find those metrics, and tools and approaches for collecting and analyzing them.

## Understanding MySQL performance

### A brief MySQL overview

MySQL is a fast and stable multi-user, multi-threaded open-source relational database management system (RDBMS). It is available as the Community Server (free) and the commercial MySQL Enterprise Edition.

MySQL supports features such as a pluggable storage engine architecture, ANSI SQL compatibility, built-in replication and high availability, ACID-compliant transactions, row-level locking, and security features. These capabilities make it suitable for a broad range of applications.

### MySQL features that impact database performance

MySQL includes several technical features that drive performance:

- Resource groups (assign threads and allocate resources)
- Partitioning
- Optimizations for high concurrency
- Read-optimized modes
- Optimizations for SSD storage
- Multiple index types (B-tree, R-tree, hash, full-text, etc.)
- Server-side thread pool
- Connection thread caching
- Diagnostics and SQL tracing
- Performance schema and sys schema

These built-in, performance-focused features contribute to MySQL’s reputation for speed and reliability.

## Why monitor MySQL performance

Your database is a critical layer of your application stack. Monitoring database performance helps you:

- Identify and fix issues before they affect users
- Optimize database queries and schema
- Measure the impact of configuration or schema changes
- Provision compute and storage resources appropriately
- Detect potential security vulnerabilities
- Find opportunities to improve user experience

Monitoring MySQL performance affects not only the database but the overall application.

## Key MySQL database performance metrics

Database performance metrics fall into two broad types: workload metrics and resource metrics.

- Workload metrics measure overall work/output produced (queries, transactions, reads, writes).
- Resource metrics measure hardware, software, and network resource consumption.

Important subcategories to monitor:

- Throughput: how much work the database performs in a time interval (e.g., number of queries, transactions, reads, writes).
- Latency (execution time): time taken to perform units of work (e.g., query run times).
- Connections (concurrency): number of concurrent queries/connections and aborted connections.
- Buffer (utilization): buffer/cache usage (e.g., InnoDB buffer pool utilization).

Key metrics to track (names correspond to MySQL server status variables and performance schema statistics):

Throughput:
- Questions: number of client-initiated statements executed by the server
- Queries: number of statements executed by the server (includes client-sent statements and statements executed in stored procedures)
- Com_select: count of executed SELECT statements (read activity)
- Com_insert, Com_update, Com_delete: counts of write operations (often summed)

Latency:
- Slow_queries: number of queries that exceed long_query_time
- Query run time: statistics available in the performance schema

Concurrency:
- Aborted_connects: number of failed connection attempts
- Threads_connected: number of currently open connections
- Threads_running: number of non-sleeping threads

Buffers:
- Statistics obtainable from SHOW ENGINE INNODB STATUS (e.g., buffer pool metrics)

Unless otherwise indicated, these metrics are available via server status variables or the performance schema.

## Locating MySQL performance metrics

MySQL performance metrics can be obtained from three main sources:

- Server status variables: internal counters accessible via SHOW [GLOBAL | SESSION] STATUS.
- Performance schema: detailed monitoring tables (performance_schema.*) for server events and query execution.
- Sys schema: usability layer providing views and functions built on top of performance_schema for easier consumption.

Later sections show usage examples for each.

## Choosing which performance metrics to monitor

Which metrics to monitor depends on your use case, but the critical ones typically cover throughput, latency, concurrency, and buffer utilization (see the list in the previous section). Monitor metrics that reflect the workload your application generates and the resources you care about (CPU, memory, I/O, connections).

## Collecting and monitoring MySQL performance metrics

Below are common approaches and examples for collecting MySQL metrics.

### Server status variables

MySQL exposes server-status variables that act as counters for operations. Use:

- SHOW GLOBAL STATUS; to get aggregated values across all connections.
- SHOW SESSION STATUS; to get values for the current session.

Example: show all global status variables (shortened for brevity):

```sql
mysql> SHOW GLOBAL STATUS;
+-----------------+-------+
| Variable_name   | Value |
+-----------------+-------+
| Aborted_clients | 0     |
| ...             | ...   |
+-----------------+-------+
```

To view a single server status variable:

```sql
mysql> SHOW STATUS LIKE '%Com_select%';
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| Com_select    | 10    |
+---------------+-------+
1 row in set (0.0130 sec)
```

For a full list of server status variables, consult the documentation for your MySQL Server version.

### Performance schema

The performance schema monitors execution at the query level. If enabled, it appears as the performance_schema database containing many tables. Ensure it is installed and enabled before querying.

To list performance_schema tables:

```sql
mysql> SELECT TABLE_NAME
       FROM INFORMATION_SCHEMA.TABLES
       WHERE TABLE_SCHEMA = 'performance_schema';
+---------------------------------------------+
| TABLE_NAME                                  |
+---------------------------------------------+
| accounts                                    |
| cond_instances                              |
| data_lock_waits                              |
| data_locks                                   |
| events_errors_summary_by_account_by_error    |
| events_errors_summary_by_host_by_error       |
| events_errors_summary_by_thread_by_error     |
| ...                                          |
| table_handles                                |
| table_io_waits_summary_by_index_usage        |
| table_io_waits_summary_by_table              |
| table_lock_waits_summary_by_table            |
| threads                                      |
| user_defined_functions                       |
| user_variables_by_thread                     |
| users                                        |
| variables_by_thread                          |
+---------------------------------------------+
```

A useful performance schema table is events_statements_summary_by_digest. Example: get the query with the longest average execution time:

```sql
mysql> SELECT digest_text, avg_timer_wait
       FROM performance_schema.events_statements_summary_by_digest
       ORDER BY avg_timer_wait DESC
       LIMIT 1;
+----------------------------------------------------+---------------+
| digest_text                                        | avg_timer_wait|
+----------------------------------------------------+---------------+
| INSERT INTO `rental` VALUES (...) /* , ... */      | 407201600000  |
+----------------------------------------------------+---------------+
1 row in set (0.0052 sec)
```

You can set the current database to performance_schema with `USE performance_schema;` to avoid qualifying table names.

### Sys schema

The sys schema provides views and helper functions to simplify querying the performance schema. It was introduced to make the performance schema outputs more readable.

Example using a sys schema view:

```sql
mysql> SELECT * FROM sys.host_summary_by_file_io;
+------------+-------+-----------+
| host       | ios   | io_latency|
+------------+-------+-----------+
| background | 12167 | 1.48 s    |
| localhost  | 1694  | 427.99 ms |
+------------+-------+-----------+
2 rows in set (0.0049 sec)
```

### MySQL Workbench

MySQL Workbench provides a GUI to explore and investigate database performance. It includes a dashboard for high-level stats and tools to drill down into metrics exposed via the sys schema.

### Full-featured monitoring tools

Built-in MySQL monitoring features are useful for ad-hoc checks, but production environments require continuous monitoring, alerting, long-term storage, and visualization. Full-featured monitoring platforms can:

- Offload metric collection and storage so the database focuses on serving the application
- Provide dashboards and visualizations at different levels of granularity
- Trigger alerts and notifications for thresholds and anomalies
- Continuously track performance in high-volume environments

Examples of capabilities to look for in monitoring tools:
- Integrations with MySQL (server status, performance_schema, sys)
- Time-series data storage and retention
- Dashboards and query + visualization tools
- Alerting and notification channels
- Lightweight agents for metric collection

MetricFire is an example of a hosted monitoring platform that integrates with MySQL and provides collection, storage, visualization, and alerting for time-series metrics.

## Conclusion

Effective MySQL performance monitoring requires understanding which metrics matter for your workload (throughput, latency, concurrency, buffer utilization), where to obtain them (server status variables, performance schema, sys schema), and how to collect and analyze them using tools suitable for continuous production monitoring.

Choose a monitoring strategy and tools that match your requirements for data retention, visualization, alerting, and operational overhead. Hosted and managed monitoring platforms can simplify metric collection and storage while providing dashboards and alerting features to help you maintain MySQL performance.