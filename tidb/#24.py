import re
from typing import List, Dict
from matplotlib.lines import Line2D
try:
    import matplotlib.pyplot as plt
except ImportError:
    raise SystemExit("matplotlib not installed. Install with: pip install matplotlib")

MD_FILE = 'sysbench.md'
SECTIONS = ['GCP * 1', 'GCP * 3']  # order matters (baseline vs target)

# ------------ Parsing Helpers ------------ #

def read_markdown(path: str) -> str:
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def extract_section(content: str, header: str) -> str:
    # Capture everything after '- {header}' until next section (a line that starts with '- ' at beginning) or EOF
    pattern = rf"- {re.escape(header)}\n(.*?)(?=\n- |\Z)"
    m = re.search(pattern, content, re.DOTALL)
    return m.group(1).strip() if m else ''

def extract_blocks(section: str) -> List[str]:
    # Code fences only
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
        line = line.rstrip()
        if not line or line.startswith('OLTP Type') or set(line) == {'-'}:
            continue
        parts = re.split(r"\s{2,}", line.strip())
        if len(parts) < 10:
            continue
        try:
            oltype = simplify_oltp(parts[0])
            latency_95 = float(parts[1])
            qps = float(parts[7].replace('per sec.', '').strip())
            tps = float(parts[9].replace('per sec.', '').strip())
            rows.append({'oltype': oltype, 'latency_95': latency_95, 'qps': qps, 'tps': tps})
        except ValueError:
            continue
    return rows

def load_section_data(content: str, section_header: str):
    section = extract_section(content, section_header)
    if not section:
        raise RuntimeError(f"Section not found: - {section_header}")
    blocks = extract_blocks(section)
    if len(blocks) < 2:
        raise RuntimeError(f"Need at least 2 code blocks (TiDB & TiProxy) in section {section_header}")
    data_tidb = parse_table(blocks[0])
    data_tiproxy = parse_table(blocks[1])
    return data_tidb, data_tiproxy

# ------------ Plotting ------------ #

def annotate_series(ax, xs, ys, color, dy=6, fmt="{v:.1f}", fontsize=8):
    for x, y in zip(xs, ys):
        ax.annotate(fmt.format(v=y), (x, y), textcoords='offset points', xytext=(0, dy), ha='center', fontsize=fontsize, color=color)

def plot_comparison(data: Dict[str, Dict[str, List[Dict]]]):
    # Ordered OLTP types baseline-first
    baseline_oltypes = [row['oltype'] for row in data['GCP * 1']['tidb']]
    other_oltypes = [row['oltype'] for row in data['GCP * 3']['tidb'] if row['oltype'] not in baseline_oltypes]
    oltypes = baseline_oltypes + other_oltypes

    fig, ax = plt.subplots(figsize=(14, 6))

    # Encoding: metric -> color ; component -> line style ; env -> marker
    metric_colors = {'qps': 'tab:green', 'tps': 'tab:red'}
    comp_styles = {'tidb': 'solid', 'tiproxy': 'dashed'}
    env_markers = {'GCP * 1': 'o', 'GCP * 3': '^'}
    metrics = ['qps', 'tps']

    def series(env, comp):
        rows = {r['oltype']: r for r in data[env][comp]}
        xs = oltypes
        return xs, [rows.get(o) for o in xs]

    for env in SECTIONS:
        for comp in ['tidb', 'tiproxy']:
            xs, row_objs = series(env, comp)
            for metric in metrics:
                ys = [ro[metric] if ro else float('nan') for ro in row_objs]
                color = metric_colors[metric]
                ls = comp_styles[comp]
                marker = env_markers[env]
                label = f"{comp.capitalize()} {env.split('*')[1].strip()} {metric.upper()}"
                ax.plot(xs, ys, marker=marker, linestyle=ls, color=color, label=label)
                dy = 8 if metric == 'qps' else -14
                annotate_series(ax, xs, ys, color=color, dy=dy, fmt="{v:.0f}")

    ax.set_ylabel('Throughput (QPS / TPS)')
    ax.set_xlabel('OLTP Type')
    ax.grid(True, alpha=0.4, linestyle='--', linewidth=0.6)
    ax.set_title('Sysbench Throughput: GCP * 1 vs GCP * 3 (TiDB vs TiProxy)')
    handles, labels = ax.get_legend_handles_labels()
    ax.legend(handles, labels, bbox_to_anchor=(1.02, 1), loc='upper left', borderaxespad=0., fontsize=9)
    fig.tight_layout()
    plt.show()

# ------------ Main ------------ #

def main():
    content = read_markdown(MD_FILE)
    data = {}
    for sect in SECTIONS:
        tidb_rows, tiproxy_rows = load_section_data(content, sect)
        data[sect] = {'tidb': tidb_rows, 'tiproxy': tiproxy_rows}
    plot_comparison(data)

    # Print simple diff summary (ratios) to console for quick review
    print('\n=== Ratio GCP*3 / GCP*1 (TiDB) ===')
    baseline = {r['oltype']: r for r in data['GCP * 1']['tidb']}
    target = {r['oltype']: r for r in data['GCP * 3']['tidb']}
    for o in baseline:
        if o in target:
            qps_ratio = target[o]['qps'] / baseline[o]['qps'] if baseline[o]['qps'] else float('inf')
            tps_ratio = target[o]['tps'] / baseline[o]['tps'] if baseline[o]['tps'] else float('inf')
            print(f"{o:15s} QPS {qps_ratio:5.2f}x  TPS {tps_ratio:5.2f}x")

if __name__ == '__main__':
    main()
