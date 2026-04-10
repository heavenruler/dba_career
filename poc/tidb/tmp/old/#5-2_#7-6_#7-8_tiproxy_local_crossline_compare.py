#!/usr/bin/env python3
"""
Three-way throughput comparison (multi_thread_multi_conn RPS) for TiProxy:
 - Local IDC 3-node TiProxy (#5-2)
 - Simultaneous Execution Cross-Line IDC TiProxy (#7-6)
 - Simultaneous Execution Cross-Line GCP TiProxy (#7-8)

Baseline: Local IDC (#5-2)
Metrics per thread: RPS and Δ% vs Local for IDC Simul & GCP Simul; Δ GCP Simul vs IDC Simul.

Output:
 - Console table & Traditional Chinese summary
 - PNG grouped bar chart (3 bars / thread) with per-bar RPS and Δ annotations (non-baseline)

File: #5-2_#7-6_#7-8_tiproxy_local_crossline_compare.py
PNG : #5-2_#7-6_#7-8_tiproxy_local_crossline_compare.png
"""
from __future__ import annotations

LOCAL = [
    (1,     384.32),
    (100,  5899.92),
    (200,  3839.15),
    (250,  5693.22),
    (500,  3126.86),
    (750,  4265.93),
    (1000, 3188.79),
]

IDC_SIMUL = [
    (1,    488.56),
    (100, 2963.69),
    (200, 3106.60),
    (250, 3044.20),
    (500, 2939.32),
    (750, 2209.29),
    (1000,2726.36),
]

GCP_SIMUL = [
    (1,    585.44),
    (100, 2551.03),
    (200, 3707.02),
    (250, 2341.62),
    (500, 3138.08),
    (750, 1800.96),
    (1000,2540.32),
]

PNG_NAME = "#5-2_#7-6_#7-8_tiproxy_local_crossline_compare.png"


def pct(a, b):
    if b == 0:
        return 0.0
    return (a - b) / b * 100.0


def mp(rows):
    return {t: r for t, r in rows}


def build():
    l = mp(LOCAL); i = mp(IDC_SIMUL); g = mp(GCP_SIMUL)
    threads = sorted(set(l) & set(i) & set(g))
    out = []
    for t in threads:
        rl, ri, rg = l[t], i[t], g[t]
        out.append((
            t, rl, ri, rg,
            pct(ri, rl),    # IDC_simul vs Local
            pct(rg, rl),    # GCP_simul vs Local
            pct(rg, ri),    # GCP_simul vs IDC_simul
        ))
    return out


def table(rows):
    headers = [
        "Threads", "Local_IDC", "IDC_Simul", "GCP_Simul",
        "ΔIDCsim_vs_Local%", "ΔGCPsim_vs_Local%", "ΔGCPsim_vs_IDCsim%"
    ]
    w = [len(h) for h in headers]
    for r in rows:
        vals = [r[0], r[1], r[2], r[3], r[4], r[5], r[6]]
        for i, v in enumerate(vals):
            s = f"{v:.2f}" if isinstance(v, float) and i != 0 else str(v)
            w[i] = max(w[i], len(s))
    def fmt(v, i):
        if isinstance(v, float) and i != 0:
            return f"{v:.2f}".rjust(w[i])
        return str(v).rjust(w[i])
    print(" | ".join(headers[i].ljust(w[i]) for i in range(len(headers))))
    print("-+-".join('-'*width for width in w))
    for r in rows:
        vals = [r[0], r[1], r[2], r[3], r[4], r[5], r[6]]
        print(" | ".join(fmt(vals[i], i) for i in range(len(headers))))


def summarize(rows):
    # rows schema: (threads, local, idc_sim, gcp_sim, d_idc_vs_local, d_gcp_vs_local, d_gcp_vs_idc)
    idc_d = [(r[0], r[4]) for r in rows]
    gcp_d = [(r[0], r[5]) for r in rows]
    g_vs_i = [(r[0], r[6]) for r in rows]
    idc_max = max(idc_d, key=lambda x: x[1]); idc_min = min(idc_d, key=lambda x: x[1])
    gcp_max = max(gcp_d, key=lambda x: x[1]); gcp_min = min(gcp_d, key=lambda x: x[1])
    gvi_max = max(g_vs_i, key=lambda x: x[1]); gvi_min = min(g_vs_i, key=lambda x: x[1])
    focus = [100, 200, 250, 500, 750, 1000]
    lines = []
    lines.append("=== SUMMARY (繁體中文) ===")
    lines.append(f"IDC 同步 TiProxy 相對 本地 最大正向: {idc_max[0]} threads {idc_max[1]:+.1f}% ; 最大負向: {idc_min[0]} threads {idc_min[1]:+.1f}%")
    lines.append(f"GCP 同步 TiProxy 相對 本地 最大正向: {gcp_max[0]} threads {gcp_max[1]:+.1f}% ; 最大負向: {gcp_min[0]} threads {gcp_min[1]:+.1f}%")
    lines.append(f"GCP 同步 相對 IDC 同步 最大正向: {gvi_max[0]} threads {gvi_max[1]:+.1f}% ; 最大負向: {gvi_min[0]} threads {gvi_min[1]:+.1f}%")
    lines.append("重點 thread 差異:")
    for ft in focus:
        r = next((row for row in rows if row[0] == ft), None)
        if r:
            t, rl, ri, rg, d_i, d_g, d_gi = r
            lines.append(f" {t:>4}: IDCsim_vs_Local {d_i:+6.1f}% ; GCPsim_vs_Local {d_g:+6.1f}% ; GCPsim_vs_IDCsim {d_gi:+6.1f}%")
    lines.append("觀察:")
    lines.append(" - 本地 100 threads 為峰值 (5899) 遠高於同步 (2964 / 2551) => 同步執行代理層顯著受限")
    lines.append(" - 200~500 threads: 同步執行無法恢復到本地峰值, 顯示延遲 / 排程成本抵銷擴充效益")
    lines.append(" - 750 / 1000 threads 出現深度退化 (特別是 GCP -57.8% @750 vs Local) 為關鍵調優點")
    lines.append(" - GCP 同步 全域劣勢 > IDC 同步, 表示跨區 RTT + Proxy 排程對 throughput 更敏感")
    lines.append("建議:")
    lines.append(" - 聚焦 100~250 threads TiProxy 行為 (連線池、路由策略、批次) 以提升同步執行基線")
    lines.append(" - 分析 750 threads 長尾 (CPU runq、Go scheduler、lock wait、region hotspot) 避免非線性退化")
    lines.append(" - 評估調整 TiProxy 參數: 最大併發、後端連線重用、idle timeout、健康檢查間隔")
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
    fig, ax = plt.subplots(figsize=(11,5.2))
    b1 = ax.bar(x - width, local, width, label='Local IDC', color='#1f77b4', alpha=0.85)
    b2 = ax.bar(x, idc_sim, width, label='IDC Simul', color='#ff7f0e', alpha=0.85)
    b3 = ax.bar(x + width, gcp_sim, width, label='GCP Simul', color='#d62728', alpha=0.85)
    ax.set_xticks(x); ax.set_xticklabels([str(t) for t in threads])
    ax.set_xlabel('Threads'); ax.set_ylabel('Requests per second')
    ax.set_title('TiProxy Local vs Simultaneous Cross-Line Throughput')
    ax.legend(loc='upper right')
    for bars in (b1,b2,b3):
        for bar in bars:
            h = bar.get_height(); ax.text(bar.get_x()+bar.get_width()/2, h*1.01, f"{int(h)}", ha='center', va='bottom', fontsize=8)
    for bar, d in zip(b2, d_idc):
        ax.text(bar.get_x()+bar.get_width()/2, bar.get_height()*1.13, f"{d:+.1f}%", ha='center', va='bottom', fontsize=8, color='#d62728' if d>=0 else '#2ca02c')
    for bar, d in zip(b3, d_gcp):
        ax.text(bar.get_x()+bar.get_width()/2, bar.get_height()*1.13, f"{d:+.1f}%", ha='center', va='bottom', fontsize=8, color='#d62728' if d>=0 else '#2ca02c')
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
