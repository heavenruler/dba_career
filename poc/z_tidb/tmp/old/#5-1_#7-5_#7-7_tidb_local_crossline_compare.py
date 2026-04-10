#!/usr/bin/env python3
"""
Three-way throughput comparison (multi_thread_multi_conn RPS) for TiDB:
 - Local IDC 3-node cluster (#5-1)
 - Simultaneous Execution Cross-Line (IDC node under label isolation) (#7-5)
 - Simultaneous Execution Cross-Line (GCP node under label isolation) (#7-7)

Goal: Quantify performance impact of cross-line simultaneous execution versus purely local IDC deployment.

Plot: Grouped bar chart (3 bars per thread). Baseline = Local IDC (#5-1). For each thread:
 - Annotate all bars with raw RPS.
 - Above the IDC-Simul and GCP-Simul bars show Δ% vs Local baseline.

Console Output:
 - Comparative table with per-thread RPS and deltas (IDC_simul vs Local, GCP_simul vs Local, GCP_simul vs IDC_simul).
 - Traditional Chinese summary highlighting max gains / worst regressions and tuning advice.

English-only plot labels; Chinese summary. PNG mirrors script name.
"""
from __future__ import annotations

# Local IDC (#5-1)
LOCAL = [
    (1,    661.34),
    (100,  3788.97),
    (200,  7137.34),
    (250,  3653.09),
    (500,  2428.03),
    (750,  2731.68),
    (1000, 2869.28),
]

# Cross-Line Simultaneous (IDC node) (#7-5)
IDC_SIMUL = [
    (1,    655.42),
    (100, 3245.01),
    (200, 4910.52),
    (250, 3435.43),
    (500, 4392.55),
    (750, 2743.21),
    (1000,1885.80),
]

# Cross-Line Simultaneous (GCP node) (#7-7)
GCP_SIMUL = [
    (1,    873.23),
    (100, 2811.40),
    (200, 5264.86),
    (250, 2572.56),
    (500, 4257.80),
    (750, 1928.54),
    (1000,3170.67),
]

PNG_NAME = "#5-1_#7-5_#7-7_tidb_local_crossline_compare.png"


def pct(a, b):
    if b == 0:
        return 0.0
    return (a - b) / b * 100.0


def map_rows(rows):
    return {t: r for t, r in rows}


def build():
    l = map_rows(LOCAL)
    i = map_rows(IDC_SIMUL)
    g = map_rows(GCP_SIMUL)
    threads = sorted(set(l) & set(i) & set(g))
    out = []
    for t in threads:
        rl, ri, rg = l[t], i[t], g[t]
        out.append((
            t, rl, ri, rg,
            pct(ri, rl),      # Δ IDC_simul vs Local
            pct(rg, rl),      # Δ GCP_simul vs Local
            pct(rg, ri),      # Δ GCP_simul vs IDC_simul
        ))
    return out


def table(rows):
    headers = [
        "Threads", "Local_IDC", "IDC_Simul", "GCP_Simul",
        "ΔIDCsim_vs_Local%", "ΔGCPsim_vs_Local%", "ΔGCPsim_vs_IDCsim%"
    ]
    widths = [len(h) for h in headers]
    for r in rows:
        vals = [r[0], r[1], r[2], r[3], r[4], r[5], r[6]]
        for i, v in enumerate(vals):
            s = f"{v:.2f}" if isinstance(v, float) and i != 0 else str(v)
            widths[i] = max(widths[i], len(s))

    def fmt(v, i):
        if isinstance(v, float) and i != 0:
            return f"{v:.2f}".rjust(widths[i])
        return str(v).rjust(widths[i])

    header_line = " | ".join(headers[i].ljust(widths[i]) for i in range(len(headers)))
    sep = "-+-".join('-'*w for w in widths)
    print(header_line)
    print(sep)
    for r in rows:
        vals = [r[0], r[1], r[2], r[3], r[4], r[5], r[6]]
        print(" | ".join(fmt(vals[i], i) for i in range(len(headers))))


def summarize(rows):
    # rows schema: (threads, local, idc_sim, gcp_sim, d_idc_vs_local, d_gcp_vs_local, d_gcp_vs_idc)
    # Extract per-thread percentage deltas directly by index for clarity.
    idc_d = [(r[0], r[4]) for r in rows]          # IDC_simul vs Local
    gcp_d = [(r[0], r[5]) for r in rows]          # GCP_simul vs Local
    gcp_vs_idc_sim = [(r[0], r[6]) for r in rows] # GCP_simul vs IDC_simul
    idc_max = max(idc_d, key=lambda x: x[1])
    idc_min = min(idc_d, key=lambda x: x[1])
    gcp_max = max(gcp_d, key=lambda x: x[1])
    gcp_min = min(gcp_d, key=lambda x: x[1])
    gcp_sim_max = max(gcp_vs_idc_sim, key=lambda x: x[1])
    gcp_sim_min = min(gcp_vs_idc_sim, key=lambda x: x[1])

    focus = [100, 200, 250, 500, 750, 1000]
    lines = []
    lines.append("=== SUMMARY (繁體中文) ===")
    lines.append(f"IDC 同步執行 相對 本地 最大正向差異: {idc_max[0]} threads {idc_max[1]:+.1f}% ; 最大負向: {idc_min[0]} threads {idc_min[1]:+.1f}%")
    lines.append(f"GCP 同步執行 相對 本地 最大正向差異: {gcp_max[0]} threads {gcp_max[1]:+.1f}% ; 最大負向: {gcp_min[0]} threads {gcp_min[1]:+.1f}%")
    lines.append(f"GCP 同步 相對 IDC 同步 最大正向: {gcp_sim_max[0]} threads {gcp_sim_max[1]:+.1f}% ; 最大負向: {gcp_sim_min[0]} threads {gcp_sim_min[1]:+.1f}%")
    lines.append("重點 thread 差異:")
    for ft in focus:
        r = next((row for row in rows if row[0] == ft), None)
        if r:
            t, rl, ri, rg, d_i, d_g, d_gi = r
            lines.append(f" {t:>4}: IDCsim_vs_Local {d_i:+6.1f}% ; GCPsim_vs_Local {d_g:+6.1f}% ; GCPsim_vs_IDCsim {d_gi:+6.1f}%")
    # Observations
    lines.append("觀察:")
    lines.append(" - 本地 (Local) 峰值 200 threads (7137) 明顯高於兩種同步執行 (4911 / 5265)")
    lines.append(" - 500 threads: 同步執行出現顯著反轉 (IDC +81%, GCP +75% vs Local) 顯示本地場景資源瓶頸較早出現")
    lines.append(" - 高併發 1000 threads: GCP 同步仍 +10.5% vs Local, 但 IDC 同步 -34.2% (跨區調度差異)")
    lines.append(" - 750 threads 為普遍退化點 (三者均低於 100 baseline 或接近) 需調查 hotspot / lock / GC / I/O 排隊")
    lines.append("建議:")
    lines.append(" - 壓測 / 實務建議以 200 threads 為 TiDB 峰值目標; 500 threads 需釐清 Local 退化根因 (CPU / store hotspot)")
    lines.append(" - 針對同步執行跨線路：調整 region balance 與 PD 調度，減少 750 thread 長尾影響")
    lines.append(" - 觀察 500 threads 下 Local TiKV/PD 指標 (CPU saturation, scheduler wait) 以複製同步執行的正向特性")
    return "\n".join(lines)


def plot(rows):
    try:
        import matplotlib.pyplot as plt
        import numpy as np
    except Exception:
        print("[WARN] matplotlib/numpy not available; skip plot.")
        return False
    threads = [r[0] for r in rows]
    local = [r[1] for r in rows]
    idc_sim = [r[2] for r in rows]
    gcp_sim = [r[3] for r in rows]
    d_idc = [r[4] for r in rows]
    d_gcp = [r[5] for r in rows]
    x = np.arange(len(threads))
    width = 0.25
    fig, ax = plt.subplots(figsize=(11, 5.2))
    b1 = ax.bar(x - width, local, width, label='Local IDC', color='#1f77b4', alpha=0.85)
    b2 = ax.bar(x, idc_sim, width, label='IDC Simul', color='#ff7f0e', alpha=0.85)
    b3 = ax.bar(x + width, gcp_sim, width, label='GCP Simul', color='#2ca02c', alpha=0.85)
    ax.set_xticks(x)
    ax.set_xticklabels([str(t) for t in threads])
    ax.set_xlabel('Threads')
    ax.set_ylabel('Requests per second')
    ax.set_title('TiDB Local vs Simultaneous Cross-Line Throughput')
    ax.legend(loc='upper right')
    # RPS labels
    for bars in (b1, b2, b3):
        for bar in bars:
            h = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2, h*1.01, f"{int(h)}", ha='center', va='bottom', fontsize=8)
    # Delta labels above non-baseline bars
    for bar, d in zip(b2, d_idc):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height()*1.13, f"{d:+.1f}%", ha='center', va='bottom', fontsize=8, color='#d62728' if d>=0 else '#2ca02c')
    for bar, d in zip(b3, d_gcp):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height()*1.13, f"{d:+.1f}%", ha='center', va='bottom', fontsize=8, color='#d62728' if d>=0 else '#2ca02c')
    fig.tight_layout()
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved plot -> {PNG_NAME}")
    return True


def main():
    rows = build()
    table(rows)
    print()
    print(summarize(rows))
    plot(rows)


if __name__ == "__main__":
    main()
