#!/usr/bin/env python3
"""Generate SVG charts for the GitBook from tracked summary.json files.

Zero-dependency (stdlib only). Every chart footer carries N=1 caveat,
source paths and generation date so the images stay traceable like the text.

Usage: python3 charts.py   (or `make charts` from gitbook/)
Output: gitbook/assets/charts/*.svg
"""

from __future__ import annotations

import json
import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
OUT = ROOT / "assets" / "charts"

# Vendor-neutral palette (colorblind-safe)
COLORS = {"TiDB": "#4e79a7", "CockroachDB": "#59a14f", "YugabyteDB": "#f28e2b"}
GREY = "#666666"
LIGHT = "#e0e0e0"

SBASE = {
    "TiDB": "results/tidb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc-pd-sched-l4r4/tidb-vm-3node-haproxy-3s3r-rc-20260601T003316+0800/summary.json",
    "CockroachDB": "results/crdb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/crdb-vm-3node-haproxy-3s3r-rc-20260602T051500+0800/summary.json",
    "YugabyteDB": "results/yuga-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/summary.json",
}
SK8S = {
    "TiDB": {
        "limit": "results/tidb-tc1/S-K8S/tidb-k8s-3node-haproxy-3s3r-limit-rc-20260608T210453+0800/summary.json",
        "unlimit": "results/tidb-tc1/S-K8S/tidb-k8s-3node-haproxy-3s3r-unlimit-rc-20260608T165403+0800/summary.json",
    },
    "CockroachDB": {
        "limit": "results/crdb-tc1/S-K8S/crdb-k8s-3node-haproxy-3s3r-limit-rc-20260611T132715+0800/summary.json",
        "unlimit": "results/crdb-tc1/S-K8S/crdb-k8s-3node-haproxy-3s3r-unlimit-rc-20260609T065714+0800/summary.json",
    },
    "YugabyteDB": {
        "limit": "results/yuga-tc1/S-K8S/ybdb-k8s-3node-haproxy-3s3r-limit-rc-20260613T233549+0800/summary.json",
        "unlimit": "results/yuga-tc1/S-K8S/ybdb-k8s-3node-haproxy-3s3r-unlimit-rc-20260612T120138+0800/summary.json",
    },
}
XCROSS = {
    "2026-07-03 正式 cell": "results/x-cross/baseline/w128/20260703T092243+0800/tidb-vm-6node-P-A-rc-20260703T092243+0800/summary.json",
    "2026-07-11 首輪（不採用）": "results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/summary.json",
    "2026-07-12 重跑（採用）": "results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/summary.json",
}

THREADS = ["16", "32", "64", "128"]


def load(rel: str) -> dict:
    return json.loads((REPO / rel).read_text())


def esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


class Svg:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.parts = [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
            f'viewBox="0 0 {w} {h}" font-family="Helvetica,Arial,sans-serif">',
            f'<rect width="{w}" height="{h}" fill="white"/>',
        ]

    def text(self, x, y, s, size=12, fill="#222", anchor="start", weight="normal", rotate=None):
        t = f'transform="rotate({rotate} {x} {y})" ' if rotate is not None else ""
        self.parts.append(
            f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" fill="{fill}" '
            f'text-anchor="{anchor}" font-weight="{weight}" {t}>{esc(str(s))}</text>'
        )

    def rect(self, x, y, w, h, fill, opacity=1.0):
        self.parts.append(
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" '
            f'fill="{fill}" opacity="{opacity}"/>'
        )

    def line(self, x1, y1, x2, y2, stroke=GREY, width=1, dash=None):
        d = f'stroke-dasharray="{dash}" ' if dash else ""
        self.parts.append(
            f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
            f'stroke="{stroke}" stroke-width="{width}" {d}/>'
        )

    def polyline(self, pts, stroke, width=2, dash=None):
        d = f'stroke-dasharray="{dash}" ' if dash else ""
        p = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        self.parts.append(
            f'<polyline points="{p}" fill="none" stroke="{stroke}" stroke-width="{width}" {d}/>'
        )

    def circle(self, x, y, r, fill):
        self.parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{fill}"/>')

    def save(self, name: str, sources: list[str], caveat: str):
        y = self.h - 14 - 11 * len(sources) - 14
        self.text(12, y, caveat, size=10, fill=GREY)
        for i, src in enumerate(sources):
            self.text(12, y + 14 + i * 11, f"來源: {src}", size=9, fill=GREY)
        self.parts.append("</svg>")
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT / name).write_text("\n".join(self.parts), encoding="utf-8")
        print(f"wrote {OUT.relative_to(ROOT)}/{name}")


def nice_max(v: float) -> float:
    import math
    mag = 10 ** math.floor(math.log10(v))
    for m in (1, 2, 2.5, 5, 10):
        if v <= m * mag:
            return m * mag
    return 10 * mag


def panel_bars(svg, x0, y0, pw, ph, labels, values, colors, title, unit, annotate):
    vmax = nice_max(max(values) * 1.05)
    svg.text(x0 + pw / 2, y0 - 10, title, size=13, anchor="middle", weight="bold")
    for frac in (0, 0.25, 0.5, 0.75, 1.0):
        gy = y0 + ph - ph * frac
        svg.line(x0, gy, x0 + pw, gy, stroke=LIGHT)
        svg.text(x0 - 6, gy + 4, f"{vmax * frac:,.0f}", size=10, fill=GREY, anchor="end")
    n = len(values)
    slot = pw / n
    bw = slot * 0.55
    for i, (lab, val, col) in enumerate(zip(labels, values, colors)):
        bx = x0 + slot * i + (slot - bw) / 2
        bh = ph * val / vmax
        svg.rect(bx, y0 + ph - bh, bw, bh, col)
        svg.text(bx + bw / 2, y0 + ph - bh - 5, f"{val:,.0f}", size=11, anchor="middle", weight="bold")
        svg.text(bx + bw / 2, y0 + ph + 15, lab, size=11, anchor="middle")
        if annotate:
            svg.text(bx + bw / 2, y0 + ph + 29, annotate[i], size=10, anchor="middle", fill=GREY)
    svg.text(x0 - 6, y0 - 10, unit, size=10, fill=GREY, anchor="end")


def chart_sbase_t128():
    data = {db: load(p) for db, p in SBASE.items()}
    dbs = list(data)
    tpmc = [data[d]["thread_results"]["128"]["tpmC_mean"] for d in dbs]
    p99 = [data[d]["thread_results"]["128"]["NEW_ORDER"]["p99_mean_ms"] for d in dbs]
    svg = Svg(880, 440)
    svg.text(430, 24, "S-BASE 單區 VM 三節點・t=128・R1-R5 mean（非跨引擎勝負表）",
             size=15, anchor="middle", weight="bold")
    cols = [COLORS[d] for d in dbs]
    panel_bars(svg, 70, 70, 330, 250, dbs, tpmc, cols, "tpmC（越高越好）", "tpmC", None)
    panel_bars(svg, 490, 70, 330, 250, dbs, p99, cols, "NEW_ORDER p99 ms（越低越好）", "ms", None)
    svg.save(
        "sbase-t128-tpmc-p99.svg",
        [f"{db}: {p}" for db, p in SBASE.items()],
        "N=1（單次完整流程）・error rate 0%・tpmC 與 p99 必須成對解讀，不構成排名或 SLA",
    )


def chart_sbase_scaling():
    data = {db: load(p) for db, p in SBASE.items()}
    svg = Svg(880, 460)
    svg.text(430, 24, "S-BASE thread scaling（t16→t128）・R1-R5 mean", size=15, anchor="middle", weight="bold")

    def draw_lines(x0, y0, pw, ph, metric, title, fmt):
        vals = {db: [metric(data[db]["thread_results"][t]) for t in THREADS] for db in data}
        vmax = nice_max(max(max(v) for v in vals.values()) * 1.05)
        svg.text(x0 + pw / 2, y0 - 10, title, size=13, anchor="middle", weight="bold")
        for frac in (0, 0.5, 1.0):
            gy = y0 + ph - ph * frac
            svg.line(x0, gy, x0 + pw, gy, stroke=LIGHT)
            svg.text(x0 - 6, gy + 4, f"{vmax * frac:,.0f}", size=10, fill=GREY, anchor="end")
        xs = [x0 + pw * i / (len(THREADS) - 1) for i in range(len(THREADS))]
        for i, t in enumerate(THREADS):
            svg.text(xs[i], y0 + ph + 15, f"t{t}", size=11, anchor="middle")
        # 端點標籤依終值排序錯開，避免數值相近時互相重疊
        order = sorted(vals, key=lambda db: vals[db][-1])
        for db, series in vals.items():
            pts = [(xs[i], y0 + ph - ph * v / vmax) for i, v in enumerate(series)]
            svg.polyline(pts, COLORS[db])
            for (px, py), v in zip(pts, series):
                svg.circle(px, py, 3.5, COLORS[db])
            nudge = (order.index(db) - 1) * 12
            svg.text(pts[-1][0] + 6, pts[-1][1] + 4 + nudge, fmt(series[-1]), size=10, fill=COLORS[db])

    draw_lines(70, 80, 300, 250, lambda r: r["tpmC_mean"], "tpmC", lambda v: f"{v:,.0f}")
    draw_lines(490, 80, 300, 250, lambda r: r["NEW_ORDER"]["p99_mean_ms"],
               "NEW_ORDER p99 (ms)", lambda v: f"{v:,.0f}")
    lx = 70
    for db in data:
        svg.rect(lx, 44, 14, 10, COLORS[db])
        svg.text(lx + 19, 53, db, size=11)
        lx += 150
    svg.save(
        "sbase-thread-scaling.svg",
        [f"{db}: {p}" for db, p in SBASE.items()],
        "N=1・同 scope 內比較 thread 水位形狀；不可外推容量或跨 scope 比較",
    )


def chart_sk8s():
    svg = Svg(880, 460)
    svg.text(430, 24, "S-K8S limit vs unlimit・t=128・R1-R5 mean", size=15, anchor="middle", weight="bold")
    dbs = list(SK8S)
    labels, tpmc, p99, cols, ann = [], [], [], [], []
    srcs = []
    for db in dbs:
        for mode in ("limit", "unlimit"):
            d = load(SK8S[db][mode])
            r = d["thread_results"]["128"]
            labels.append(mode)
            tpmc.append(r["tpmC_mean"])
            p99.append(r["NEW_ORDER"]["p99_mean_ms"])
            cols.append(COLORS[db] if mode == "unlimit" else COLORS[db] + "99")
            ann.append(db if mode == "limit" else "")
            srcs.append(f"{db} {mode}: {SK8S[db][mode]}")
    panel_bars(svg, 70, 80, 330, 240, labels, tpmc, cols, "tpmC（越高越好）", "tpmC", ann)
    panel_bars(svg, 490, 80, 330, 240, labels, p99, cols, "NEW_ORDER p99 ms（越低越好）", "ms", ann)
    svg.save(
        "sk8s-limit-vs-unlimit.svg",
        srcs,
        "N=1・limit/unlimit 是資源宣告控制變數對照，不是產品屬性；throttling/OOM 根因需另證",
    )


def chart_xcross_rounds():
    svg = Svg(880, 470)
    svg.text(430, 24, "X-CROSS TiDB P-A/A-S W=128・t=128 逐輪 tpmC（穩定性檢視）",
             size=15, anchor="middle", weight="bold")
    groups = {label: load(p) for label, p in XCROSS.items()}
    all_vals = [v for d in groups.values() for v in d["thread_results"]["128"]["tpmC_per_round"]]
    vmax = nice_max(max(all_vals) * 1.05)
    x0, y0, pw, ph = 70, 70, 760, 270
    for frac in (0, 0.25, 0.5, 0.75, 1.0):
        gy = y0 + ph - ph * frac
        svg.line(x0, gy, x0 + pw, gy, stroke=LIGHT)
        svg.text(x0 - 6, gy + 4, f"{vmax * frac:,.0f}", size=10, fill=GREY, anchor="end")
    gslot = pw / len(groups)
    palette = ["#4e79a7", "#b07aa1", "#76b7b2"]
    for gi, (label, d) in enumerate(groups.items()):
        r = d["thread_results"]["128"]
        rounds = r["tpmC_per_round"]
        cv = r["tpmC_range_mean_pct"]
        col = palette[gi]
        bw = gslot * 0.8 / len(rounds)
        gx = x0 + gslot * gi + gslot * 0.1
        for i, v in enumerate(rounds):
            bh = ph * v / vmax
            svg.rect(gx + i * bw, y0 + ph - bh, bw * 0.85, bh, col,
                     opacity=0.55 if "不採用" in label else 1.0)
        svg.text(gx + gslot * 0.4, y0 + ph + 16, label, size=11, anchor="middle")
        svg.text(gx + gslot * 0.4, y0 + ph + 31,
                 f"mean {r['tpmC_mean']:,.0f}・CV {cv}%", size=10, anchor="middle", fill=GREY)
    svg.text(x0 - 6, y0 - 10, "tpmC", size=10, fill=GREY, anchor="end")
    svg.save(
        "xcross-w128-tidb-rounds.svg",
        [f"{label}: {p}" for label, p in XCROSS.items()],
        "各組皆 N=1・每組 5 根 = R1-R5・首輪 CV 102.2% 經重跑判定為單次環境雜訊（不可重現）",
    )


def main():
    chart_sbase_t128()
    chart_sbase_scaling()
    chart_sk8s()
    chart_xcross_rounds()
    print(f"done at {datetime.date.today().isoformat()}")


if __name__ == "__main__":
    main()
