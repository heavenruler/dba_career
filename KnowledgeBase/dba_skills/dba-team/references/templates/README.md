# templates 說明

`references/templates/` 存放可直接複製使用的文件、SOP、review、PoC 與自動化模板。

## 內容原則

- 模板要能直接複製後修改，不只做欄位示意
- 預設使用 markdown、shell、sql、yaml、json
- 變數以英文字段命名，說明以繁體中文為主
- 每份模板應包含適用範圍、輸入欄位、步驟、驗證、風險或回退

## 已提供模板

- `architecture-design-template.md`
- `incident-rca-template.md`
- `migration-plan-template.md`
- `sop-runbook-template.md`
- `poc-evaluation-template.md`
- `ansible-inventory-template.yml`
- `terraform-variables-template.tfvars.json`

## 使用建議

1. 架構設計需求優先用 `architecture-design-template.md`
2. 線上事故結案後用 `incident-rca-template.md`
3. 升級與遷移用 `migration-plan-template.md`
4. 標準操作文件用 `sop-runbook-template.md`
5. PoC / benchmark 結果用 `poc-evaluation-template.md`
6. 平台自動化交付可從 ansible / terraform 範本開始
