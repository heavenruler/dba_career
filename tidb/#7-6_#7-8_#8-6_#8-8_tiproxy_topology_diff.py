#!/usr/bin/env python3
"""
Topology difference comparison for TiProxy multi_thread_multi_conn RPS.

Topology A (IDC *1 + GCP *2)  -> #7-6 (IDC), #7-8 (GCP)
Topology B (IDC *2 + GCP *1)  -> #8-6 (IDC), #8-8 (GCP)

Metrics per thread:
  IDC_A, IDC_B, ΔIDC_B_vs_A%
  GCP_A, GCP_B, ΔGCP_B_vs_A%
  IDC_A/GCP_A, IDC_B/GCP_B, Δ(IDC/GCP)%

PNG grouped bar chart with four bars (IDC A, GCP A, IDC B, GCP B) and Δ annotations for B bars.
Traditional Chinese summary for analysis; English plot labels.

File : #7-6_#7-8_#8-6_#8-8_tiproxy_topology_diff.py
PNG  : #7-6_#7-8_#8-6_#8-8_tiproxy_topology_diff.png
"""
from __future__ import annotations

IDC_A = [
    (1,    488.56),
    (100, 2963.69),
    (200, 3106.60),
    (250, 3044.20),
    (500, 2939.32),
    (750, 2209.29),
    (1000,2726.36),
]
GCP_A = [
    (1,    585.44),
    (100, 2551.03),
    (200, 3707.02),
    (250, 2341.62),
    (500, 3138.08),
    (750, 1800.96),
    (1000,2540.32),
]

IDC_B = [
    (1,    431.74),
    (100, 4340.12),
    (200, 4004.50),
    (250, 4097.70),
    (500, 3468.14),
    (750, 3347.87),
    (1000,2951.89),
]
GCP_B = [
    (1,    618.03),
    (100, 1416.45),
    (200, 1959.11),
    (250, 1342.86),
    (500, 1712.75),
    (750, 1129.57),
    (1000,1540.76),
]

PNG_NAME = "#7-6_#7-8_#8-6_#8-8_tiproxy_topology_diff.png"


def pct(a, b):
    if b == 0:
        return 0.0
    return (a - b) / b * 100.0


def mp(rows):
    return {t: r for t, r in rows}


def build():
    idc_a = mp(IDC_A); gcp_a = mp(GCP_A); idc_b = mp(IDC_B); gcp_b = mp(GCP_B)
    threads = sorted(set(idc_a) & set(gcp_a) & set(idc_b) & set(gcp_b))
    out = []
    for t in threads:
        ia, ga, ib, gb = idc_a[t], gcp_a[t], idc_b[t], gcp_b[t]
        out.append((
            t,
            ia, ib, pct(ib, ia),
            ga, gb, pct(gb, ga),
            ia/ga if ga else 0.0,
            ib/gb if gb else 0.0,
            pct( (ib/gb) if gb else 0.0, (ia/ga) if ga else 0.0 ) if ga and gb else 0.0,
        ))
    return out


def table(rows):
    headers = [
        "Threads",
        "IDC_A","IDC_B","ΔIDC_B_vs_A%",
        "GCP_A","GCP_B","ΔGCP_B_vs_A%",
        "IDC_A/GCP_A","IDC_B/GCP_B","Δ(IDC/GCP)%",
    ]
    w = [len(h) for h in headers]
    for r in rows:
        vals = [r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]]
        for i, v in enumerate(vals):
            if isinstance(v, float):
                s = f"{v:.2f}" if i not in (3,6,9) else f"{v:.1f}"
            else:
                s = str(v)
            w[i] = max(w[i], len(s))
    def fmt(v, i):
        if isinstance(v, float):
            return (f"{v:.2f}" if i not in (3,6,9) else f"{v:.1f}").rjust(w[i])
        return str(v).rjust(w[i])
    print(" | ".join(headers[i].ljust(w[i]) for i in range(len(headers))))
    print("-+-".join('-'*width for width in w))
    for r in rows:
        vals = [r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]]
        print(" | ".join(fmt(vals[i], i) for i in range(len(headers))))


def summarize(rows):
    idc_delta = [(r[0], r[3]) for r in rows]
    gcp_delta = [(r[0], r[6]) for r in rows]
    ratio_shift = [(r[0], r[9]) for r in rows]
    idc_max = max(idc_delta, key=lambda x: x[1]); idc_min = min(idc_delta, key=lambda x: x[1])
    gcp_max = max(gcp_delta, key=lambda x: x[1]); gcp_min = min(gcp_delta, key=lambda x: x[1])
    rs_max = max(ratio_shift, key=lambda x: x[1]); rs_min = min(ratio_shift, key=lambda x: x[1])
    focus = [100,200,250,500,750,1000]
    lines = []
    lines.append("=== SUMMARY (繁體中文) ===")
    lines.append(f"拓撲變更 (IDC1+GCP2 -> IDC2+GCP1) 對 IDC TiProxy 最大提升: {idc_max[0]}T {idc_max[1]:+.1f}% ; 最大下降: {idc_min[0]}T {idc_min[1]:+.1f}%")
    lines.append(f"對 GCP TiProxy 最大提升: {gcp_max[0]}T {gcp_max[1]:+.1f}% ; 最大下降: {gcp_min[0]}T {gcp_min[1]:+.1f}%")
    lines.append(f"IDC/GCP 比值變動最大正向: {rs_max[0]}T {rs_max[1]:+.1f}% ; 最大負向: {rs_min[0]}T {rs_min[1]:+.1f}%")
    lines.append("重點 threads:")
    for ft in focus:
        r = next((x for x in rows if x[0]==ft), None)
        if r:
            t, ia, ib, d_i, ga, gb, d_g, ra, rb, d_r = r
            lines.append(f" {t:>4}: IDC {ia:.0f}->{ib:.0f} ({d_i:+5.1f}%) ; GCP {ga:.0f}->{gb:.0f} ({d_g:+5.1f}%) ; Ratio {ra:.2f}->{rb:.2f} ({d_r:+5.1f}%)")
    lines.append("觀察:")
    lines.append(" - IDC TiProxy 在新增 IDC 節點後 100T +46.5%, 250T +34.7% 明顯改善")
    lines.append(" - GCP 端 TiProxy 吞吐大幅下滑 (100T -44.4%, 200T -47.1%, 500T -45.4%) => 跨區負載轉移 / 連線排程偏向 IDC")
    lines.append(" - 750T / 1000T 下 IDC 雖保持較高但 GCP 極度退化, 整體平衡惡化")
    lines.append(" - Ratio 上升顯示代理層負載集中 IDC, 需檢視負載均衡策略")
    lines.append("建議:")
    lines.append(" - 檢視 TiProxy 後端連線/路由策略, 重新分配 GCP 流量避免被邊緣化")
    lines.append(" - 調整 health check / 負載均衡權重, 以及观察 GCP store CPU/latency 指標是否造成 scheduler 避開")
    lines.append(" - 針對高併發 (≥500T) 建議先平衡兩區再壓測, 以免 IDC 過熱 GCP 閒置")
    return "\n".join(lines)


def plot(rows):
    try:
        import matplotlib.pyplot as plt
        import numpy as np
    except Exception:
        print("[WARN] matplotlib/numpy not available; skip plot.")
        return False
    threads = [r[0] for r in rows]
    idc_a = [r[1] for r in rows]; idc_b = [r[2] for r in rows]; d_idc = [r[3] for r in rows]
    gcp_a = [r[4] for r in rows]; gcp_b = [r[5] for r in rows]; d_gcp = [r[6] for r in rows]
    x = np.arange(len(threads))
    width = 0.2
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
    for bar, d in zip(b3, d_idc):
        ax.text(bar.get_x()+bar.get_width()/2, bar.get_height()*1.14, f"{d:+.1f}%", ha='center', va='bottom', fontsize=7, color='#d62728' if d>=0 else '#2ca02c')
    for bar, d in zip(b4, d_gcp):
        ax.text(bar.get_x()+bar.get_width()/2, bar.get_height()*1.14, f"{d:+.1f}%", ha='center', va='bottom', fontsize=7, color='#d62728' if d>=0 else '#2ca02c')
    fig.tight_layout(); fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved plot -> {PNG_NAME}")
    return True


def main():
    rows = build()
    table(rows)
    print(); print(summarize(rows))
    plot(rows)


if __name__ == "__main__":
    main()
