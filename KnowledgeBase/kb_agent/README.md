# KB Agent Derived Indexes

This directory upgrades the KnowledgeBase from article chunks into task-oriented indexes for specialist agents.

Source data remains read-only under `generated/`. Derived artifacts here must preserve provenance with `doc_id`, `chunk_id`, and `source_kind`.

## Current KB Snapshot

- `generated/kb/chunks.jsonl`: 13228 chunks.
- `generated/kb/documents.jsonl`: 897 documents.
- `generated/filtered/*/knowledge.json`: 120 filtered documents at inspection time.
- Chunk fields include `doc_id`, `chunk_id`, `content`, `source_kind`, `quality`, `title`, `url`, `source_domain`, `tags`, `primary_category`, `chunk_types`, and `classification_confidence`.

## Derived Indexes

- `indexes/procedures.jsonl`: runbook/SOP records for SRE and DBA troubleshooting.
- `indexes/commands.jsonl`: command and SQL snippets with purpose, preconditions, risk, and caution.
- `indexes/concepts.jsonl`: reusable concepts, methods, templates, and aliases.
- `indexes/comparisons.jsonl`: architecture trade-off and ADR-style comparison records.
- `indexes/content_elements.jsonl`: required information atoms for content production.
- `indexes/content_topics.jsonl`: topic seeds that turn KB evidence into publishable angles.
- `indexes/content_templates.jsonl`: repeatable output shapes for LinkedIn and long-form posts.
- `indexes/content_calendar_seed.jsonl`: starter publishing queue.
- `indexes/qa_seed.jsonl`: high-value seed questions for retrieval smoke tests.
- `indexes/source_quality.jsonl`: evidence level and quality assessment per source document/chunk set.

## Content Production Layer

The KB now supports a second use case beyond question answering: repeatable technical sharing.

The content layer separates four things that should not be mixed:

1. `content_elements`: the minimum facts every post must carry.
2. `content_topics`: the workplace scenarios worth writing about.
3. `content_templates`: the reusable post structures.
4. `content_calendar_seed`: the initial publishing cadence.

This layer is intended for LinkedIn posts, technical sharing on platforms, and interview-style explanation reuse.

## Prompt And Retrieval Rules

Use `prompts/kb_agent_retrieval.md` as the default consumer prompt. It defines source priority, missing-evidence behavior, risk handling, and specialist routing.

## Structural Overview

Use `kb_structure.md` as the complete current map of the KB, including source layer, evidence layer, answer routes, content production layer, and coverage status.

## Validation

`reports/smoke_tests.md` records the Q1-Q4 smoke tests and known gaps.
