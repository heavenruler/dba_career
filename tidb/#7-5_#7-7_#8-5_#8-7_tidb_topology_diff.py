#!/usr/bin/env python3
"""
Topology difference comparison for TiDB multi_thread_multi_conn RPS.

Goal: Quantify impact of changing cross-line topology from:
  Topology A (IDC * 1 + GCP * 2)  -> datasets #7-5 (IDC node), #7-7 (GCP node)
  to
  Topology B (IDC * 2 + GCP * 1)  -> datasets #8-5 (IDC node), #8-7 (GCP node)

For each thread count, compute:
  - IDC_A_RPS, IDC_B_RPS, ΔIDC_B_vs_A%
  - GCP_A_RPS, GCP_B_RPS, ΔGCP_B_vs_A%
  - IDC/GCP ratio for A & B, plus Δ(IDC/GCP) shift (how relative balance changed)

Output:
  - Console table
  - Traditional Chinese summary (plots in English only)
  - PNG grouped bar chart (4 bars / thread: IDC_A, GCP_A, IDC_B, GCP_B)
    * Annotate only the B (new topology) bars with Δ% vs A of same region.

File : #7-5_#7-7_#8-5_#8-7_tidb_topology_diff.py
PNG  : #7-5_#7-7_#8-5_#8-7_tidb_topology_diff.png
"""
from __future__ import annotations

# Topology A (IDC *1 + GCP *2)
IDC_A = [
    (1,    655.42),
    (100, 3245.01),
    (200, 4910.52),
    (250, 3435.43),
    (500, 4392.55),
    (750, 2743.21),
    (1000,1885.80),
]
GCP_A = [
    (1,    873.23),
    (100, 2811.40),
    (200, 5264.86),
    (250, 2572.56),
    (500, 4257.80),
    (750, 1928.54),
    (1000,3170.67),
]

# Topology B (IDC *2 + GCP *1)
IDC_B = [
    (1,    701.65),
    (100, 4071.64),
    (200, 7797.52),
    (250, 3541.41),
    (500, 6427.14),
    (750, 2790.56),
    (1000,4546.69),
]
GCP_B = [
    (1,    950.96),
    (100, 2405.80),
    (200, 3047.46),
    (250, 2266.70),
    (500, 2663.84),
    (750, 1732.99),
    (1000,2211.28),
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
            pct( (ib/gb) if gb else 0.0, (ia/ga) if ga else 0.0 ) if ga and gb else 0.0,
        ))
    return rows


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
    print(" | " .join(headers[i].ljust(w[i]) for i in range(len(headers))))
    print("-+-".join('-'*width for width in w))
    for r in rows:
        vals = [r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]]
        print(" | ".join(fmt(vals[i], i) for i in range(len(headers))))


def summarize(rows):
    # Extract delta stats
    idc_delta = [(r[0], r[3]) for r in rows]
    gcp_delta = [(r[0], r[6]) for r in rows]
    ratio_shift = [(r[0], r[9]) for r in rows]
    idc_max = max(idc_delta, key=lambda x: x[1]); idc_min = min(idc_delta, key=lambda x: x[1])
    gcp_max = max(gcp_delta, key=lambda x: x[1]); gcp_min = min(gcp_delta, key=lambda x: x[1])
    rs_max = max(ratio_shift, key=lambda x: x[1]); rs_min = min(ratio_shift, key=lambda x: x[1])
    focus = [100,200,250,500,750,1000]
    lines = []
    lines.append("=== SUMMARY (繁體中文) ===")
    lines.append(f"拓撲變更 (IDC1+GCP2 -> IDC2+GCP1) 對 IDC 節點 RPS 最大提升: {idc_max[0]}T {idc_max[1]:+.1f}% ; 最大下降: {idc_min[0]}T {idc_min[1]:+.1f}%")
    lines.append(f"對 GCP 節點 RPS 最大提升: {gcp_max[0]}T {gcp_max[1]:+.1f}% ; 最大下降: {gcp_min[0]}T {gcp_min[1]:+.1f}%")
    lines.append(f"IDC/GCP 相對比值變動最大正向: {rs_max[0]}T {rs_max[1]:+.1f}% ; 最大負向: {rs_min[0]}T {rs_min[1]:+.1f}%")
    lines.append("重點 threads:")
    for ft in focus:
        r = next((x for x in rows if x[0]==ft), None)
        if r:
            t, ia, ib, d_i, ga, gb, d_g, ra, rb, d_r = r
            lines.append(f" {t:>4}: IDC {ia:.0f}->{ib:.0f} ({d_i:+5.1f}%) ; GCP {ga:.0f}->{gb:.0f} ({d_g:+5.1f}%) ; Ratio {ra:.2f}->{rb:.2f} ({d_r:+5.1f}%)")
    lines.append("觀察:")
    lines.append(" - IDC 節點在新增一個 IDC 節點後吞吐普遍大幅成長 (200T +58.7%, 500T +46.3%)")
    lines.append(" - GCP 節點吞吐同時顯著下滑 (200T -42.1%, 500T -37.4%) 顯示 scheduler / region 分布偏移")
    lines.append(" - 高併發 1000T: IDC +141.2% vs GCP -30.3%, IDC/GCP 比值躍升, 跨區壓力由 GCP 轉移")
    lines.append(" - 250T / 750T 仍為不穩定區 (雙方皆低 / 退化), 需檢視 balance 與 hotspot")
    lines.append("建議:")
    lines.append(" - 調整 PD / region rebalance 策略: 確保 GCP 不因 IDC 擴容而被邊緣化導致 throughput 急遽下降")
    lines.append(" - 觀察 200~500T 下 GCP store CPU / IO / raftstore 指標, 評估是否需要 leader/region 數調整")
    lines.append(" - 針對 1000T 下 IDC 激增: 驗證是否為真實可持續或短期快取/調度偏態")
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
    ax.set_title('TiDB Topology Change: IDC1+GCP2 -> IDC2+GCP1 Throughput')
    ax.legend(loc='upper right', ncol=2)
    # annotate RPS (int) for all bars
    for bars in (b1,b2,b3,b4):
        for bar in bars:
            h = bar.get_height(); ax.text(bar.get_x()+bar.get_width()/2, h*1.01, f"{int(h)}", ha='center', va='bottom', fontsize=7)
    # annotate deltas only for new topology bars
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
