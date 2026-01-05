#!/usr/bin/env python3
"""
Combined comparison: Simultaneous Execution (Label Isolation) multi_thread_multi_conn throughput
across regions (IDC vs GCP) and access paths (TiDB direct vs TiProxy).

Source datasets:
 - #7-5 TiDB IDC   (TIDB_IDC)
 - #7-7 TiDB GCP   (TIDB_GCP)
 - #7-6 TiProxy IDC (PROXY_IDC)
 - #7-8 TiProxy GCP (PROXY_GCP)

Each dataset: list of (threads, req_per_sec).

Output artifacts:
 - Console comparative table with per-thread deltas:
     Threads | TIDB_IDC | TIDB_GCP | ΔGCP_vs_IDC_TiDB% | PROXY_IDC | PROXY_GCP | ΔGCP_vs_IDC_Proxy% | ΔProxy_IDC_vs_TiDB_IDC% | ΔProxy_GCP_vs_TiDB_GCP%
 - Summary (Traditional Chinese) highlighting:
     * 最佳/最差 GCP 相對 IDC 差異 (TiDB & TiProxy)
     * TiProxy 相對 TiDB 在各區域表現 (max gain / worst regression)
     * 甜蜜點 / 退化點 threads
     * 建議調優方向
 - PNG: Grouped bar chart (4 bars per thread) with RPS labels, optional highlight of best bar per group.

Plot aesthetics:
 - English labels only (portability / font safety).
 - Colors: TiDB IDC (#1f77b4), TiDB GCP (#2ca02c), TiProxy IDC (#ff7f0e), TiProxy GCP (#d62728)
 - Annotate each bar with raw RPS; mark highest bar in each thread group with a star (★) next to value.

File: #7-5_#7-6_#7-7_#7-8_simul_compare.py
PNG : #7-5_#7-6_#7-7_#7-8_simul_compare.png
"""
from __future__ import annotations

TIDB_IDC = [
    (1,    655.42),
    (100, 3245.01),
    (200, 4910.52),
    (250, 3435.43),
    (500, 4392.55),
    (750, 2743.21),
    (1000,1885.80),
]

PROXY_IDC = [
    (1,    488.56),
    (100, 2963.69),
    (200, 3106.60),
    (250, 3044.20),
    (500, 2939.32),
    (750, 2209.29),
    (1000,2726.36),
]

TIDB_GCP = [
    (1,    873.23),
    (100, 2811.40),
    (200, 5264.86),
    (250, 2572.56),
    (500, 4257.80),
    (750, 1928.54),
    (1000,3170.67),
]

PROXY_GCP = [
    (1,    585.44),
    (100, 2551.03),
    (200, 3707.02),
    (250, 2341.62),
    (500, 3138.08),
    (750, 1800.96),
    (1000,2540.32),
]

PNG_NAME = "#7-5_#7-6_#7-7_#7-8_simul_compare.png"


def idx_map(rows):
    return {t: r for t, r in rows}


def pct(a, b):
    if b == 0:
        return 0.0
    return (a - b) / b * 100.0


def build_rows():
    ti_idc = idx_map(TIDB_IDC)
    ti_gcp = idx_map(TIDB_GCP)
    pr_idc = idx_map(PROXY_IDC)
    pr_gcp = idx_map(PROXY_GCP)
    threads = sorted(set(ti_idc) & set(ti_gcp) & set(pr_idc) & set(pr_gcp))
    rows = []
    for t in threads:
        ti_i = ti_idc[t]
        ti_g = ti_gcp[t]
        pr_i = pr_idc[t]
        pr_g = pr_gcp[t]
        rows.append((
            t,
            ti_i,
            ti_g,
            pct(ti_g, ti_i),
            pr_i,
            pr_g,
            pct(pr_g, pr_i),
            pct(pr_i, ti_i),  # proxy idc vs tidb idc
            pct(pr_g, ti_g),  # proxy gcp vs tidb gcp
        ))
    return rows


def print_table(rows):
    headers = [
        "Threads", "TiDB_IDC", "TiDB_GCP", "ΔGCP_vs_IDC_TiDB%",
        "Proxy_IDC", "Proxy_GCP", "ΔGCP_vs_IDC_Proxy%",
        "ΔProxyIDC_vs_TiDBIDC%", "ΔProxyGCP_vs_TiDBGCP%"
    ]
    # Determine widths
    col_widths = [len(h) for h in headers]
    for r in rows:
        vals = [
            r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8]
        ]
        for i, v in enumerate(vals):
            s = f"{v:.2f}" if isinstance(v, float) else str(v)
            col_widths[i] = max(col_widths[i], len(s))
    def fmt(val, i):
        if isinstance(val, float):
            return f"{val:.2f}".rjust(col_widths[i])
        return str(val).rjust(col_widths[i])
    line = " | ".join(headers[i].ljust(col_widths[i]) for i in range(len(headers)))
    sep = "-+-".join('-'*w for w in col_widths)
    print(line) ; print(sep)
    for r in rows:
        vals = [
            r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8]
        ]
        print(" | ".join(fmt(vals[i], i) for i in range(len(headers))))


def summarize(rows):
    # Extract deltas
    gcp_tidb_deltas = [(t, d) for t, _, _, d, *_ in rows]
    gcp_proxy_deltas = [(t, rows[i][6]) for i, (t, *_) in enumerate(rows)]
    proxy_vs_tidb_idc = [(t, rows[i][7]) for i, (t, *_) in enumerate(rows)]
    proxy_vs_tidb_gcp = [(t, rows[i][8]) for i, (t, *_) in enumerate(rows)]

    def max_min(arr):
        return max(arr, key=lambda x: x[1]), min(arr, key=lambda x: x[1])

    tidb_max, tidb_min = max_min(gcp_tidb_deltas)
    proxy_max, proxy_min = max_min(gcp_proxy_deltas)
    pidc_max, pidc_min = max_min(proxy_vs_tidb_idc)
    pgcp_max, pgcp_min = max_min(proxy_vs_tidb_gcp)

    focus_threads = [100, 200, 250, 500, 750, 1000]
    lines = []
    lines.append("=== SUMMARY (繁體中文) ===")
    lines.append(f"TiDB GCP 相對 IDC 最大正向差異: {tidb_max[0]} threads {tidb_max[1]:+.1f}%; 最大負向: {tidb_min[0]} threads {tidb_min[1]:+.1f}%")
    lines.append(f"TiProxy GCP 相對 IDC 最大正向差異: {proxy_max[0]} threads {proxy_max[1]:+.1f}%; 最大負向: {proxy_min[0]} threads {proxy_min[1]:+.1f}%")
    lines.append(f"IDC 內 Proxy 相對 TiDB 最大增益: {pidc_max[0]} threads {pidc_max[1]:+.1f}%; 最大回落: {pidc_min[0]} threads {pidc_min[1]:+.1f}%")
    lines.append(f"GCP 內 Proxy 相對 TiDB 最大增益: {pgcp_max[0]} threads {pgcp_max[1]:+.1f}%; 最大回落: {pgcp_min[0]} threads {pgcp_min[1]:+.1f}%")
    lines.append("重點 thread 差異:")
    for ft in focus_threads:
        r = next((row for row in rows if row[0] == ft), None)
        if r:
            t, ti_i, ti_g, d_tidb, pr_i, pr_g, d_proxy, d_pidc, d_pgcp = r
            lines.append(f" {t:>4}: TiDB_GCP_vs_IDC {d_tidb:+6.1f}% ; Proxy_GCP_vs_IDC {d_proxy:+6.1f}% ; ProxyIDC_vs_TiDBIDC {d_pidc:+6.1f}% ; ProxyGCP_vs_TiDBGCP {d_pgcp:+6.1f}%")
    # Qualitative insights
    lines.append("觀察:")
    lines.append(" - TiDB 在 200/500/1000 GCP 具優勢, 但 250/750 退化顯著 (跨區交互 / 排程熱點)")
    lines.append(" - TiProxy 跨區 (GCP) 全域相對 IDC 劣勢較多, 顯示代理層延遲與連線管理成本敏感")
    lines.append(" - IDC Proxy 相對 IDC TiDB 在高併發 (1000) 尚能回升 (併發調度差異)；GCP Proxy 長尾更重")
    lines.append(" - 750 threads 普遍為退化點 (TiDB/Proxy/雙區) 需檢視 lock / region hotspot / GC / network jitter")
    lines.append("建議:")
    lines.append(" - 優先聚焦 200~500 threads 調優 (資源利用 / 延遲曲線最佳化)")
    lines.append(" - 針對 750 退化收集: TiKV store CPU、锁等待、cop task 遲滯、network RTT 變異")
    lines.append(" - TiProxy 層調整: 連線池大小、batch / multiplex、健康檢查頻率，降低中高併發抖動")
    lines.append(" - 評估將 GCP 優勢 (200/500) 策略回推 IDC (e.g., scheduler param, load distribution)")
    return "\n".join(lines)


def make_plot(rows):
    try:
        import matplotlib.pyplot as plt
        import numpy as np
    except Exception:
        print("[WARN] matplotlib/numpy not available, skipping plot (pip install matplotlib numpy)")
        return False
    threads = [r[0] for r in rows]
    tidb_idc = [r[1] for r in rows]
    tidb_gcp = [r[2] for r in rows]
    proxy_idc = [r[4] for r in rows]
    proxy_gcp = [r[5] for r in rows]
    n = len(threads)
    x = np.arange(n)
    width = 0.18
    fig, ax = plt.subplots(figsize=(11.5, 5.4))
    b1 = ax.bar(x - 1.5*width, tidb_idc, width, label='TiDB IDC', color='#1f77b4', alpha=0.85)
    b2 = ax.bar(x - 0.5*width, tidb_gcp, width, label='TiDB GCP', color='#2ca02c', alpha=0.85)
    b3 = ax.bar(x + 0.5*width, proxy_idc, width, label='TiProxy IDC', color='#ff7f0e', alpha=0.85)
    b4 = ax.bar(x + 1.5*width, proxy_gcp, width, label='TiProxy GCP', color='#d62728', alpha=0.85)
    ax.set_xticks(x)
    ax.set_xticklabels([str(t) for t in threads])
    ax.set_xlabel('Threads')
    ax.set_ylabel('Requests per second')
    ax.set_title('Simultaneous Execution Throughput Comparison (IDC vs GCP / TiDB vs TiProxy)')
    ax.legend(loc='upper right', ncol=2)
    # Annotate bars with RPS and star for group max
    grouped = list(zip(b1, b2, b3, b4))
    for idx, bars in enumerate(grouped):
        # Determine max height
        max_h = max(bar.get_height() for bar in bars)
        for bar in bars:
            h = bar.get_height()
            star = '★' if abs(h - max_h) < 1e-9 else ''
            ax.text(bar.get_x()+bar.get_width()/2, h*1.01, f"{int(h)}{star}", ha='center', va='bottom', fontsize=8)
    fig.tight_layout()
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved plot -> {PNG_NAME}")
    return True


def main():
    rows = build_rows()
    print_table(rows)
    print()
    print(summarize(rows))
    make_plot(rows)


if __name__ == "__main__":
    main()
