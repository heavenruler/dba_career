# Architecture Design Template

## title

`<project-or-system-name> architecture design`

## metadata

- `document_owner`: `<team-or-owner>`
- `reviewers`: [`dba-director`, `<product-expert>`]
- `status`: `draft`
- `last_updated`: `YYYY-MM-DD`

## 1. Objective

- 業務目標：
- 技術目標：
- 成功條件：

## 2. Scope

- in scope:
- out of scope:

## 3. Requirements

- workload type:
- availability target:
- RPO / RTO:
- data size:
- growth rate:
- peak TPS / QPS:
- compliance / security:
- budget / delivery timeline:

## 4. Assumptions

- 

## 5. Candidate Options

| option | description | pros | cons | fit |
| --- | --- | --- | --- | --- |
| option-a |  |  |  |  |
| option-b |  |  |  |  |

## 6. Recommended Design

### topology

```text
<put topology outline here>
```

### components

| component | role | quantity | notes |
| --- | --- | --- | --- |
| db-primary | primary database | 1 |  |
| db-replica | replica / standby | 2 |  |

### network and security

- 

### backup and recovery

- 

### observability

- 

## 7. Risks And Trade-offs

| risk | impact | mitigation |
| --- | --- | --- |
|  |  |  |

## 8. Implementation Plan

| phase | objective | owner | validation |
| --- | --- | --- | --- |
| phase-1 |  |  |  |
| phase-2 |  |  |  |

## 9. Open Items

- 

## 10. Approval

- go / no-go:
- approver:
- approval_date:
