# KB Information Structure

This document describes the current KB as a layered system, so it can be converted into a mind map or content production map without re-discovering the same structure.

## 1. Source Layer

### 1.1 Raw corpus under `generated/`

- `generated/kb/chunks.jsonl`
  - master chunk index
  - each line is one chunk
  - carries `doc_id`, `chunk_id`, `chunk_index`, `content`, `source_kind`, `quality`, `tags`, `primary_category`, `chunk_types`, and provenance fields
- `generated/kb/documents.jsonl`
  - document inventory
  - one line per document
- `generated/filtered/<doc_id>/knowledge.json`
  - filtered extractive knowledge layer
  - preferred source for answer construction when present
- `generated/extracted/<doc_id>/full.md`
  - raw extracted text plus OCR
  - fallback when filtered content is missing
- `generated/extracted/<doc_id>/metadata.json`
  - per-document metadata
- `generated/kb/missing_documents.jsonl`
  - documents expected but not available

### 1.2 Provenance keys

- `doc_id`: source PDF md5
- `chunk_id`: chunk identifier
- `source_kind`: `llm_filtered` or `extracted_text`

## 2. Knowledge Domains

### 2.1 Core domain coverage

- DBA and database core
  - MySQL
  - PostgreSQL
  - Oracle
  - TiDB
  - CRDB
  - YBDB
- system architecture and SRE
- observability and incident response
- analysis design and algorithms
- system design
- psychology and cognitive science
- workplace communication
- interview, resume, and value expression
- research methods

### 2.2 Domain intent

The KB is not just a document archive. It is intended to support:

- operational diagnosis
- architectural comparison
- reusable explanation
- career translation
- periodic technical sharing

## 3. Evidence Layer

This layer turns source chunks into reusable knowledge units.

### 3.1 Runbooks

File: `kb_agent/indexes/procedures.jsonl`

Use for:

- incident handling
- diagnostic sequencing
- immediate mitigation
- decision branches
- risk-aware operations

### 3.2 Commands and SQL

File: `kb_agent/indexes/commands.jsonl`

Use for:

- shell commands
- SQL snippets
- config inspection
- code-level examples
- risk and failure mode notes

### 3.3 Concepts

File: `kb_agent/indexes/concepts.jsonl`

Use for:

- reusable definitions
- aliases
- explanation blocks
- interview language
- framework translations

### 3.4 Comparisons

File: `kb_agent/indexes/comparisons.jsonl`

Use for:

- architecture trade-offs
- vendor vs vendor comparison
- mechanism comparison
- recommendation boundaries

### 3.5 Retrieval regression set

File: `kb_agent/indexes/qa_seed.jsonl`

Use for:

- smoke tests
- answer-quality regression
- coverage checks
- missing-evidence detection

### 3.6 Source quality

File: `kb_agent/indexes/source_quality.jsonl`

Use for:

- evidence trust
- noise assessment
- freshness notes
- recommended use boundaries

## 4. Content Production Layer

This layer exists so the KB can produce recurring technical sharing, not only answer questions.

### 4.1 Required content atoms

File: `kb_agent/indexes/content_elements.jsonl`

Minimum atoms:

- workplace problem
- diagnostic path
- core mechanism
- decision point
- risk boundary
- career translation
- evidence quality

### 4.2 Topic seeds

File: `kb_agent/indexes/content_topics.jsonl`

Each topic seed contains:

- pillar
- workplace situation
- academia-industry gap
- audience
- pain point
- technical modules
- KB citations
- output formats
- angle
- title candidates
- risk notes
- coverage and gaps

### 4.3 Writing templates

File: `kb_agent/indexes/content_templates.jsonl`

Templates currently cover:

- LinkedIn short insight
- LinkedIn practical post
- long-form technical post
- architecture trade-off article
- interview translation post

### 4.4 Publishing queue seed

File: `kb_agent/indexes/content_calendar_seed.jsonl`

Purpose:

- seed weekly or monthly posting
- map topic to template
- keep recurring content steady

## 5. Current Answer Routes

### 5.1 DBA / incident route

Preferred path:

1. `procedures.jsonl`
2. `commands.jsonl`
3. `concepts.jsonl`
4. `qa_seed.jsonl`

Examples:

- MySQL CPU 100%
- thread to SQL mapping
- connection pool exhaustion

### 5.2 Architecture route

Preferred path:

1. `comparisons.jsonl`
2. `concepts.jsonl`
3. `source_quality.jsonl`

Examples:

- PolarDB strong consistency
- trade-off explanation

### 5.3 Career and communication route

Preferred path:

1. `concepts.jsonl`
2. `qa_seed.jsonl`
3. `source_quality.jsonl`

Examples:

- Pyramid Principle
- MECE
- problem-action-data-business impact

### 5.4 Content production route

Preferred path:

1. `content_elements.jsonl`
2. `content_topics.jsonl`
3. `content_templates.jsonl`
4. `content_calendar_seed.jsonl`
5. supporting KB citations from evidence layer

## 6. Current High-Value Topics

These are the most clearly supported topics in the current KB.

- MySQL CPU 100% OS thread to SQL diagnosis
- PolarDB MySQL cross-AZ strong consistency
- connection pool exhaustion and partial HikariCP leak diagnosis
- interview and value-expression structure
- MECE and problem decomposition

## 7. Coverage Status

### 7.1 Complete or strong

- MySQL CPU 100% diagnosis path
- interview expression structure
- MECE decomposition

### 7.2 Partial

- PolarDB strong consistency setup details
- HikariCP-specific leak diagnosis details

### 7.3 Missing or weak

- explicit HikariCP `leakDetectionThreshold` source
- exact PolarDB product setup checklist
- broader source-quality automation
- weekly content scheduling automation

## 8. Content Logic

The KB should support the following transformation chain:

`source evidence -> extracted knowledge -> answer route -> content topic -> template -> publishable draft`

That is the complete structural target for the KB at this stage.
