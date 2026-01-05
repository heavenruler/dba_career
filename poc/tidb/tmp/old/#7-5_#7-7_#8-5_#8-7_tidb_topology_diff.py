#!/usr/bin/env python3
"""
Topology difference comparison for TiDB multi_thread_multi_conn RPS.

(Updated) 預設不顯示百分比；若要顯示需加參數：
  --show-delta-columns   顯示百分比欄位
  --show-delta-annot     圖上顯示百分比標註

原百分比定義保持不變。
"""
from __future__ import annotations
import argparse

# Topology A (IDC *1 + GCP *2)
IDC_A = [
    (1,    655.42), (100, 3245.01), (200, 4910.52), (250, 3435.43), (500, 4392.55), (750, 2743.21), (1000,1885.80),
]
GCP_A = [
    (1,    873.23), (100, 2811.40), (200, 5264.86), (250, 2572.56), (500, 4257.80), (750, 1928.54), (1000,3170.67),
]
# Topology B (IDC *2 + GCP *1)
IDC_B = [
    (1,    701.65), (100, 4071.64), (200, 7797.52), (250, 3541.41), (500, 6427.14), (750, 2790.56), (1000,4546.69),
]
GCP_B = [
    (1,    950.96), (100, 2405.80), (200, 3047.46), (250, 2266.70), (500, 2663.84), (750, 1732.99), (1000,2211.28),
]
PNG_NAME = "#7-5_#7-7_#8-5_#8-7_tidb_topology_diff.png"


def pct(a, b):
    if b == 0:
        return 0.0
    return (a - b) / b * 100.0


def mp(rows):
    return {t: r for t, r in rows}


def build():
    idc_a = mp(IDC_A); gcp_a = mp(GCP_A); idc_b = mp(IDC_B); gcp_b = mp(GCP_B)
    threads = sorted(set(idc_a) & set(gcp_a) & set(idc_b) & set(gcp_b))
    rows = []
    for t in threads:
        ia, ga, ib, gb = idc_a[t], gcp_a[t], idc_b[t], gcp_b[t]
        rows.append((
            t,
            ia, ib, pct(ib, ia),
            ga, gb, pct(gb, ga),
            ia/ga if ga else 0.0,
            ib/gb if gb else 0.0,
            pct((ib/gb) if gb else 0.0, (ia/ga) if ga else 0.0) if ga and gb else 0.0,
        ))
    return rows


def table(rows, show_delta_columns: bool = False):  # default False now
    if show_delta_columns:
        headers = ["Threads","IDC_A","IDC_B","ΔIDC_B_vs_A%","GCP_A","GCP_B","ΔGCP_B_vs_A%","IDC_A/GCP_A","IDC_B/GCP_B","Δ(IDC/GCP)%"]
    else:
        headers = ["Threads","IDC_A","IDC_B","GCP_A","GCP_B","IDC_A/GCP_A","IDC_B/GCP_B"]
    w = [len(h) for h in headers]
    for r in rows:
        vals = ([r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]] if show_delta_columns else [r[0], r[1], r[2], r[4], r[5], r[7], r[8]])
        for i, v in enumerate(vals):
            s = f"{v:.2f}" if isinstance(v, float) and (not show_delta_columns or i not in (3,6,9)) else (f"{v:.1f}" if isinstance(v, float) and show_delta_columns and i in (3,6,9) else str(v))
            w[i] = max(w[i], len(s))
    def fmt(v, i):
        if isinstance(v, float):
            return (f"{v:.2f}" if (not show_delta_columns or i not in (3,6,9)) else f"{v:.1f}").rjust(w[i])
        return str(v).rjust(w[i])
    print(" | ".join(headers[i].ljust(w[i]) for i in range(len(headers))))
    print("-+-".join('-'*width for width in w))
    for r in rows:
        vals = ([r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]] if show_delta_columns else [r[0], r[1], r[2], r[4], r[5], r[7], r[8]])
        print(" | ".join(fmt(vals[i], i) for i in range(len(headers))))


def summarize(rows, show_delta: bool = False):  # default False now
    lines = ["=== SUMMARY (繁體中文) ==="]
    baseline_line = "基準 = 拓撲 A 同一 threads 的 RPS/比值。" + ("(已隱藏 Δ% 欄位)" if not show_delta else "")
    lines.append(baseline_line)
    focus = [100,200,250,500,750,1000]
    lines.append("重點 threads:")
    for ft in focus:
        r = next((x for x in rows if x[0]==ft), None)
        if r:
            t, ia, ib, d_i, ga, gb, d_g, ra, rb, d_r = r
            if show_delta:
                lines.append(f" {t:>4}: IDC {ia:.0f}->{ib:.0f} ({d_i:+5.1f}%) ; GCP {ga:.0f}->{gb:.0f} ({d_g:+5.1f}%) ; Ratio {ra:.2f}->{rb:.2f} ({d_r:+5.1f}%)")
            else:
                lines.append(f" {t:>4}: IDC {ia:.0f}->{ib:.0f} ; GCP {ga:.0f}->{gb:.0f} ; Ratio {ra:.2f}->{rb:.2f}")
    lines.append("觀察: 預設已隱藏百分比 (避免誤解)。使用 --show-delta-columns / --show-delta-annot 以檢視變動幅度。")
    return "\n".join(lines)


def plot(rows, annotate_deltas: bool = False):  # default False now
    try:
        import matplotlib.pyplot as plt, numpy as np
    except Exception:
        print("[WARN] matplotlib/numpy not available; skip plot.")
        return False
    threads = [r[0] for r in rows]
    idc_a = [r[1] for r in rows]; idc_b = [r[2] for r in rows]; d_idc = [r[3] for r in rows]
    gcp_a = [r[4] for r in rows]; gcp_b = [r[5] for r in rows]; d_gcp = [r[6] for r in rows]
    x = np.arange(len(threads)); width = 0.2
    fig, ax = plt.subplots(figsize=(12,5.4))
    b1 = ax.bar(x - 1.5*width, idc_a, width, label='IDC A', color='#1f77b4', alpha=0.85)
    b2 = ax.bar(x - 0.5*width, gcp_a, width, label='GCP A', color='#2ca02c', alpha=0.85)
    b3 = ax.bar(x + 0.5*width, idc_b, width, label='IDC B', color='#ff7f0e', alpha=0.85)
    b4 = ax.bar(x + 1.5*width, gcp_b, width, label='GCP B', color='#d62728', alpha=0.85)
    ax.set_xticks(x); ax.set_xticklabels([str(t) for t in threads])
    ax.set_xlabel('Threads'); ax.set_ylabel('Requests per second')
    ax.set_title('TiDB Topology Change: IDC1+GCP2 -> IDC2+GCP1 Throughput')
    ax.legend(loc='upper right', ncol=2)
    for bars in (b1,b2,b3,b4):
        for bar in bars:
            h = bar.get_height(); ax.text(bar.get_x()+bar.get_width()/2, h*1.01, f"{int(h)}", ha='center', va='bottom', fontsize=7)
    if annotate_deltas:  # only if explicitly enabled
        for bar, d in zip(b3, d_idc):
            ax.text(bar.get_x()+bar.get_width()/2, bar.get_height()*1.14, f"{d:+.1f}%", ha='center', va='bottom', fontsize=7, color='#d62728' if d>=0 else '#2ca02c')
        for bar, d in zip(b4, d_gcp):
            ax.text(bar.get_x()+bar.get_width()/2, bar.get_height()*1.14, f"{d:+.1f}%", ha='center', va='bottom', fontsize=7, color='#d62728' if d>=0 else '#2ca02c')
    else:
        ax.text(0.01, 0.98, "Δ% hidden", transform=ax.transAxes, ha='left', va='top', fontsize=9, color='#555')
    fig.tight_layout(); fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved plot -> {PNG_NAME}")
    return True


def parse_args():
    p = argparse.ArgumentParser(description="Compare TiDB topology A vs B (percentages hidden by default).")
    p.add_argument('--show-delta-columns', action='store_true', help='顯示百分比欄位/摘要')
    p.add_argument('--show-delta-annot', action='store_true', help='圖上顯示百分比標註')
    p.add_argument('--no-plot', action='store_true', help='不產生 PNG')
    return p.parse_args()


def main():
    args = parse_args()
    rows = build()
    table(rows, show_delta_columns=args.show_delta_columns)
    print(); print(summarize(rows, show_delta=args.show_delta_columns))
    if not args.no_plot:
        plot(rows, annotate_deltas=args.show_delta_annot)


if __name__ == '__main__':
    main()
