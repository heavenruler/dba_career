#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "output_with_md5.txt"
COLLECTOR_DIR = ROOT / "collector"
EXTRACTED_DIR = ROOT / "generated" / "extracted"
FILTERED_DIR = ROOT / "generated" / "filtered"
DATA_DIR = ROOT / "generated" / "kb"
CHUNKS_PATH = DATA_DIR / "chunks.jsonl"
DOCUMENTS_PATH = DATA_DIR / "documents.jsonl"
MISSING_PATH = DATA_DIR / "missing_documents.jsonl"

MIN_CHUNK_CHARS = 350
MAX_CHUNK_CHARS = 900
OVERLAP_CHARS = 120
SENTENCE_END = re.compile(r"[。！？!?;；]\s*|\n{2,}")
FRONTMATTER_RE = re.compile(r"\A---\n.*?\n---\n", re.DOTALL)
PAGE_MARKER_RE = re.compile(r"<!--\s*page:(\d+)\s*-->")


CATEGORY_RULES = [
    ("SQL 與查詢優化", ["sql", "查詢", "query", "explain", "索引", "index", "join", "group by", "order by", "limit", "慢sql", "slow sql"]),
    ("InnoDB 核心原理", ["innodb", "mvcc", "b+tree", "b-tree", "undo", "redo", "buffer pool", "change buffer", "ahi", "自適應哈希", "鎖", "deadlock", "死鎖"]),
    ("高可用與複製", ["高可用", "ha", "主從", "复制", "複製", "replication", "mgr", "mha", "orchestrator", "raft", "gtid", "binlog", "跨可用区", "跨可用區"]),
    ("備份恢復與容災", ["備份", "backup", "恢復", "恢复", "recovery", "xtrabackup", "clone", "容災", "灾备", "disaster"]),
    ("監控與故障處理", ["監控", "monitor", "grafana", "performance schema", "pfs", "故障", "troubleshooting", "報錯", "报错", "error", "core", "gdb", "告警"]),
    ("安全與權限", ["安全", "security", "權限", "权限", "grant", "role", "tls", "ssl", "認證", "认证", "sql注入", "injection"]),
    ("部署升級與配置", ["部署", "安裝", "安装", "docker", "kubernetes", "k8s", "升級", "升级", "配置", "參數", "参数", "install"]),
    ("資料遷移與同步", ["遷移", "迁移", "同步", "cdc", "debezium", "資料比對", "数据比对", "tidb", "polardb", "迁库"]),
    ("架構案例與分庫分表", ["架構", "架构", "分庫", "分库", "分表", "高并发", "高併發", "qps", "億級", "亿级", "流量", "案例"]),
    ("培訓與參考", ["培訓", "培训", "認證", "认证", "ocp", "1z0", "課程", "课程", "合集", "汇总"]),
]

CHUNK_TYPE_RULES = [
    ("command", [r"\b(mysqldump|pt-[a-z-]+|xtrabackup|kubectl|docker|systemctl|grep|awk|sed)\b", r"^\s*\$ "]),
    ("sql", [r"\b(select|insert|update|delete|alter|create|drop|show|explain)\b", r"\bwhere\b", r"\bfrom\b"]),
    ("config", [r"\binnodb_[a-z0-9_]+\b", r"\b[a-z0-9_]+\s*=\s*[^,\s]+"]),
    ("problem", ["問題", "问题", "現象", "现象", "报错", "報錯", "故障", "失败", "失敗"]),
    ("root_cause", ["原因", "根因", "root cause", "為什麼", "为什么"]),
    ("solution", ["解決", "解决", "方案", "修復", "修复", "處理", "处理", "優化", "优化"]),
    ("warning", ["注意", "風險", "风险", "避免", "不要", "慎用"]),
    ("checklist", ["步驟", "步骤", "檢查", "检查", "確認", "确认"]),
]

NOISE_PATTERNS = [
    r"^\s*京东\s*$",
    r"^\s*京東\s*$",
    r"^\s*广告\s*$",
    r"^\s*廣告\s*$",
    r"^\s*京东配送\s*$",
    r"^\s*京東配送\s*$",
    r"^\s*[¥￥]\s*\d+(?:\.\d+)?\s*购买\s*$",
    r"^\s*\d+\s*元券\s*$",
    r"^\s*喜欢作者\s*$",
    r"^\s*喜歡作者\s*$",
    r"^\s*[“\"]?\s*欢迎转发打赏\s*[”\"]?\s*$",
    r"^\s*[“\"]?\s*歡迎轉發打賞\s*[”\"]?\s*$",
    r"^\s*\d+\s*篇原创内容\s*$",
    r"^\s*\d+\s*篇原創內容\s*$",
    r"^\s*公众号\s*$",
    r"^\s*公眾號\s*$",
    r"^\s*探\s*索\s*稀\s*.*掘\s*.*\s*$",
    r"^\s*登.*[首⾸].*[页頁⻚]\s*$",
    r"^\s*标签[:：].*$",
    r"^\s*評論\s*\d+\s*$",
    r"^\s*评论\s*\d+\s*$",
    r"^\s*暂无评论数据\s*$",
    r"^\s*暫無評論資料\s*$",
    r"^\s*登录\s*/\s*注册.*$",
    r"^\s*登入\s*/\s*註冊.*$",
    r"^\s*上一篇\s+.*下一篇\s+.*$",
    r"^\s*本[文⽂]收录于以下专栏\s*$",
    r"^\s*\d+/\s*\d+\s*发送\s*$",
    r"^\s*https?://\S+\s+\d+/\d+\s*$",
    r"^\s*\d{4}/\d{1,2}/\d{1,2}\s+.+\s+\d+/\d+\s*$",
    r"^\s*\d{4}/\d{1,2}/\d{1,2}\s+(凌晨|上午|下午|晚上).*$",
]


def parse_manifest() -> list[dict]:
    if not MANIFEST_PATH.exists():
        raise FileNotFoundError(f"Missing {MANIFEST_PATH}")

    lines = MANIFEST_PATH.read_text(encoding="utf-8").splitlines()
    docs = []
    block = []
    for line in lines:
        if line.strip() == "----":
            add_manifest_block(block, docs)
            block = []
        else:
            block.append(line)
    add_manifest_block(block, docs)
    return docs


def add_manifest_block(block: list[str], docs: list[dict]) -> None:
    if len(block) < 3:
        return
    title = block[0].strip()
    url = block[1].strip()
    md5 = block[2].strip()
    if title and url and re.fullmatch(r"[0-9a-f]{32}", md5):
        docs.append({"doc_id": md5, "title": title, "url": url})


def extracted_source_md(doc_id: str) -> Path | None:
    full_md = EXTRACTED_DIR / doc_id / "full.md"
    if full_md.exists():
        return full_md
    return None


def filtered_source_json(doc_id: str) -> Path | None:
    knowledge_json = FILTERED_DIR / doc_id / "knowledge.json"
    if knowledge_json.exists():
        return knowledge_json
    return None


def text_from_filtered_knowledge(path: Path) -> tuple[str, dict]:
    knowledge = json.loads(path.read_text(encoding="utf-8"))
    parts = []
    if knowledge.get("summary"):
        parts.append(f"# 摘要\n\n{knowledge['summary']}")
    for section in knowledge.get("sections", []):
        heading = section.get("heading") or section.get("section_type") or "有效知識"
        content = section.get("content") or ""
        if content.strip():
            parts.append(f"# {heading}\n\n{content.strip()}")
    return "\n\n".join(parts).strip(), knowledge


def strip_frontmatter(text: str) -> str:
    return FRONTMATTER_RE.sub("", text, count=1)


def page_for_position(page_offsets: list[tuple[int, int]], position: int) -> int | None:
    """Return the page number whose [start,end) range contains position."""
    if not page_offsets:
        return None
    result = page_offsets[0][0]
    for page_no, start in page_offsets:
        if start <= position:
            result = page_no
        else:
            break
    return result


def page_offsets_from_text(text: str) -> list[tuple[int, int]]:
    """List of (page_no, char_offset) for every page marker found."""
    return [(int(m.group(1)), m.start()) for m in PAGE_MARKER_RE.finditer(text)]


def clean_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"\n{3,}", "\n\n", text)

    clean_lines = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            clean_lines.append("")
            continue
        if any(re.search(pattern, line, flags=re.IGNORECASE) for pattern in NOISE_PATTERNS):
            continue
        clean_lines.append(raw_line.rstrip())

    cleaned = "\n".join(clean_lines)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    return cleaned.strip()


def split_paragraphs(text: str) -> list[str]:
    paragraphs = []
    current = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            if current:
                paragraphs.append("\n".join(current).strip())
                current = []
            continue
        if re.match(r"^#{1,6}\s+\S+", stripped) and current:
            paragraphs.append("\n".join(current).strip())
            current = [stripped]
        else:
            current.append(line.rstrip())
    if current:
        paragraphs.append("\n".join(current).strip())
    return [p for p in paragraphs if p]


def safe_overlap(tail: str) -> str:
    """Trim overlap to start after the nearest sentence boundary."""
    if not tail:
        return ""
    match = list(SENTENCE_END.finditer(tail))
    if not match:
        return tail.strip()
    boundary = match[0].end()
    return tail[boundary:].strip()


def chunk_text(text: str) -> list[str]:
    paragraphs = split_paragraphs(text)
    chunks = []
    current = ""

    for paragraph in paragraphs:
        candidate = paragraph if not current else f"{current}\n\n{paragraph}"
        if len(candidate) <= MAX_CHUNK_CHARS or len(current) < MIN_CHUNK_CHARS:
            current = candidate
            continue

        chunks.append(current.strip())
        overlap = safe_overlap(current[-OVERLAP_CHARS * 2:])
        current = f"{overlap}\n\n{paragraph}" if overlap else paragraph

    if current.strip():
        chunks.append(current.strip())

    return chunks


def classify(text: str, title: str) -> tuple[str, list[str], float]:
    haystack = f"{title}\n{text}".lower()
    scores = []
    for category, keywords in CATEGORY_RULES:
        score = sum(1 for keyword in keywords if keyword.lower() in haystack)
        if score:
            scores.append((score, category))

    if not scores:
        return "待審核", [], 0.2

    scores.sort(reverse=True)
    category = scores[0][1]
    tags = []
    for _, matched_category in scores[:3]:
        if matched_category != category:
            tags.append(matched_category)
    confidence = min(0.95, 0.45 + scores[0][0] * 0.1)
    return category, tags, confidence


def detect_chunk_types(text: str) -> list[str]:
    lowered = text.lower()
    types = []
    for chunk_type, patterns in CHUNK_TYPE_RULES:
        for pattern in patterns:
            if re.search(pattern, lowered, flags=re.IGNORECASE | re.MULTILINE):
                types.append(chunk_type)
                break
    return types or ["concept"]


def content_hash(text: str) -> str:
    return hashlib.md5(text.encode("utf-8")).hexdigest()


def source_domain(url: str) -> str:
    return urlparse(url).netloc.lower()


def quality_for(text: str) -> str:
    if len(text) < 300:
        return "low_content"
    if len(text) < 800:
        return "short"
    return "ok"


def write_jsonl(path: Path, rows: list[dict]) -> None:
    with path.open("w", encoding="utf-8") as file:
        for row in rows:
            file.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")


def title_from_text(text: str, fallback: str) -> str:
    for line in text.splitlines():
        stripped = line.strip().lstrip("#").strip()
        if len(stripped) >= 4:
            return stripped[:120]
    return fallback


def build_records_for_document(doc: dict, source_path: Path, source_pdf: Path | None, status: str = "ok") -> tuple[dict, list[dict]]:
    filtered_metadata = None
    page_offsets: list[tuple[int, int]] = []
    if source_path.suffix == ".json":
        raw_text, filtered_metadata = text_from_filtered_knowledge(source_path)
        text = clean_text(raw_text)
    else:
        raw_text = source_path.read_text(encoding="utf-8", errors="replace")
        raw_text = strip_frontmatter(raw_text)
        page_offsets = page_offsets_from_text(raw_text)
        text = clean_text(raw_text)

    title = (filtered_metadata or {}).get("title") or doc.get("title") or title_from_text(text, doc["doc_id"])
    category, tags, confidence = classify(text[:5000], title)
    if filtered_metadata:
        tags = sorted(set(tags + filtered_metadata.get("tags", [])))
        confidence = max(confidence, 0.9)
    quality = quality_for(text)
    url = doc.get("url")

    base_record = {
        "doc_id": doc["doc_id"],
        "title": title,
        "url": url,
        "source_domain": source_domain(url) if url else None,
        "source_pdf": str(source_pdf.relative_to(ROOT)) if source_pdf and source_pdf.exists() else None,
        "source_content": str(source_path.relative_to(ROOT)),
        "source_kind": "llm_filtered" if filtered_metadata else "extracted_text",
        "status": status,
    }

    document_record = {
        **base_record,
        "primary_category": category,
        "tags": tags,
        "classification_confidence": confidence,
        "quality": quality,
        "char_count": len(text),
        "content_hash": content_hash(text),
    }

    chunk_records = []
    cursor = 0
    for index, chunk in enumerate(chunk_text(text), start=1):
        chunk_category, chunk_tags, chunk_confidence = classify(chunk, title)
        page_start = page_end = None
        if page_offsets:
            search_from = text.find(chunk[:60], cursor) if len(chunk) >= 60 else -1
            if search_from < 0:
                search_from = cursor
            page_start = page_for_position(page_offsets, search_from)
            page_end = page_for_position(page_offsets, search_from + len(chunk))
            cursor = search_from + len(chunk)
        chunk_records.append({
            **base_record,
            "chunk_id": f"{doc['doc_id']}:{index:04d}",
            "chunk_index": index,
            "content": chunk,
            "content_hash": content_hash(chunk),
            "page_start": page_start,
            "page_end": page_end,
            "primary_category": chunk_category if chunk_category != "待審核" else category,
            "tags": sorted(set(tags + chunk_tags)),
            "chunk_types": detect_chunk_types(chunk),
            "classification_confidence": max(confidence, chunk_confidence),
            "quality": quality_for(chunk),
            "char_count": len(chunk),
        })

    return document_record, chunk_records


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build knowledge-base chunks from collector/imported full.md files.")
    parser.add_argument("--doc-id", help="Only rebuild one 32-character document id.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    manifest_docs = parse_manifest()
    documents = []
    chunks = []
    missing = []

    for doc in manifest_docs:
        doc_id = doc["doc_id"]
        if args.doc_id and doc_id != args.doc_id:
            continue
        source_content = filtered_source_json(doc_id) or extracted_source_md(doc_id)
        source_pdf = COLLECTOR_DIR / f"{doc_id}.pdf"

        base_record = {
            **doc,
            "source_domain": source_domain(doc["url"]),
            "source_pdf": str(source_pdf.relative_to(ROOT)) if source_pdf.exists() else None,
            "source_content": str(source_content.relative_to(ROOT)) if source_content else None,
        }

        if source_content is None:
            missing.append({**base_record, "status": "missing_full_md"})
            continue

        document_record, chunk_records = build_records_for_document(doc, source_content, source_pdf)
        documents.append(document_record)
        chunks.extend(chunk_records)

    write_jsonl(DOCUMENTS_PATH, documents)
    write_jsonl(CHUNKS_PATH, chunks)
    write_jsonl(MISSING_PATH, missing)

    print(f"documents: {len(documents)} -> {DOCUMENTS_PATH.relative_to(ROOT)}")
    print(f"chunks: {len(chunks)} -> {CHUNKS_PATH.relative_to(ROOT)}")
    print(f"missing: {len(missing)} -> {MISSING_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
