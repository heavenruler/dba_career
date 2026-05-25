# KB Content Production Map

This layer turns KB evidence into repeatable technical sharing.

## 1. Content Pillars

- `workplace_problem`: incidents, bottlenecks, outages, and operational pain.
- `technical_mechanism`: commands, SQL, architecture, and failure modes.
- `decision_reasoning`: trade-offs, boundaries, and risk handling.
- `career_translation`: how to express the same work in interview, resume, or LinkedIn language.
- `evidence_quality`: what is proven, what is partial, and what is missing.

## 2. Required Information Elements

- `scenario`: what happened in the real workplace.
- `symptom`: what was observed first.
- `diagnostic_path`: how to move from symptom to root cause.
- `core_mechanism`: the technical principle that explains the behavior.
- `commands_or_queries`: concrete steps a practitioner can run.
- `decision_point`: where judgement is required.
- `risk_boundary`: what not to do and why.
- `evidence_status`: complete, partial, or missing.
- `career_translation`: how to retell the same lesson as a story.

## 3. Output Ladder

1. `LinkedIn short insight`
   - one scenario
   - one technical point
   - one takeaway
   - one citation block

2. `LinkedIn practical post`
   - scenario
   - mistake to avoid
   - step-by-step approach
   - risk boundary
   - summary lesson

3. `Platform technical post`
   - full diagnostic path
   - commands or SQL
   - mechanism
   - trade-offs
   - fallback or mitigation

4. `Interview translation`
   - problem
   - action
   - data
   - business impact
   - concise answer version

## 4. Repurposing Flow

`KB source -> content element extraction -> topic seed -> template selection -> publishable draft -> interview/resume variant`

## 5. Writing Rules

- Every post must name the workplace problem first.
- Every technical claim must carry a KB citation.
- If the KB only proves part of the story, say `KB 未提供`.
- Do not inflate a partial source into a complete operating playbook.
- Do not write generic motivation when a concrete incident can be explained.
