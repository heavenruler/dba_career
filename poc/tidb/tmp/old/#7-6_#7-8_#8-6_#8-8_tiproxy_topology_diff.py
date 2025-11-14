#!/usr/bin/env python3
"""
TiProxy topology difference (multi_thread_multi_conn RPS)

Updated: 預設隱藏百分比差異，僅顯示兩拓撲絕對數值與比值；需顯示請加：
  --show-delta-columns   顯示 Δ% 欄位 (B 相對 A 同 thread)
  --show-delta-annot     圖上顯示 Δ% 標註
  --no-plot              不產生 PNG

百分比定義 (若啟用)：
  ΔIDC_B_vs_A%   = (IDC_B - IDC_A) / IDC_A * 100
  ΔGCP_B_vs_A%   = (GCP_B - GCP_A) / GCP_A * 100
  Δ(IDC/GCP)%    = ((IDC_B/GCP_B) - (IDC_A/GCP_A)) / (IDC_A/GCP_A) * 100
Baseline = 拓撲 A 同一 threads。
"""
from __future__ import annotations
import argparse

# Topology A (IDC *1 + GCP *2)
IDC_A = [
    (1,488.56),(100,2963.69),(200,3106.60),(250,3044.20),(500,2939.32),(750,2209.29),(1000,2726.36)
]
GCP_A = [
    (1,585.44),(100,2551.03),(200,3707.02),(250,2341.62),(500,3138.08),(750,1800.96),(1000,2540.32)
]
# Topology B (IDC *2 + GCP *1)
IDC_B = [
    (1,431.74),(100,4340.12),(200,4004.50),(250,4097.70),(500,3468.14),(750,3347.87),(1000,2951.89)
]
GCP_B = [
    (1,618.03),(100,1416.45),(200,1959.11),(250,1342.86),(500,1712.75),(750,1129.57),(1000,1540.76)
]
PNG_NAME = "#7-6_#7-8_#8-6_#8-8_tiproxy_topology_diff.png"


def pct(a, b):
    if b == 0: return 0.0
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
            t, ia, ib, pct(ib, ia), ga, gb, pct(gb, ga), ia/ga if ga else 0.0, ib/gb if gb else 0.0, pct((ib/gb) if gb else 0.0, (ia/ga) if ga else 0.0) if ga and gb else 0.0
        ))
    return rows


def table(rows, show_delta_columns: bool = False):
    if show_delta_columns:
        headers = ["Threads","IDC_A","IDC_B","ΔIDC_B_vs_A%","GCP_A","GCP_B","ΔGCP_B_vs_A%","IDC_A/GCP_A","IDC_B/GCP_B","Δ(IDC/GCP)%"]
    else:
        headers = ["Threads","IDC_A","IDC_B","GCP_A","GCP_B","IDC_A/GCP_A","IDC_B/GCP_B"]
    w = [len(h) for h in headers]
    for r in rows:
        vals = ([r[0],r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8],r[9]] if show_delta_columns else [r[0],r[1],r[2],r[4],r[5],r[7],r[8]])
        for i,v in enumerate(vals):
            if isinstance(v,float):
                s = (f"{v:.1f}" if show_delta_columns and i in (3,6,9) else f"{v:.2f}")
            else:
                s = str(v)
            w[i] = max(w[i], len(s))
    def fmt(v,i):
        if isinstance(v,float):
            return (f"{v:.1f}" if show_delta_columns and i in (3,6,9) else f"{v:.2f}").rjust(w[i])
        return str(v).rjust(w[i])
    print(" | ".join(headers[i].ljust(w[i]) for i in range(len(headers))))
    print("-+-".join('-'*width for width in w))
    for r in rows:
        vals = ([r[0],r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8],r[9]] if show_delta_columns else [r[0],r[1],r[2],r[4],r[5],r[7],r[8]])
        print(" | ".join(fmt(vals[i],i) for i in range(len(headers))))


def summarize(rows, show_delta: bool = False):
    lines = ["=== SUMMARY (繁體中文) ==="]
    lines.append("Baseline = 拓撲 A 同 thread RPS/比值." + (" (Δ% 隱藏)" if not show_delta else ""))
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
    lines.append("觀察: 預設僅顯示絕對值；用 --show-delta-columns / --show-delta-annot 以檢視變動幅度。")
    return "\n".join(lines)


def plot(rows, annotate_deltas: bool = False):
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
    ax.set_title('TiProxy Topology Change: IDC1+GCP2 -> IDC2+GCP1 Throughput')
    ax.legend(loc='upper right', ncol=2)
    for bars in (b1,b2,b3,b4):
        for bar in bars:
            h = bar.get_height(); ax.text(bar.get_x()+bar.get_width()/2, h*1.01, f"{int(h)}", ha='center', va='bottom', fontsize=7)
    if annotate_deltas:
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
    p = argparse.ArgumentParser(description='TiProxy topology A vs B (percentages hidden by default).')
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
