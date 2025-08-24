import re
from typing import List, Dict
try:
    import matplotlib.pyplot as plt
    from matplotlib.lines import Line2D
except ImportError:
    raise SystemExit("Need matplotlib: pip install matplotlib")

MD_FILE = 'sysbench.md'
SECTION_HEADER = 'IDC * 1 + GCP * 2'

# -------- helpers -------- #

def read_md(path: str) -> str:
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def extract_section(content: str, header: str) -> str:
    pattern = rf"- {re.escape(header)}\n(.*?)(?=\n- |\Z)"
    m = re.search(pattern, content, re.DOTALL)
    return m.group(1).strip() if m else ''

def extract_blocks(section: str) -> List[str]:
    return re.findall(r"```(.*?)```", section, re.DOTALL)

def simplify_oltp(name: str) -> str:
    return (name.replace('oltp_', '')
                .replace('select_', '')
                .replace('random_', 'rnd_')
                .replace('read_only', 'RO')
                .replace('read_write', 'RW')
                .replace('write_only', 'WO')
                .replace('points', 'pts')
                .replace('ranges', 'rngs'))

def parse_table(block: str) -> List[Dict]:
    rows = []
    for line in block.splitlines():
        line = line.strip()
        if not line or line.startswith('OLTP Type') or set(line) == {'-'}:
            continue
        parts = re.split(r"\s{2,}", line)
        if len(parts) < 10:
            continue
        try:
            oltype = simplify_oltp(parts[0])
            latency_95 = float(parts[1])  # 95th percentile latency
            qps = float(parts[7].replace('per sec.', '').strip())
            tps = float(parts[9].replace('per sec.', '').strip())
            rows.append({'oltype': oltype, 'latency_95': latency_95, 'qps': qps, 'tps': tps})
        except ValueError:
            continue
    return rows

# -------- plotting -------- #

def annotate(ax, xs, ys, dy, color, fmt):
    for x, y in zip(xs, ys):
        if y == y:  # not NaN
            ax.annotate(fmt.format(y), (x, y), textcoords='offset points', xytext=(0, dy), ha='center', fontsize=8, color=color)

def plot_combined(tidb_idc, tiproxy_idc, tidb_gcp, tiproxy_gcp):
    metric_colors = {'latency_95': 'tab:blue', 'qps': 'tab:green', 'tps': 'tab:red'}
    comp_styles   = {'tidb': 'solid', 'tiproxy': 'dashed'}
    metric_markers= {'latency_95': 'o', 'qps': '^', 'tps': 's'}
    metrics_order = ['latency_95', 'qps', 'tps']

    def prep_axes_rows(tidb_rows, tiproxy_rows):
        x_order = []
        for r in tidb_rows + tiproxy_rows:
            if r['oltype'] not in x_order:
                x_order.append(r['oltype'])
        return x_order, {r['oltype']: r for r in tidb_rows}, {r['oltype']: r for r in tiproxy_rows}

    fig, (ax_idc, ax_gcp) = plt.subplots(2, 1, figsize=(13, 10), sharex=True)
    site_axes = [ ('IDC', ax_idc, tidb_idc, tiproxy_idc), ('GCP', ax_gcp, tidb_gcp, tiproxy_gcp) ]

    for site_name, ax, tidb_rows, tiproxy_rows in site_axes:
        x_order, tidb_map, tiproxy_map = prep_axes_rows(tidb_rows, tiproxy_rows)
        # Store for second pass annotations
        plotted_series = []  # list of dict(metric, xs, ys, color)
        for comp, cmap in [('tidb', tidb_map), ('tiproxy', tiproxy_map)]:
            for metric in metrics_order:
                ys = [cmap[o][metric] if o in cmap else float('nan') for o in x_order]
                color = metric_colors[metric]
                ls = comp_styles[comp]
                marker = metric_markers[metric]
                ax.plot(x_order, ys, marker=marker, linestyle=ls, color=color, linewidth=1.6, markersize=6)
                plotted_series.append({'metric': metric, 'xs': x_order, 'ys': ys, 'color': color})
        # Annotation layer (after lines so we know axis scale)
        # Determine vertical offset factors (relative to y-range) per metric
        all_vals = [y for s in plotted_series for y in s['ys'] if y == y]
        if all_vals:
            y_min, y_max = min(all_vals), max(all_vals)
            span = (y_max - y_min) or 1.0
        else:
            span = 1.0
        offset_factor = {
            'latency_95': 0.03,  # slightly above
            'qps': 0.06,         # higher above to avoid overlap with latency label
            'tps': -0.05         # below point
        }
        fmt_map = {'latency_95': '{:.1f}', 'qps': '{:.0f}', 'tps': '{:.0f}'}
        used_positions = {}  # key: (x, metric)
        for s in plotted_series:
            metric = s['metric']
            for x, y in zip(s['xs'], s['ys']):
                if y != y:  # NaN
                    continue
                base_y = y + span * offset_factor[metric]
                # Simple de-conflict: if a label already near this y for same x, shift further by 0.02*span until free
                attempt = 0
                final_y = base_y
                while any(abs(final_y - prev_y) < span * 0.02 for (xx, _m), prev_y in used_positions.items() if xx == x):
                    final_y += span * 0.02 * (1 if offset_factor[metric] >= 0 else -1)
                    attempt += 1
                    if attempt > 10:
                        break
                used_positions[(x, metric)] = final_y
                ax.annotate(fmt_map[metric].format(y), (x, y), xytext=(0, (final_y - y)/span*72),
                            textcoords='offset points', ha='center', fontsize=8, color=s['color'],
                            bbox=dict(boxstyle='round,pad=0.2', fc='white', ec='none', alpha=0.65))
        ax.set_ylabel('Value')
        ax.set_title(f'{site_name} Connections')
        ax.grid(True, alpha=0.4, linestyle='--', linewidth=0.6)

    # Build compact encoding legend
    legend_elems = [
        Line2D([0],[0], color='tab:blue', lw=2, label='Latency (95%)'),
        Line2D([0],[0], color='tab:green', lw=2, label='QPS'),
        Line2D([0],[0], color='tab:red', lw=2, label='TPS'),
        Line2D([0],[0], color='black', lw=2, linestyle='solid', label='TiDB (solid)'),
        Line2D([0],[0], color='black', lw=2, linestyle='dashed', label='TiProxy (dashed)'),
        Line2D([0],[0], marker='o', color='black', linestyle='None', label='IDC (circle)'),
        Line2D([0],[0], marker='^', color='black', linestyle='None', label='GCP (triangle)'),
    ]
    fig.legend(handles=legend_elems, loc='upper center', ncol=4, fontsize=9, frameon=False)
    ax_gcp.set_xlabel('OLTP Type')
    fig.suptitle('Sysbench: IDC *1 + GCP *2 — Latency(95%) / QPS / TPS', fontsize=14, y=0.98)
    fig.tight_layout(rect=(0,0,1,0.92))
    plt.show()

# -------- main -------- #

def main():
    content = read_md(MD_FILE)
    section = extract_section(content, SECTION_HEADER)
    if not section:
        raise SystemExit(f'Section not found: - {SECTION_HEADER}')
    blocks = extract_blocks(section)
    if len(blocks) < 4:
        raise SystemExit('Expecting 4 code blocks (TiDB IDC, TiProxy IDC, TiDB GCP, TiProxy GCP)')
    tidb_idc = parse_table(blocks[0])
    tiproxy_idc = parse_table(blocks[1])
    tidb_gcp = parse_table(blocks[2])
    tiproxy_gcp = parse_table(blocks[3])
    plot_combined(tidb_idc, tiproxy_idc, tidb_gcp, tiproxy_gcp)

if __name__ == '__main__':
    main()
