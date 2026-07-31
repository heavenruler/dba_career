#!/usr/bin/env python3
"""Build the Obsidian expert workbench without overwriting human review state."""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import tempfile
from collections import Counter
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
VAULT = ROOT / "obsidian"
MANIFEST = ROOT / "output_with_md5.txt"
PILOT = VAULT / "pilot_sources.json"
CHUNKS = ROOT / "generated/kb/chunks.jsonl"
FILTERED = ROOT / "generated/filtered"
EXTRACTED = ROOT / "generated/extracted"
COLLECTOR = ROOT / "collector"

EXPERTS = (
    "DBA",
    "SRE Platform",
    "Solution Architecture",
    "Career Interview",
    "Content Production",
    "Knowledge Operations",
)
EXPERT_SLUG = {
    "DBA": "DBA",
    "SRE Platform": "SRE Platform",
    "Solution Architecture": "Solution Architecture",
    "Career Interview": "Career Interview",
    "Content Production": "Content Production",
    "Knowledge Operations": "Knowledge Operations",
}
MANAGED_DIRS = ("01 Workbenches", "10 Maps", "90 Sources", "Bases")
VALID_DOC_ID = re.compile(r"^[0-9a-f]{32}$")
INVALID_FILENAME = re.compile(r'[\\/:*?"<>|#^[\]]')
SPACE = re.compile(r"\s+")


def q(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def manifest_docs() -> dict[str, dict]:
    docs: dict[str, dict] = {}
    block: list[str] = []

    def add() -> None:
        if len(block) < 3:
            return
        title, url, doc_id = (part.strip() for part in block[:3])
        if title and VALID_DOC_ID.fullmatch(doc_id) and doc_id not in docs:
            docs[doc_id] = {"doc_id": doc_id, "title": title, "url": url}

    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        if line.strip() == "----":
            add()
            block = []
        else:
            block.append(line)
    add()
    return docs


def pilot_config() -> list[dict]:
    data = json.loads(PILOT.read_text(encoding="utf-8"))
    return data["sources"]


def filtered_data(doc_id: str) -> dict | None:
    path = FILTERED / doc_id / "knowledge.json"
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def chunks_by_doc() -> dict[str, list[dict]]:
    result: dict[str, list[dict]] = {}
    if not CHUNKS.is_file():
        return result
    for line in CHUNKS.read_text(encoding="utf-8").splitlines():
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        doc_id = row.get("doc_id")
        if isinstance(doc_id, str):
            result.setdefault(doc_id, []).append(row)
    return result


def safe_name(title: str, doc_id: str) -> str:
    name = SPACE.sub(" ", INVALID_FILENAME.sub(" ", title)).strip(" .") or "Untitled"
    return f"{name[:92].rstrip()} -- {doc_id[:8]}"


def evidence_for(doc: dict, chunks: list[dict]) -> list[dict]:
    evidence = []
    for row in chunks:
        content = str(row.get("content") or "").strip()
        if not content:
            continue
        evidence.append({
            "chunk_id": str(row.get("chunk_id") or ""),
            "source_kind": str(row.get("source_kind") or "unknown"),
            "content": content[:1800].rstrip(),
        })
        if len(evidence) == 3:
            break
    if evidence:
        return evidence

    data = filtered_data(doc["doc_id"])
    for index, section in enumerate((data or {}).get("sections", []), start=1):
        if not isinstance(section, dict):
            continue
        content = str(section.get("content") or "").strip()
        if content:
            evidence.append({
                "chunk_id": f"{doc['doc_id']}:section-{index:04d}",
                "source_kind": "llm_filtered",
                "content": content[:1800].rstrip(),
            })
        if len(evidence) == 3:
            break
    return evidence


def source_status(doc_id: str) -> str:
    if filtered_data(doc_id):
        return "llm_filtered"
    if (EXTRACTED / doc_id / "full.md").is_file():
        return "extracted-only"
    return "source-only"


def source_page(doc: dict, cfg: dict, chunks: list[dict], review_stem: str) -> str:
    doc_id = doc["doc_id"]
    primary = cfg["expected_primary_expert"]
    domains = cfg["expected_expert_domains"]
    status = source_status(doc_id)
    data = filtered_data(doc_id) or {}
    summary = str(data.get("summary") or "").strip()
    sections = [s for s in data.get("sections", []) if isinstance(s, dict)]
    evidence = evidence_for(doc, chunks)
    domain = urlparse(doc["url"]).netloc.lower()
    lines = [
        "---",
        f"doc_id: {q(doc_id)}",
        f"title: {q(doc['title'])}",
        "knowledge_type: source",
        "status: reviewed",
        f"primary_expert: {q(primary)}",
        "expert_domains:",
        *[f"  - {q(item)}" for item in domains],
        "classification_source: generated",
        f"source_kind: {q(status)}",
        f"source_domain: {q(domain)}",
        f"url: {q(doc['url'])}",
        "generated: true",
        "---",
        "",
        f"# {doc['title']}",
        "",
        "> [!info] Provenance",
        f"> - doc_id: `{doc_id}`",
        f"> - source_kind: `{status}`",
        f"> - original: [來源連結]({doc['url']})" if doc["url"] else "> - original: unavailable",
        f"> - Review Record: [[{review_stem}]]",
        f"> - PDF: [[Attachments/Sources/{doc_id}.pdf|Open PDF]]",
        "",
        "## 專家建議",
        "",
        f"- primary_expert: **{primary}**",
        f"- expert_domains: {', '.join(domains)}",
        f"- reason: {cfg['reason']}",
        "",
        "## Generated Summary",
        "",
        "> [!warning] Generated interpretation",
        "> 下列摘要不是來源原文；技術主張請回到 Evidence 與 PDF 核對。",
        "",
        summary or "KB evidence 不足",
        "",
        "## Knowledge Outline",
        "",
    ]
    if sections:
        lines.extend(f"- {SPACE.sub(' ', str(s.get('heading') or '')).strip()}" for s in sections[:12])
    else:
        lines.append("- KB evidence 不足")
    lines.extend(["", "## Extractive Evidence", ""])
    if not evidence:
        lines.append("KB evidence 不足")
    for item in evidence:
        lines.extend([
            f"### `{item['chunk_id']}`",
            "",
            f"`doc_id: {doc_id}` · `source_kind: {item['source_kind']}`",
            "",
            "```text",
            item["content"],
            "```",
            "",
        ])
    lines.extend([
        "## Repository Paths",
        "",
        f"- PDF: `collector/{doc_id}.pdf`",
        f"- Extracted: `generated/extracted/{doc_id}/full.md`",
        f"- Filtered: `generated/filtered/{doc_id}/knowledge.json`",
        "",
        "<!-- Generated source page: do not edit. Use the Review Record or promote a new note. -->",
        "",
    ])
    return "\n".join(lines)


def review_record(doc: dict, cfg: dict, source_stem: str) -> str:
    domains = cfg["expected_expert_domains"]
    return "\n".join([
        "---",
        f"doc_id: {q(doc['doc_id'])}",
        f"title: {q(doc['title'])}",
        "knowledge_type: review",
        "status: inbox",
        f"primary_expert: {q(cfg['expected_primary_expert'])}",
        "expert_domains:",
        *[f"  - {q(item)}" for item in domains],
        "classification_source: generated",
        "risk_level: none",
        "review_status: pending",
        "source_quality: 0",
        "knowledge_value: 0",
        "promoted_notes: []",
        "---",
        "",
        f"# Review · {doc['title']}",
        "",
        f"- Source: [[{source_stem}]]",
        f"- PDF: [[Attachments/Sources/{doc['doc_id']}.pdf|Open PDF]]",
        "",
        "## Review Checklist",
        "",
        "- [ ] 核對 primary_expert 與 expert_domains",
        "- [ ] 核對來源有效性與 evidence",
        "- [ ] 決定 promoted note 類型",
        "- [ ] 更新 status 與 review_status",
        "",
        "## Notes",
        "",
    ])


def base_file(expert: str | None = None) -> str:
    expert_filter = f'\n    - \'primary_expert == "{expert}"\'' if expert else ""
    return f"""filters:
  and:
    - 'file.ext == "md"'
    - 'file.inFolder("00 Inbox/Reviews")'{expert_filter}
formulas:
  risk_rank: 'if(risk_level == "high", 4, if(risk_level == "medium", 3, if(risk_level == "low", 2, 1)))'
  evidence_alert: 'if(source_quality == 0, "missing evidence", if(review_status == "pending", "pending review", if(risk_level == "high" && review_status != "approved", "high-risk gate", "")))'
properties:
  status:
    displayName: 狀態
  primary_expert:
    displayName: 主責專家
  risk_level:
    displayName: 風險
  review_status:
    displayName: 審核
  source_quality:
    displayName: 來源品質
  knowledge_value:
    displayName: 知識價值
  formula.evidence_alert:
    displayName: 警示
views:
  - type: table
    name: Review Queue
    filters:
      and:
        - 'status == "inbox"'
    order:
      - file.name
      - risk_level
      - source_quality
      - knowledge_value
      - review_status
      - formula.evidence_alert
    sort:
      - property: formula.risk_rank
        direction: DESC
      - property: source_quality
        direction: DESC
      - property: knowledge_value
        direction: DESC
      - property: file.mtime
        direction: DESC
  - type: table
    name: Evidence Gaps
    filters:
      or:
        - 'source_quality == 0'
        - 'review_status == "pending"'
        - 'risk_level == "high" && review_status != "approved"'
    order:
      - file.name
      - risk_level
      - review_status
      - source_quality
      - formula.evidence_alert
    sort:
      - property: formula.risk_rank
        direction: DESC
      - property: file.mtime
        direction: DESC
"""


def workbench(expert: str) -> str:
    slug = EXPERT_SLUG[expert]
    return "\n".join([
        "---",
        f"title: {q(expert)}",
        f"primary_expert: {q(expert)}",
        "knowledge_type: concept",
        "status: evergreen",
        f"cssclasses: [knowledge-workbench, expert-{slug.lower().replace(' ', '-')}]",
        "---",
        "",
        f"# {expert}",
        "",
        "[[Knowledge Workbench|← 首頁]]",
        "",
        "## Knowledge",
        "",
        f"![[{slug} Knowledge.base#Knowledge]]",
        "",
        "## Review Queue",
        "",
        f"![[{slug} Review.base#Review Queue]]",
        "",
        "## Evidence Gaps",
        "",
        f"![[{slug} Review.base#Evidence Gaps]]",
        "",
        "## Sections",
        "",
        "Overview · Runbooks · Concepts · Cases · Questions · Sources · Gaps · Recent",
        "",
    ])


def knowledge_base(expert: str) -> str:
    return f"""filters:
  and:
    - 'file.ext == "md"'
    - 'primary_expert == "{expert}"'
    - 'knowledge_type != "review"'
    - 'file.folder != "01 Workbenches"'
views:
  - type: table
    name: Knowledge
    order:
      - file.name
      - knowledge_type
      - status
      - risk_level
      - source_kind
"""


def home(counts: Counter) -> str:
    links = "\n".join(f"- [[01 Workbenches/{EXPERT_SLUG[e]}|{e}]]" for e in EXPERTS)
    return f"""---
title: Knowledge Workbench
knowledge_type: concept
status: evergreen
cssclasses: [knowledge-workbench, workbench-home]
---

# Knowledge Workbench

> [!tip] 下一步
> 從 Review Queue 選一筆來源，核對證據後更新 Review Record；可升級為 Concept、Runbook 或 Case。

## Expert Workbenches

{links}

## Review Queue

![[All Reviews.base#Review Queue]]

## Evidence Gaps

![[All Reviews.base#Evidence Gaps]]

## Pilot Coverage

- sources: {sum(counts.values())}
""" + "\n".join(f"- {expert}: {counts[expert]}" for expert in EXPERTS) + """

## Workflow

`inbox → reviewed → evergreen`

Generated interface layer. Run `make obsidian_pilot_check` before expanding.
"""


def css() -> str:
    return """:root {
  --kb-dba: #164f86;
  --kb-sre: #b35c00;
  --kb-arch: #087f6b;
  --kb-career: #9a6b00;
  --kb-content: #9b3f32;
  --kb-ops: #4b5563;
}
.knowledge-workbench .markdown-preview-sizer,
.knowledge-workbench .cm-sizer { max-width: 980px; }
.knowledge-workbench h1 {
  letter-spacing: -0.035em;
  border-bottom: 3px solid var(--kb-ops);
  padding-bottom: .35rem;
}
.expert-dba h1 { border-color: var(--kb-dba); }
.expert-sre-platform h1 { border-color: var(--kb-sre); }
.expert-solution-architecture h1 { border-color: var(--kb-arch); }
.expert-career-interview h1 { border-color: var(--kb-career); }
.expert-content-production h1 { border-color: var(--kb-content); }
.expert-knowledge-operations h1 { border-color: var(--kb-ops); }
.knowledge-workbench .callout[data-callout="tip"] {
  --callout-color: 8, 127, 107;
}
.knowledge-workbench table { font-size: .88rem; }
.knowledge-workbench .internal-embed { margin-block: .5rem 1.5rem; }
"""


def build(mode: str) -> tuple[dict[Path, str], list[dict], Counter]:
    docs = manifest_docs()
    configs = pilot_config()
    if mode == "full":
        configured = {item["doc_id"]: item for item in configs}
        configs = []
        for doc_id, doc in docs.items():
            cfg = configured.get(doc_id) or {
                "doc_id": doc_id,
                "reason": "Full import; classification requires review",
                "expected_primary_expert": "Knowledge Operations",
                "expected_expert_domains": ["Knowledge Operations"],
            }
            configs.append(cfg)
    chunk_map = chunks_by_doc()
    files: dict[Path, str] = {}
    selected: list[dict] = []
    counts: Counter = Counter()
    for cfg in configs:
        doc_id = cfg["doc_id"]
        if doc_id not in docs:
            raise ValueError(f"pilot doc_id missing from manifest: {doc_id}")
        doc = docs[doc_id]
        source_stem = safe_name(doc["title"], doc_id)
        review_stem = doc_id
        files[Path("90 Sources") / f"{source_stem}.md"] = source_page(
            doc, cfg, chunk_map.get(doc_id, []), review_stem
        )
        selected.append({**doc, **cfg, "source_stem": source_stem, "review_stem": review_stem})
        counts[cfg["expected_primary_expert"]] += 1

    for expert in EXPERTS:
        slug = EXPERT_SLUG[expert]
        files[Path("01 Workbenches") / f"{slug}.md"] = workbench(expert)
        files[Path("Bases") / f"{slug} Review.base"] = base_file(expert)
        files[Path("Bases") / f"{slug} Knowledge.base"] = knowledge_base(expert)
    files[Path("Bases") / "All Reviews.base"] = base_file()
    files[Path("Knowledge Workbench.md")] = home(counts)
    files[Path("10 Maps") / "Pilot Source Catalog.md"] = "# Pilot Source Catalog\n\n" + "\n".join(
        f"- [[{item['source_stem']}|{item['title']}]] · `{item['doc_id']}` · {item['expected_primary_expert']}"
        for item in selected
    ) + "\n"
    return files, selected, counts


def atomic_managed_write(files: dict[Path, str]) -> None:
    temp_root = Path(tempfile.mkdtemp(prefix=".obsidian-build-", dir=VAULT))
    try:
        for rel, content in files.items():
            target = temp_root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8")
        for dirname in MANAGED_DIRS:
            target = VAULT / dirname
            incoming = temp_root / dirname
            backup = VAULT / f".{dirname.replace(' ', '-')}.previous"
            if backup.exists():
                shutil.rmtree(backup)
            if target.exists():
                target.replace(backup)
            incoming.replace(target)
            if backup.exists():
                shutil.rmtree(backup)
        for rel, content in files.items():
            if rel.parts[0] not in MANAGED_DIRS:
                target = VAULT / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(content, encoding="utf-8")
    finally:
        shutil.rmtree(temp_root, ignore_errors=True)


def create_reviews(selected: list[dict]) -> int:
    review_dir = VAULT / "00 Inbox" / "Reviews"
    review_dir.mkdir(parents=True, exist_ok=True)
    created = 0
    for item in selected:
        path = review_dir / f"{item['doc_id']}.md"
        if path.exists():
            continue
        path.write_text(review_record(item, item, item["source_stem"]), encoding="utf-8")
        created += 1
    return created


def hardlink_pdfs(selected: list[dict]) -> int:
    attach = VAULT / "Attachments" / "Sources"
    attach.mkdir(parents=True, exist_ok=True)
    selected_ids = {item["doc_id"] for item in selected}
    for path in attach.glob("*.pdf"):
        if path.stem not in selected_ids:
            path.unlink()
    linked = 0
    for item in selected:
        source = COLLECTOR / f"{item['doc_id']}.pdf"
        target = attach / source.name
        if not source.is_file():
            continue
        if target.exists():
            if os.path.samefile(source, target):
                linked += 1
                continue
            target.unlink()
        os.link(source, target)
        linked += 1
    return linked


def configure_obsidian() -> None:
    settings = VAULT / ".obsidian"
    snippets = settings / "snippets"
    snippets.mkdir(parents=True, exist_ok=True)
    (snippets / "knowledge-workbench.css").write_text(css(), encoding="utf-8")
    (settings / "appearance.json").write_text(json.dumps({
        "baseFontSize": 15,
        "cssTheme": "",
        "enabledCssSnippets": ["knowledge-workbench"],
        "theme": "moonstone",
    }, indent=2) + "\n", encoding="utf-8")
    (settings / "bookmarks.json").write_text(json.dumps({
        "items": [{
            "type": "file",
            "ctime": 1785379200000,
            "path": "Knowledge Workbench.md",
            "title": "Knowledge Workbench",
        }]
    }, indent=2) + "\n", encoding="utf-8")
    plugins_path = settings / "core-plugins.json"
    plugins = json.loads(plugins_path.read_text(encoding="utf-8"))
    if "bases" not in plugins:
        plugins.append("bases")
    plugins_path.write_text(json.dumps(sorted(set(plugins)), indent=2) + "\n", encoding="utf-8")


def import_changes(files: dict[Path, str], selected: list[dict]) -> dict:
    expected = {
        str(rel): content
        for rel, content in files.items()
        if rel.parts[0] == "90 Sources"
    }
    actual = {
        str(path.relative_to(VAULT)): path.read_text(encoding="utf-8")
        for path in (VAULT / "90 Sources").glob("*.md")
    }
    drifts = []
    for item in selected:
        review = VAULT / "00 Inbox" / "Reviews" / f"{item['doc_id']}.md"
        if not review.is_file():
            continue
        meta = frontmatter(review)
        human = meta.get("primary_expert")
        generated = item["expected_primary_expert"]
        if meta.get("classification_source") == "human" and human != generated:
            drifts.append({
                "doc_id": item["doc_id"],
                "human_primary_expert": human,
                "generated_primary_expert": generated,
            })
    return {
        "added": sorted(set(expected) - set(actual)),
        "updated": sorted(
            path for path in set(expected) & set(actual) if expected[path] != actual[path]
        ),
        "deleted": sorted(set(actual) - set(expected)),
        "classification_drift": drifts,
    }


def write_import_report(mode: str, selected: list[dict], changes: dict) -> None:
    report = {
        "schema_version": 1,
        "mode": mode,
        "selected_source_count": len(selected),
        **changes,
    }
    (VAULT / "import_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def frontmatter(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        return {}
    head = text.split("---\n", 2)[1]
    result: dict[str, str] = {}
    for line in head.splitlines():
        match = re.match(r"^([a-z_]+):\s*(.*)$", line)
        if match:
            result[match.group(1)] = match.group(2).strip().strip('"')
    return result


def validate(mode: str, files: dict[Path, str], selected: list[dict]) -> list[str]:
    errors: list[str] = []
    expected_sources = {VAULT / rel for rel in files if rel.parts[0] == "90 Sources"}
    actual_sources = set((VAULT / "90 Sources").glob("*.md"))
    for path in sorted(expected_sources - actual_sources):
        errors.append(f"missing source: {path.relative_to(ROOT)}")
    for path in sorted(actual_sources - expected_sources):
        errors.append(f"unexpected source: {path.relative_to(ROOT)}")
    for rel, content in files.items():
        path = VAULT / rel
        if not path.is_file():
            errors.append(f"missing: {path.relative_to(ROOT)}")
        elif path.read_text(encoding="utf-8") != content:
            errors.append(f"stale: {path.relative_to(ROOT)}")
    for item in selected:
        review = VAULT / "00 Inbox" / "Reviews" / f"{item['doc_id']}.md"
        if not review.is_file():
            errors.append(f"missing review: {item['doc_id']}")
        pdf = VAULT / "Attachments" / "Sources" / f"{item['doc_id']}.pdf"
        if not pdf.is_file():
            errors.append(f"missing PDF hardlink: {item['doc_id']}")
        elif not os.path.samefile(pdf, COLLECTOR / pdf.name):
            errors.append(f"PDF is not hardlinked: {item['doc_id']}")
    for path in (VAULT / "30 Runbooks").glob("*.md"):
        meta = frontmatter(path)
        if meta.get("status") == "evergreen" and meta.get("risk_level") == "high":
            required = ("preconditions", "validation", "rollback", "evidence", "tested_on")
            for field in required:
                if not meta.get(field) or meta[field] in ("[]", '""'):
                    errors.append(f"high-risk gate missing {field}: {path.relative_to(VAULT)}")
            if meta.get("review_status") != "approved":
                errors.append(f"high-risk gate not approved: {path.relative_to(VAULT)}")
    link_targets = {
        path.stem
        for path in VAULT.rglob("*")
        if path.is_file() and path.suffix in (".md", ".base", ".pdf")
    }
    link_pattern = re.compile(r"!?\[\[([^]\n]+)\]\]")
    for path in VAULT.rglob("*.md"):
        for raw in link_pattern.findall(path.read_text(encoding="utf-8")):
            target = raw.split("|", 1)[0].split("#", 1)[0].strip()
            if not target or "{{" in target:
                continue
            if Path(target).stem not in link_targets:
                errors.append(
                    f"ambiguous or missing link: {path.relative_to(VAULT)} -> {target}"
                )
    if mode == "pilot" and len(actual_sources) != 10:
        errors.append(f"pilot requires 10 source pages, found {len(actual_sources)}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("pilot", "full"), default="pilot")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        files, selected, counts = build(args.mode)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    if args.check:
        errors = validate(args.mode, files, selected)
        for error in errors[:80]:
            print(error)
        print(json.dumps({
            "mode": args.mode,
            "sources": len(selected),
            "experts": dict(counts),
            "errors": len(errors),
        }, ensure_ascii=False))
        return 1 if errors else 0
    changes = import_changes(files, selected)
    atomic_managed_write(files)
    created = create_reviews(selected)
    linked = hardlink_pdfs(selected)
    configure_obsidian()
    write_import_report(args.mode, selected, changes)
    print(json.dumps({
        "mode": args.mode,
        "sources": len(selected),
        "review_records_created": created,
        "pdf_hardlinks": linked,
        "experts": dict(counts),
        "changes": {
            "added": len(changes["added"]),
            "updated": len(changes["updated"]),
            "deleted": len(changes["deleted"]),
            "classification_drift": len(changes["classification_drift"]),
        },
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
