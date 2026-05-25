# Smoke Test Report

Smoke tests are based on the original Q1-Q4 validation set.

## Q1 MySQL CPU 100%

Status: pass.

Expected route:

- `qa_seed.jsonl` -> `qa_mysql_cpu_100_os_to_sql`
- `procedures.jsonl` -> `proc_mysql_cpu_100_thread_to_sql`
- `commands.jsonl` -> `cmd_linux_top_process_cpu`, `cmd_linux_top_hot_mysql_thread`, `cmd_mysql_map_thread_os_id`, `cmd_mysql_current_statement_for_thread`, `cmd_mysql_kill_processlist_id`

Required answer elements:

- `top`
- `free -h`
- `top -H -p \`pidof mysqld\``
- `information_schema.processlist` + `performance_schema.threads`
- `performance_schema.events_statements_current`
- caution that `kill` should use the MySQL `processlist_id`

Primary evidence:

- doc_id=44862aef1f3e9f432840f303bb9da948 chunk_id=44862aef1f3e9f432840f303bb9da948:0002 source_kind=llm_filtered
- doc_id=44862aef1f3e9f432840f303bb9da948 chunk_id=44862aef1f3e9f432840f303bb9da948:0003 source_kind=llm_filtered

## Q2 PolarDB Cross-AZ Strong Consistency

Status: partial pass.

Expected route:

- `qa_seed.jsonl` -> `qa_polardb_cross_az_strong_consistency`
- `comparisons.jsonl` -> `cmp_polardb_cross_az_strong_consistency_vs_mgr`
- `concepts.jsonl` -> `concept_consensus_lsn`

Supported:

- three-AZ mode;
- one primary, one standby, one log node;
- Redo physical replication + X-Paxos;
- `consensus_lsn`;
- majority before commit success;
- MGR contrast around binlog requirement and large transactions.

Known gap:

- KB does not provide exact product configuration or cloud-console setup checklist.

Primary evidence:

- doc_id=f47e6048987f7b4eeb3199c1fc30c45c chunk_id=f47e6048987f7b4eeb3199c1fc30c45c:0001 source_kind=extracted_text
- doc_id=f47e6048987f7b4eeb3199c1fc30c45c chunk_id=f47e6048987f7b4eeb3199c1fc30c45c:0002 source_kind=extracted_text
- doc_id=f47e6048987f7b4eeb3199c1fc30c45c chunk_id=f47e6048987f7b4eeb3199c1fc30c45c:0003 source_kind=extracted_text

## Q3 HikariCP Connection Leak

Status: partial pass with explicit missing-evidence warning.

Expected route:

- `qa_seed.jsonl` -> `qa_hikaricp_connection_leak`
- `procedures.jsonl` -> `proc_connection_pool_exhaustion_hikari_partial`
- `concepts.jsonl` -> `concept_connection_leak_partial`
- `source_quality.jsonl` -> `sq_connection_pool_article`

Supported:

- generic connection leak/resource leak concept;
- pool exhaustion and wait behavior;
- HikariCP `maximumPoolSize`, `minimumIdle`, `connectionTimeout`;
- long transaction holding a connection.

Known gap:

- KB does not provide a dedicated HikariCP leak diagnosis article.
- KB does not provide `leakDetectionThreshold`, `ProxyLeakTask`, JMX, Micrometer, or stack trace diagnosis as supported evidence.

Primary evidence:

- doc_id=7fa5526bae686214bbcb40c29a167309 chunk_id=7fa5526bae686214bbcb40c29a167309:0004 source_kind=extracted_text
- doc_id=7fa5526bae686214bbcb40c29a167309 chunk_id=7fa5526bae686214bbcb40c29a167309:0027 source_kind=extracted_text
- doc_id=7fa5526bae686214bbcb40c29a167309 chunk_id=7fa5526bae686214bbcb40c29a167309:0028 source_kind=extracted_text
- doc_id=7fa5526bae686214bbcb40c29a167309 chunk_id=7fa5526bae686214bbcb40c29a167309:0029 source_kind=extracted_text

## Q4 Interview Expression Structure

Status: pass with STAR caveat.

Expected route:

- `qa_seed.jsonl` -> `qa_interview_expression_structure`
- `concepts.jsonl` -> `concept_value_chain_expression`, `concept_mece_data_governance`

Supported:

- conclusion-first / total-detail-total expression;
- Pyramid Principle reference;
- problem + action + data + business impact;
- background -> challenge -> action -> result;
- MECE.

Known gap:

- No dedicated STAR framework document found in current smoke test. Use STAR-like material and state the gap.

Primary evidence:

- doc_id=e1a168c44200c635a475549f4c5a5cc3 chunk_id=e1a168c44200c635a475549f4c5a5cc3:0002 source_kind=extracted_text
- doc_id=e1a168c44200c635a475549f4c5a5cc3 chunk_id=e1a168c44200c635a475549f4c5a5cc3:0005 source_kind=extracted_text
- doc_id=78aebc04d946bc99a8428426dfdc8163 chunk_id=78aebc04d946bc99a8428426dfdc8163:0002 source_kind=extracted_text

