# Derived Index Schemas

All records are JSON objects stored as JSONL. Required provenance for any evidence-backed claim:

- `doc_id`: source document md5.
- `chunk_id`: source chunk id.
- `source_kind`: `llm_filtered` or `extracted_text`.

When a record combines multiple chunks, use `citations`, an array of `{doc_id, chunk_id, source_kind}`.

## `procedures.jsonl`

Purpose: runbook-level records for SRE/DBA incident handling.

Required fields:

- `procedure_id`: stable id.
- `title`: human-readable name.
- `expertise`: primary expert lens, e.g. `sre`, `dba`, `java_backend`.
- `scenario`: incident or task trigger.
- `symptoms`: observable signals.
- `impact`: expected or observed blast radius.
- `preconditions`: required versions, features, privileges, or environment.
- `immediate_mitigation`: safe first actions.
- `diagnostic_steps`: ordered objects with `step`, `purpose`, `commands`, `expected_signal`, `citations`.
- `decision_branches`: condition/action branches.
- `root_causes`: candidate causes supported by the KB.
- `fixes`: remediation options.
- `prevention`: follow-up controls.
- `risk_operations`: dangerous operations with `operation`, `risk_level`, `caution`.
- `coverage`: `complete`, `partial`, or `missing`.
- `coverage_notes`: what the KB does or does not prove.
- `citations`: source citations.

## `commands.jsonl`

Purpose: command/SQL registry for safe agent use.

Required fields:

- `command_id`
- `command`
- `command_type`: `shell`, `sql`, `config`, or `code`.
- `purpose`
- `applies_to`
- `preconditions`
- `expected_output`
- `risk_level`: `low`, `medium`, `high`, or `dangerous`.
- `caution`
- `failure_modes`
- `citations`

## `concepts.jsonl`

Purpose: domain concepts, aliases, templates, and reusable explanation blocks.

Required fields:

- `concept_id`
- `name`
- `category`
- `aliases`
- `definition`
- `use_when`
- `do_not_use_when`
- `related_concepts`
- `evidence_level`
- `citations`

## `comparisons.jsonl`

Purpose: architecture and design trade-off records.

Required fields:

- `comparison_id`
- `title`
- `decision_context`
- `options`: array of option objects with `name`, `mechanism`, `strengths`, `weaknesses`, `preconditions`, `fit_scenarios`, `anti_scenarios`.
- `tradeoff_axes`: e.g. consistency, latency, cost, complexity, RPO/RTO.
- `recommended_when`
- `avoid_when`
- `open_questions`
- `citations`

## `content_elements.jsonl`

Purpose: minimum information atoms required for publishable content.

Required fields:

- `element_id`
- `name`
- `role`
- `why_it_matters`
- `must_include`
- `source_priority`
- `missing_behavior`
- `citations`

## `content_topics.jsonl`

Purpose: topic seeds that connect workplace situations to KB-backed technical sharing.

Required fields:

- `topic_id`
- `pillar`
- `workplace_situation`
- `academia_industry_gap`
- `audience`
- `pain_point`
- `technical_modules`
- `source_indexes`
- `kb_citations`
- `output_formats`
- `angle`
- `title_candidates`
- `risk_notes`
- `coverage`
- `known_gaps`

## `content_templates.jsonl`

Purpose: reusable writing shapes for LinkedIn and long-form posts.

Required fields:

- `template_id`
- `platform`
- `length_target`
- `hook`
- `structure`
- `required_sections`
- `tone`
- `do_not_do`
- `best_for`
- `citations`

## `content_calendar_seed.jsonl`

Purpose: starter publishing queue for recurring content.

Required fields:

- `calendar_id`
- `publish_window`
- `topic_id`
- `template_id`
- `format`
- `status`
- `goal`
- `primary_takeaway`
- `citations`

## `qa_seed.jsonl`

Purpose: retrieval and answer-quality regression set.

Required fields:

- `qa_id`
- `question`
- `expertise`
- `expected_sources`: array of citations.
- `expected_answer_shape`
- `must_include`
- `must_not_invent`
- `known_gaps`
- `pass_criteria`

## `source_quality.jsonl`

Purpose: source-level trust and noise assessment.

Required fields:

- `source_quality_id`
- `doc_id`
- `title`
- `source_domain`
- `source_kind_available`
- `evidence_level`: `official`, `vendor`, `engineering_blog`, `community`, `interview`, `unknown`.
- `freshness`
- `noise_level`: `low`, `medium`, `high`.
- `quality_notes`
- `known_limitations`
- `recommended_use`
- `citations`
