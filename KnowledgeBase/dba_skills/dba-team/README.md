# dba-team

企業內部 DBA Team / Solution Architect / Knowledge Base / Memory System 風格的 OpenCode skill 專案。

## Overview

- skill name: `dba-team`
- primary language: `zh-TW`
- entry role: `dba-assistant`
- target runtime: OpenCode / Skill Registry compatible scaffold

## Directory Layout

```text
dba-team/
├── README.md
├── SKILL.md
├── skill.json
├── registry-entry.json
├── memory.md
├── workflows.md
├── prompts/
├── references/
└── memory/
```

## Included Roles

### Core coordination

- `dba-assistant`
- `dba-director`

### Product experts

- `oracle-expert`
- `mysql-expert`
- `postgresql-expert`
- `tidb-expert`
- `tdsql-expert`
- `mongodb-expert`
- `redis-expert`
- `clickhouse-expert`
- `sql-server-expert`
- `mariadb-expert`

### Cross-functional experts

- `performance-engineer`
- `ha-dr-expert`
- `migration-architect`
- `platform-automation-expert`

## OpenCode Load Order

建議載入順序：

1. 讀取 `skill.json`
2. 讀取 `SKILL.md`
3. 讀取 `memory.md` 與 `workflows.md`
4. 預設載入 `prompts/dba-assistant.md`
5. 依 routing 規則按需讀取其他 `prompts/*.md`
6. 執行時再讀取 `memory/*.json` 與 `references/`

## Install

### Local copy

```sh
mkdir -p ~/.config/opencode/skills
cp -R dba-team ~/.config/opencode/skills/
```

### Registry-style link

```sh
mkdir -p ~/.config/opencode/skills
ln -s "$(pwd)/dba-team" ~/.config/opencode/skills/dba-team
```

### Verification

```sh
test -f ~/.config/opencode/skills/dba-team/skill.json && echo ok
test -f ~/.config/opencode/skills/dba-team/prompts/dba-assistant.md && echo ok
```

## Registry Notes

- `skill.json` 是主要 manifest。
- `registry-entry.json` 適合給清單頁、搜尋索引或 registry catalog 使用。
- 若你的 OpenCode runtime 只接受單一 manifest，可直接讀 `skill.json`。

## Maintenance

- 新增角色時，同步更新 `skill.json`、`SKILL.md`。
- 若新增標準知識，優先放到 `references/`。
- 若確認新的環境、歷史或偏好，更新 `memory/`。
