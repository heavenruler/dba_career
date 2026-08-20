#!/usr/bin/env python3
"""Build an editable .pptx (with working hyperlinks) from a Marp markdown deck.

Why this exists
---------------
`marp-cli ... -o deck.pptx` rasterises every slide into a PNG
(`ppt/media/Slide-N-image-1.png`). The result has zero text nodes and zero
hyperlinks, so nothing in the deck is clickable or editable in PowerPoint.
This script emits native text frames and tables via python-pptx instead, so
`[label](url)` becomes a real hyperlink relationship.

Use this — not marp-cli — whenever the deck's links need to work.

Usage
-----
    python3 tools/build-slide-pptx.py <input.md> <output.pptx>

    # example
    python3 tools/build-slide-pptx.py \\
        1_MeetingMinutes/0821_slide.md 1_MeetingMinutes/0821_slide.pptx

Requires `python-pptx` (pip install python-pptx).

Supported markdown
------------------
YAML front matter (`header:` / `footer:` are read), `---` slide separators,
`<!-- _class: lead -->` for centred cover/divider slides, `#` titles, tables,
bullet and numbered lists, ```code fences```, `>` blockquote notes, and the
inline spans `**bold**`, `` `code` `` and `[label](url)`.

Links must be absolute URLs: PowerPoint has no base directory, so relative
paths such as `../FOO.md` will not resolve for the reader.
"""
import re
import sys
from pathlib import Path

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.util import Emu, Inches, Pt

if len(sys.argv) != 3:
    sys.exit(f"usage: {Path(sys.argv[0]).name} <input.md> <output.pptx>")

SRC = Path(sys.argv[1])
DST = Path(sys.argv[2])

if not SRC.is_file():
    sys.exit(f"input not found: {SRC}")

FONT = "Microsoft JhengHei"
MONO = "Consolas"
INK = RGBColor(0x22, 0x30, 0x3F)
HEAD = RGBColor(0x1A, 0x2B, 0x3C)
ACCENT = RGBColor(0xC0, 0x39, 0x2B)
MUTED = RGBColor(0x8A, 0x96, 0xA3)
LINK = RGBColor(0x1B, 0x5E, 0xA8)
RULE = RGBColor(0xD6, 0xDC, 0xE3)
BAND = RGBColor(0xF7, 0xF9, 0xFA)
HDRFILL = RGBColor(0xEC, 0xEF, 0xF2)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)

SLIDE_W = Inches(13.333)
SLIDE_H = Inches(7.5)
MARGIN_L = Inches(0.62)
CONTENT_W = SLIDE_W - 2 * MARGIN_L
FOOT_Y = SLIDE_H - Inches(0.62)


# ---------------------------------------------------------------- md parsing
def split_slides(text):
    body = text
    if body.startswith("---"):
        body = body[body.index("\n---", 3) + 4:]
    return [p.strip("\n") for p in re.split(r"\n---[ \t]*\n", body) if p.strip()]


def parse(raw):
    lines = raw.split("\n")
    blocks, i, lead = [], 0, False
    while i < len(lines):
        s = lines[i].strip()
        if not s:
            i += 1
            continue
        if s.startswith("<!--"):
            lead = lead or ("lead" in s)
            i += 1
            continue
        if s.startswith("# "):
            blocks.append(("title", s[2:].strip()))
            i += 1
            continue
        if s.startswith("```"):
            i += 1
            code = []
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code.append(lines[i])
                i += 1
            i += 1
            blocks.append(("code", code))
            continue
        if s.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                r = lines[i].strip()
                i += 1
                if re.match(r"^\|[\s:|-]+\|$", r):
                    continue
                rows.append([c.strip() for c in r.strip("|").split("|")])
            if rows:
                blocks.append(("table", rows))
            continue
        if s.startswith(">"):
            q = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                q.append(lines[i].strip().lstrip(">").strip())
                i += 1
            blocks.append(("note", [x for x in q if x]))
            continue
        if re.match(r"^[-*] ", s):
            it = []
            while i < len(lines) and re.match(r"^[-*] ", lines[i].strip()):
                it.append(lines[i].strip()[2:].strip())
                i += 1
            blocks.append(("bullets", it))
            continue
        if re.match(r"^\d+\. ", s):
            it = []
            while i < len(lines):
                m = re.match(r"^(\d+)\. (.*)$", lines[i].strip())
                if m:
                    it.append(m.group(2).strip())
                    i += 1
                elif lines[i].strip() and lines[i].startswith("   "):
                    it[-1] += "\n" + lines[i].strip()
                    i += 1
                elif not lines[i].strip():
                    i += 1
                    if i < len(lines) and re.match(r"^\d+\. ", lines[i].strip()):
                        continue
                    break
                else:
                    break
            blocks.append(("numbers", it))
            continue
        if re.fullmatch(r"\*\*.+\*\*", s):
            blocks.append(("label", s.strip("*")))
            i += 1
            continue
        blocks.append(("para", s))
        i += 1
    return blocks, lead


# ------------------------------------------------------------- run rendering
TOKEN = re.compile(r"(\[[^\]]+\]\([^)]*\)|\*\*.+?\*\*|`[^`]+`)")


def emit(para, text, size, color=INK, bold=False):
    """Render inline markdown spans as runs; real hyperlinks for [x](url)."""
    for piece in TOKEN.split(text):
        if not piece:
            continue
        m = re.fullmatch(r"\[([^\]]+)\]\(([^)]*)\)", piece)
        if m:
            label, url = m.group(1), m.group(2)
            label = label.replace("**", "").replace("`", "")
            r = para.add_run()
            r.text = label
            r.font.name = FONT
            r.font.size = Pt(size)
            r.font.bold = bold
            if url:
                r.hyperlink.address = url
            r.font.color.rgb = LINK
            r.font.underline = True
            continue
        r = para.add_run()
        r.font.name = FONT
        r.font.size = Pt(size)
        r.font.bold = bold
        r.font.color.rgb = color
        if piece.startswith("**") and piece.endswith("**"):
            r.text = piece[2:-2]
            r.font.bold = True
            r.font.color.rgb = ACCENT
        elif piece.startswith("`") and piece.endswith("`"):
            r.text = piece[1:-1]
            r.font.name = MONO
        else:
            r.text = piece


def box(slide, x, y, w, h):
    tf = slide.shapes.add_textbox(x, y, w, h).text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    return tf


def fill_cell(cell, text, size, bold, align, bg):
    cell.fill.solid()
    cell.fill.fore_color.rgb = bg
    cell.margin_left = cell.margin_right = Inches(0.07)
    cell.margin_top = cell.margin_bottom = Inches(0.035)
    cell.vertical_anchor = MSO_ANCHOR.MIDDLE
    tf = cell.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.alignment = align
    emit(p, text, size, HEAD if bold else INK, bold=bold)


def widths(rows, total):
    n = max(len(r) for r in rows)
    norm = [r + [""] * (n - len(r)) for r in rows]

    def vis(s):
        s = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", s)
        return len(s.replace("**", "").replace("`", ""))

    w = [max(max(vis(r[c]) for r in norm), 4) for c in range(n)]
    tot = sum(w)
    return [int(total * x / tot) for x in w], n, norm


# ---------------------------------------------------------------- build deck
def build():
    prs = Presentation()
    prs.slide_width, prs.slide_height = SLIDE_W, SLIDE_H
    blank = prs.slide_layouts[6]
    md = SRC.read_text()
    header = re.search(r"^header:\s*'(.*)'$", md, re.M)
    footer = re.search(r"^footer:\s*'(.*)'$", md, re.M)
    HDR = header.group(1) if header else ""
    FTR = footer.group(1) if footer else ""

    for idx, raw in enumerate(split_slides(md), start=1):
        blocks, lead = parse(raw)
        s = prs.slides.add_slide(blank)

        if idx > 1 and HDR:
            emit(box(s, MARGIN_L, Inches(0.26), CONTENT_W, Inches(0.3)).paragraphs[0],
                 HDR, 11, MUTED)
        if FTR:
            emit(box(s, MARGIN_L, FOOT_Y, Inches(4), Inches(0.3)).paragraphs[0], FTR, 11, MUTED)
        tf = box(s, SLIDE_W - MARGIN_L - Inches(1), FOOT_Y, Inches(1), Inches(0.3))
        tf.paragraphs[0].alignment = PP_ALIGN.RIGHT
        emit(tf.paragraphs[0], str(idx), 12, MUTED)

        weight = 0
        for k, pl in blocks:
            if k == "table":
                weight += 2 + len(pl)
            elif k in ("bullets", "numbers"):
                weight += sum(2 + len(x) // 46 for x in pl)
            elif k == "code":
                weight += len(pl)
            elif k == "note":
                weight += len(pl)
            elif k in ("para", "label"):
                weight += 1 + len(pl) // 46
        body_sz = 17 if weight >= 18 else (18 if weight >= 13 else 19)
        tbl_sz = 12 if weight >= 18 else (13 if weight >= 13 else 14)

        if lead:
            y = Inches(2.7)
            for k, pl in blocks:
                if k == "title":
                    tf = box(s, MARGIN_L, y, CONTENT_W, Inches(1.1))
                    tf.paragraphs[0].alignment = PP_ALIGN.CENTER
                    emit(tf.paragraphs[0], pl, 30, HEAD, bold=True)
                    y += Inches(1.25)
                elif k in ("para", "label"):
                    tf = box(s, MARGIN_L, y, CONTENT_W, Inches(0.42))
                    tf.paragraphs[0].alignment = PP_ALIGN.CENTER
                    emit(tf.paragraphs[0], pl, 16, MUTED)
                    y += Inches(0.46)
            continue

        y = Inches(0.95)
        for k, pl in blocks:
            if k == "title":
                emit(box(s, MARGIN_L, y, CONTENT_W, Inches(0.62)).paragraphs[0],
                     pl, 25, HEAD, bold=True)
                y += Inches(0.92)

            elif k == "label":
                emit(box(s, MARGIN_L, y, CONTENT_W, Inches(0.34)).paragraphs[0],
                     pl, body_sz, ACCENT, bold=True)
                y += Inches(0.44)

            elif k == "para":
                ln = 1 + len(pl) // 52
                emit(box(s, MARGIN_L, y, CONTENT_W, Inches(0.32 * ln)).paragraphs[0],
                     pl, body_sz)
                y += Inches(0.34 * ln + 0.10)

            elif k in ("bullets", "numbers"):
                h = Inches(0.0)
                tf = box(s, MARGIN_L, y, CONTENT_W, Inches(0.4) * len(pl))
                for n, item in enumerate(pl):
                    parts = item.split("\n")
                    p = tf.paragraphs[0] if n == 0 else tf.add_paragraph()
                    p.space_after = Pt(6)
                    r = p.add_run()
                    r.text = f"{n+1}. " if k == "numbers" else "•  "
                    r.font.name = FONT
                    r.font.size = Pt(body_sz)
                    r.font.color.rgb = MUTED
                    emit(p, parts[0], body_sz)
                    h += Inches(0.34) * (1 + len(parts[0]) // 52)
                    for extra in parts[1:]:
                        p2 = tf.add_paragraph()
                        p2.space_after = Pt(6)
                        rr = p2.add_run()
                        rr.text = "     "
                        rr.font.size = Pt(body_sz)
                        emit(p2, extra, body_sz - 1, MUTED)
                        h += Inches(0.32) * (1 + len(extra) // 54)
                y += h + Inches(0.10)

            elif k == "code":
                h = Inches(0.26) * len(pl) + Inches(0.24)
                bg = s.shapes.add_shape(1, MARGIN_L, y, int(CONTENT_W), int(h))
                bg.fill.solid()
                bg.fill.fore_color.rgb = BAND
                bg.line.color.rgb = RULE
                bg.shadow.inherit = False
                tf = box(s, MARGIN_L + Inches(0.14), y + Inches(0.12),
                         CONTENT_W - Inches(0.28), h - Inches(0.24))
                for n, ln in enumerate(pl):
                    p = tf.paragraphs[0] if n == 0 else tf.add_paragraph()
                    p.space_after = Pt(0)
                    r = p.add_run()
                    r.text = ln if ln.strip() else " "
                    r.font.name = MONO
                    r.font.size = Pt(body_sz - 4)
                    r.font.color.rgb = INK
                y += h + Inches(0.16)

            elif k == "note":
                nl = len(pl)
                tf = box(s, MARGIN_L + Inches(0.14), y + Inches(0.04),
                         CONTENT_W - Inches(0.14), Inches(0.30) * nl)
                for n, q in enumerate(pl):
                    p = tf.paragraphs[0] if n == 0 else tf.add_paragraph()
                    emit(p, q, body_sz - 3, MUTED)
                bar = s.shapes.add_shape(1, MARGIN_L, y + Inches(0.04),
                                         Emu(26000), Inches(0.30) * nl)
                bar.fill.solid()
                bar.fill.fore_color.rgb = RULE
                bar.line.fill.background()
                bar.shadow.inherit = False
                y += Inches(0.32 * nl + 0.16)

            elif k == "table":
                cw, ncol, norm = widths(pl, int(CONTENT_W))
                nrow = len(norm)
                rh = Inches(0.38)
                tbl = s.shapes.add_table(nrow, ncol, MARGIN_L, y,
                                         int(CONTENT_W), rh * nrow).table
                tbl.first_row = True
                for c in range(ncol):
                    tbl.columns[c].width = cw[c]
                for r in range(nrow):
                    tbl.rows[r].height = rh
                    for c in range(ncol):
                        txt = norm[r][c]
                        hd = (r == 0)
                        plain = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", txt).replace("**", "")
                        al = PP_ALIGN.CENTER if (hd or len(plain) <= 13) else PP_ALIGN.LEFT
                        bg = HDRFILL if hd else (BAND if r % 2 == 0 else WHITE)
                        fill_cell(tbl.cell(r, c), txt, tbl_sz, hd, al, bg)
                y += rh * nrow + Inches(0.20)

    prs.save(DST)
    print(f"wrote {DST}")


build()
