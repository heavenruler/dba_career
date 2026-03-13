# Migration Plan Template

## migration_overview

- `project`: `<project-name>`
- `source_db`: `<engine-version>`
- `target_db`: `<engine-version>`
- `owner`: `<owner>`
- `status`: `draft`

## 1. Objective

- migration goal:
- business reason:
- success criteria:

## 2. Scope

- schema scope:
- data scope:
- application scope:
- excluded scope:

## 3. Environment And Assumptions

- source topology:
- target topology:
- data volume:
- downtime window:
- rollback window:
- dependencies:

## 4. Compatibility Assessment

| item | status | notes |
| --- | --- | --- |
| schema compatibility | pending |  |
| sql compatibility | pending |  |
| driver compatibility | pending |  |
| backup / rollback readiness | pending |  |

## 5. Migration Strategy

- strategy type: `offline | online | cdc | dual-write | phased`
- tooling:
- cutover approach:
- rollback approach:

## 6. Execution Steps

| step | description | owner | validation |
| --- | --- | --- | --- |
| 1 |  |  |  |
| 2 |  |  |  |

## 7. Validation Checklist

- schema checksum:
- row count:
- critical query verification:
- application smoke test:
- replication / sync status:

## 8. Risks

| risk | likelihood | impact | mitigation |
| --- | --- | --- | --- |
|  |  |  |  |

## 9. Go / No-Go Criteria

- go criteria:
- no-go criteria:
- final approver:

## 10. Post Cutover Tasks

- monitoring:
- performance observation:
- cleanup:
- documentation update:
