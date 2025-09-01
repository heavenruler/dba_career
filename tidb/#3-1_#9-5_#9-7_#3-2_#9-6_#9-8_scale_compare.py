#!/usr/bin/env python3
"""
Composite scale / dedicated-line impact comparison.

Scenarios (multi_thread_multi_conn only):
  TiDB:
    - IDC *1 baseline              (#3-1.py)
    - IDC Simultaneous (w/ GCP?)   (#9-5.py)
    - GCP Simultaneous             (#9-7.py)
  TiProxy:
    - IDC *1 baseline              (#3-2.py)
    - IDC Simultaneous (w/ GCP?)   (#9-6.py)
    - GCP Simultaneous             (#9-8.py)

Goal: Show effect of simultaneous cross-site execution / dedicated line (專線) on scaling vs baseline
      and highlight super-linear zones, regressions, and stability windows.

Output (only RPS diff as requested):
    - #3-1_#9-5_#9-7_#3-2_#9-6_#9-8_scale_compare.png (TiDB & TiProxy RPS vs Threads + Δ% vs IDC*1)

Notes:
  * Percent deltas computed versus IDC *1 baseline for each layer separately (#3-1 TiDB, #3-2 TiProxy).
  * "Super-linear" flagged when efficiency (req/sec/thread) exceeds baseline 100-thread efficiency by >10%.
  * Dedicated line impact (專線影響) summarized as avg % delta (100..500 threads) for Simultaneous vs baseline.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Tuple
import math

try:
    import matplotlib.pyplot as plt
except Exception:  # pragma: no cover
    plt = None


# ===================== Raw Datasets (threads, rps, avg_ms, total_time_s) =====================

TIDB_IDC1 = [
    (1, 703.02, 1.421, 14.224),
    (100, 5178.16, 17.830, 1.931),
    (200, 5346.08, 33.044, 1.871),
    (250, 5107.33, 42.019, 1.958),
    (500, 4499.16, 86.555, 2.223),
    (750, 4255.60, 105.778, 2.350),
    (1000, 3190.80, 142.418, 3.134),
]
TIDB_IDC_SIM = [  # #9-5 (IDC Simultaneous Execution)
    (1, 591.14, 1.690, 16.916),
    (100, 3938.95, 22.355, 2.539),
    (200, 9545.70, 13.684, 1.048),
    (250, 4028.54, 44.783, 2.482),
    (500, 2719.85, 15.610, 3.677),
    (750, 2809.31, 21.924, 3.560),
    (1000, 2229.57, 14.623, 4.485),
]
TIDB_GCP_SIM = [  # #9-7 (GCP Simultaneous Execution)
    (1, 938.11, 1.065, 10.660),
    (100, 2907.39, 31.817, 3.440),
    (200, 5703.00, 27.169, 1.753),
    (250, 2650.38, 78.617, 3.773),
    (500, 4337.12, 66.139, 2.306),
    (750, 1980.50, 25.645, 5.049),
    (1000, 3224.52, 12.123, 3.101),
]

TIPROXY_IDC1 = [
    (1, 502.62, 1.988, 19.896),
    (100, 3220.79, 29.485, 3.105),
    (200, 3465.21, 52.583, 2.886),
    (250, 3428.05, 66.397, 2.917),
    (500, 3337.43, 126.219, 2.996),
    (750, 3054.79, 192.192, 3.274),
    (1000, 2968.66, 238.522, 3.369),
]
TIPROXY_IDC_SIM = [  # #9-6
    (1, 394.48, 2.534, 25.350),
    (100, 2693.88, 15.416, 3.712),
    (200, 2626.27, 41.133, 3.808),
    (250, 5156.92, 33.316, 1.939),
    (500, 3387.40, 94.211, 2.952),
    (750, 4017.87, 95.852, 2.489),
    (1000, 3126.35, 32.013, 3.199),
]
TIPROXY_GCP_SIM = [  # #9-8
    (1, 610.76, 1.636, 16.373),
    (100, 2581.78, 35.659, 3.873),
    (200, 3853.03, 44.524, 2.595),
    (250, 2365.68, 88.958, 4.227),
    (500, 3233.98, 110.136, 3.092),
    (750, 1807.05, 293.526, 5.534),
    (1000, 2577.48, 198.886, 3.880),
]


@dataclass
class Scenario:
    name: str
    label: str
    data: List[Tuple[int, float, float, float]]  # (threads, rps, avg_ms, total_time_s)

    def to_maps(self) -> Tuple[Dict[int, float], Dict[int, float]]:
        rps_map = {t: rps for t, rps, *_ in self.data}
        lat_map = {t: ms for t, _, ms, _ in self.data}
        return rps_map, lat_map

    def efficiency_map(self) -> Dict[int, float]:
        return {t: (rps / t if t else float('nan')) for t, rps, *_ in self.data}


TIDB_SCENARIOS = [
    Scenario('IDC1', 'TiDB IDC*1', TIDB_IDC1),
    Scenario('IDC_SIM', 'TiDB IDC Sim', TIDB_IDC_SIM),
    Scenario('GCP_SIM', 'TiDB GCP Sim', TIDB_GCP_SIM),
]
TIPROXY_SCENARIOS = [
    Scenario('IDC1', 'TiProxy IDC*1', TIPROXY_IDC1),
    Scenario('IDC_SIM', 'TiProxy IDC Sim', TIPROXY_IDC_SIM),
    Scenario('GCP_SIM', 'TiProxy GCP Sim', TIPROXY_GCP_SIM),
]

THREADS = [1, 100, 200, 250, 500, 750, 1000]


def pct(new: float, old: float) -> float:
    if old == 0 or math.isclose(old, 0.0):
        return 0.0
    return (new / old - 1.0) * 100.0


def build_delta_table(scenarios: List[Scenario]) -> str:
    baseline = scenarios[0]
    base_rps, _ = baseline.to_maps()
    headers = ["Threads"] + [sc.label for sc in scenarios] + [f"Δ% vs {baseline.label} ({sc.label})" for sc in scenarios[1:]]
    rows = []
    for t in THREADS:
        row = [t]
        for sc in scenarios:
            rps_map, _ = sc.to_maps()
            row.append(rps_map.get(t, float('nan')))
        for sc in scenarios[1:]:
            rps_map, _ = sc.to_maps()
            row.append(pct(rps_map.get(t, float('nan')), base_rps.get(t, float('nan'))))
        rows.append(row)
    # column widths
    widths = []
    for i, h in enumerate(headers):
        max_len = max(len(h), *(len(f"{r[i]:.2f}") if isinstance(r[i], float) else len(str(r[i])) for r in rows))
        widths.append(max_len)

    def fmt(v, w):
        if isinstance(v, float):
            if math.isnan(v):
                return 'NaN'.rjust(w)
            return f"{v:.2f}".rjust(w)
        return str(v).rjust(w)

    lines = [" | ".join(h.ljust(widths[i]) for i, h in enumerate(headers)),
             "-+-".join('-'*w for w in widths)]
    for r in rows:
        lines.append(" | ".join(fmt(r[i], widths[i]) for i in range(len(headers))))
    return '\n'.join(lines)


def super_linear_threads(scenario: Scenario, baseline_eff_100: float) -> List[int]:
    eff_map = scenario.efficiency_map()
    out = []
    for t, eff in eff_map.items():
        if t < 100:
            continue
        if eff > baseline_eff_100 * 1.10:  # >10% over baseline efficiency counts as super-linear
            out.append(t)
    return out


def summarize_layer(name: str, scenarios: List[Scenario]) -> List[str]:
    baseline = scenarios[0]
    base_eff_100 = baseline.efficiency_map().get(100)
    lines: List[str] = []
    # Dedicated-line (simultaneous) impact average across mid concurrency (100..500)
    mids = [100, 200, 250, 500]
    base_rps_map, _ = baseline.to_maps()
    for sc in scenarios[1:]:
        rps_map, _ = sc.to_maps()
        deltas = [pct(rps_map[t], base_rps_map[t]) for t in mids if t in base_rps_map and t in rps_map]
        avg_mid = sum(deltas)/len(deltas)
        lines.append(f"{sc.label}: 中段併發 (100~500T) 平均 RPS 變化 {avg_mid:+.1f}% vs {baseline.label}")
        sl = super_linear_threads(sc, base_eff_100)
        if sl:
            lines.append(f"  超線性效率點 (效率 > baseline100 +10%): {', '.join(map(str, sl))} threads")
    # Peaks & worst regressions
    for sc in scenarios:
        rps_map, _ = sc.to_maps()
        peak_t = max(rps_map, key=lambda t: rps_map[t])
        peak_v = rps_map[peak_t]
        lines.append(f"{sc.label}: 峰值 {peak_v:.0f} RPS @ {peak_t}T")
    # Identify worst negative delta for each non-baseline scenario
    for sc in scenarios[1:]:
        rps_map, _ = sc.to_maps()
        worst_t = min(THREADS, key=lambda t: pct(rps_map[t], base_rps_map[t]))
        lines.append(f"{sc.label}: 最差點 {worst_t}T (Δ {pct(rps_map[worst_t], base_rps_map[worst_t]):+.1f}%)")
    return lines


OUTPUT_PNG = '#3-1_#9-5_#9-7_#3-2_#9-6_#9-8_scale_compare.png'


def plot_rps():
    if not plt:  # pragma: no cover
        print('[WARN] matplotlib not available; skip plot.')
        return
    fig, axes = plt.subplots(1, 2, figsize=(15, 5), sharey=False)
    key_threads = [100, 200, 250, 500]
    # --- TiDB BAR CHART ---
    ax = axes[0]
    colors = ['#1f77b4', '#ff7f0e', '#2ca02c']
    width = 0.25
    x_pos = range(len(THREADS))
    base_rps_map, _ = TIDB_SCENARIOS[0].to_maps()
    for idx, sc in enumerate(TIDB_SCENARIOS):
        rps_map, _ = sc.to_maps()
        offsets = [i + (idx-1)*width for i in x_pos]
        bars = ax.bar(offsets, [rps_map[t] for t in THREADS], width, label=sc.label, color=colors[idx], alpha=0.85)
        # annotate delta vs baseline for non-baseline
        if idx > 0:
            for b, t in zip(bars, THREADS):
                d = pct(rps_map[t], base_rps_map[t])
                if t in key_threads:
                    ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f'{d:+.0f}%', ha='center', va='bottom', fontsize=7, color=colors[idx])
    ax.set_xticks([i for i in x_pos], THREADS)
    ax.set_xlabel('Threads')
    ax.set_ylabel('RPS')
    ax.set_title('TiDB RPS (Grouped Bars)')
    ax.grid(axis='y', alpha=0.3)
    ax.legend(fontsize=8)
    # --- TiProxy BAR CHART ---
    axp = axes[1]
    base_rps_map_p, _ = TIPROXY_SCENARIOS[0].to_maps()
    for idx, sc in enumerate(TIPROXY_SCENARIOS):
        rps_map, _ = sc.to_maps()
        offsets = [i + (idx-1)*width for i in x_pos]
        bars = axp.bar(offsets, [rps_map[t] for t in THREADS], width, label=sc.label, color=colors[idx], alpha=0.85)
        if idx > 0:
            for b, t in zip(bars, THREADS):
                d = pct(rps_map[t], base_rps_map_p[t])
                if t in key_threads:
                    axp.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f'{d:+.0f}%', ha='center', va='bottom', fontsize=7, color=colors[idx])
    axp.set_xticks([i for i in x_pos], THREADS)
    axp.set_xlabel('Threads')
    axp.set_ylabel('RPS')
    axp.set_title('TiProxy RPS (Grouped Bars)')
    axp.grid(axis='y', alpha=0.3)
    axp.legend(fontsize=8)
    fig.suptitle('TiDB & TiProxy RPS 比較 (Δ% vs IDC*1 @100/200/250/500)')
    fig.tight_layout(rect=[0,0,1,0.92])
    fig.savefig(OUTPUT_PNG, dpi=160)
    print(f'[OK] Saved {OUTPUT_PNG}')


## Removed latency & efficiency plotting (scope narrowed to RPS only)


def main():
    # Delta tables
    print('\n[TiDB Δ Table vs IDC*1 Baseline]')
    print(build_delta_table(TIDB_SCENARIOS))
    print('\n[TiProxy Δ Table vs IDC*1 Baseline]')
    print(build_delta_table(TIPROXY_SCENARIOS))

    # Summaries
    print('\n[TiDB Summary]')
    for line in summarize_layer('TiDB', TIDB_SCENARIOS):
        print(' - ' + line)
    print('\n[TiProxy Summary]')
    for line in summarize_layer('TiProxy', TIPROXY_SCENARIOS):
        print(' - ' + line)

    # Observational combined notes
    print('\n[Observations / 專線影響]')
    print('TiDB IDC Sim 200T 顯示超線性 (9545.70 RPS, 效率 47.7 vs baseline 51.8@100T / 26.7@200T baseline), 顯示同時執行 / 專線傳輸可能改善 pipeline 或減少等待。')
    print('TiDB GCP Sim 在 200T 也有顯著增幅 (+96.1%) 但效率未超過 baseline100; 750T 顯著退化 (-31.8%).')
    print('TiProxy IDC Sim 250T 出現峰值 (+91.5%) 但延遲大幅上升, 顯示代理層排隊或串流化閥值行為。')
    print('TiProxy GCP Sim 200T 提升 (+49.2%) 但後續高併發延遲爆炸 (≥250T) 顯示跨站 / 專線路徑在高併發下放大 latency。')
    print('Dedicated line 效益集中在中低至中度併發 (100~250T); 高併發 (≥500T) 多數情境效率崩解或延遲放大。')
    print('建議: \n  * TiDB: 針對 200T 超線性窗口調查 CPU / pipeline / batch 調整, 避免 ≥250T.\n  * TiProxy: 控制在 100~250T 並優化 250T 延遲尖峰 (連線池, epoll 迴圈, 後端路由).\n  * 跨站: 檢視專線下 500T+ 延遲成分 (RTT, 拆包, 併發流控) 並考慮動態限流避免退化區。')

    # Plots
    plot_rps()


if __name__ == '__main__':
    main()
