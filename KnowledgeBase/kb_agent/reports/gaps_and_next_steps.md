# Gaps And Next Steps

## Current Gaps

1. HikariCP leak diagnosis is undercovered.
   - Current KB has generic connection pool material and HikariCP parameter notes.
   - Missing: `leakDetectionThreshold`, stack traces, JMX/Micrometer metrics, active/idle/pending examples, Spring/MyBatis transaction interaction.

2. PolarDB setup checklist is undercovered.
   - Current KB proves the mechanism.
   - Missing: product configuration, cloud-console settings, prerequisites, operational constraints, and failback procedure.

3. Source quality is still manual.
   - The seed `source_quality.jsonl` covers only smoke-test documents.
   - Need automated classification for official/vendor/community/interview/noise.

4. Risk taxonomy needs broadening.
   - Current dangerous examples include `kill` and pool size tuning.
   - Need coverage for `reset master`, `START GROUP_REPLICATION`, global parameter changes, DDL, failover, restart, cache clear, and data migration scripts.

5. Career/psychology templates are partial.
   - Good material exists for Pyramid Principle and business-language expression.
   - Missing dedicated STAR/CAR/PAR templates and interview follow-up paths.

6. Content-production scaffolding is now present but still shallow.
   - We now have `content_elements`, `content_topics`, `content_templates`, and a starter calendar.
   - Missing: automatic topic scoring, audience-specific template selection, and weekly queue generation.

## Next Expansion

1. Generate additional procedures from high-value incident classes:
   - lock wait / deadlock;
   - replication delay;
   - connection pool exhaustion;
   - slow query;
   - disk IO saturation;
   - failover / HA incident.

2. Expand `commands.jsonl` by extracting shell and SQL snippets from verified chunks.

3. Add a lightweight verifier:
   - all JSONL lines parse;
   - every citation points to an existing `chunk_id`;
   - high-risk commands have `caution`;
   - every `qa_seed` has at least one expected source.

4. Add source-quality scoring rules:
   - `llm_filtered` preferred over raw extraction;
   - official docs > vendor engineering blog > community article > interview-prep post;
   - penalize `quality=short`, recommendation-only chunks, and OCR/page-header noise.

5. Expand the content layer:
   - add recurring themes for rollback, lock wait, deadlock, replication delay, and HA incidents;
   - add interview-facing rewrite variants for each technical topic;
   - add a simple topic-to-template scheduler for weekly posts.
