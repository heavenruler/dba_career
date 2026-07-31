# KnowledgeBase Vault

Open `obsidian/` as a vault. The default entry is `Knowledge Workbench.md`.

## Pilot

```sh
make obsidian_pilot
make obsidian_pilot_check
```

- `90 Sources/`, `01 Workbenches/`, `10 Maps/`, and `Bases/` are generated.
- `00 Inbox/Reviews/<doc_id>.md` is create-once human workflow state.
- Concept, Runbook, Case, Career, and Content notes are human-managed.
- `Attachments/Sources/` contains rebuildable local PDF hard links and is not committed.

## Workflow

1. Open `Knowledge Workbench`.
2. Choose an expert and a Review Queue item.
3. Verify source, extractive evidence, and PDF.
4. Update the Review Record.
5. Use a core Template to promote a note.
6. Move through `inbox → reviewed → evergreen`.

High-risk evergreen Runbooks require preconditions, validation, rollback, evidence,
tested_on, and `review_status: approved`.

## Full Import

```sh
make obsidian_import_all
make obsidian_check
```

Full import uses the same schema and preserves Review Records and human notes.
