import re
from typing import List
from dataclasses import dataclass

try:
    import matplotlib.pyplot as plt
    from matplotlib.lines import Line2D
    from matplotlib.figure import Figure
    from matplotlib.axes import Axes
except ImportError:
    raise SystemExit("Need matplotlib: pip install matplotlib")

MD_FILE = 'sysbench.md'
SCENARIO_HEADER = 'IDC * 2 + GCP * 3 (兩機房同時執行 Sysbench 測試)'

# -------- Data Structures -------- #

@dataclass
class SysbenchResult:
    """Represents a single row of parsed sysbench results."""
    oltype: str
    latency_95: float
    qps: float
    tps: float

    @classmethod
    def from_line(cls, line: str) -> 'SysbenchResult':
        """Parses a single line from the sysbench output table."""
        parts = re.split(r"\s{2,}", line.strip())
        if len(parts) < 10:
            raise ValueError("Line does not have enough columns to parse")
        
        oltype = _simplify_oltp(parts[0])
        latency_95 = float(parts[1])
        qps = float(parts[7].replace('per sec.', '').strip())
        tps = float(parts[9].replace('per sec.', '').strip())
        
        return cls(oltype=oltype, latency_95=latency_95, qps=qps, tps=tps)

# -------- helpers -------- #

def read_md(path: str) -> str:
    """Reads the entire content of a file."""
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def extract_section(content: str, header: str) -> str:
    """Extracts a specific section from markdown content based on a header."""
    pattern = rf"- {re.escape(header)}\n(.*?)(?=\n- |\Z)"
    m = re.search(pattern, content, re.DOTALL)
    return m.group(1).strip() if m else ''

def extract_benchmark_data(content: str, header: str) -> str:
    """Extracts a specific benchmark block from markdown content."""
    pattern = rf"{re.escape(header)}\n```\n(.*?)\n```"
    m = re.search(pattern, content, re.DOTALL)
    return m.group(1).strip() if m else ''

def _simplify_oltp(name: str) -> str:
    """Internal helper to shorten OLTP test names for display."""
    replacements = {
        'oltp_': '', 'select_': '', 'random_': 'rnd_', 'read_only': 'RO',
        'read_write': 'RW', 'write_only': 'WO', 'points': 'pts', 'ranges': 'rngs'
    }
    for old, new in replacements.items():
        name = name.replace(old, new)
    return name

def parse_table(block: str) -> List[SysbenchResult]:
    """Parses a text block containing a sysbench result table."""
    rows = []
    for line in block.splitlines():
        line = line.strip()
        if not line or line.startswith('OLTP Type') or set(line) == {'-'}:
            continue
        try:
            rows.append(SysbenchResult.from_line(line))
        except (ValueError, IndexError):
            print(f"Skipping unparsable line: {line}")
            continue
    return rows

# -------- plotting -------- #

def _annotate_plot(ax: Axes, x_values: List[str], y_values: List[float], color: str, vertical_offset: int):
    """Adds value annotations to the plot points."""
    for x, y in zip(x_values, y_values):
        if y != y:  # is NaN
            continue
        ax.annotate(
            f'{y:.1f}', (x, y), textcoords='offset points',
            xytext=(0, vertical_offset), ha='center', fontsize=8, color=color,
            bbox=dict(boxstyle='round,pad=0.2', fc='white', ec='none', alpha=0.7)
        )

def _plot_performance(ax: Axes, title: str, tidb_data: List[SysbenchResult], tiproxy_data: List[SysbenchResult]):
    """Plots TiDB vs TiProxy performance for a specific condition."""
    tidb_map = {r.oltype: r for r in tidb_data}
    tiproxy_map = {r.oltype: r for r in tiproxy_data}
    x_order = sorted(list(set(tidb_map.keys()) | set(tiproxy_map.keys())))

    metric_config = {
        'latency_95': {'color': 'tab:blue', 'marker': 'o'},
        'qps': {'color': 'tab:green', 'marker': '^'},
        'tps': {'color': 'tab:red', 'marker': 's'}
    }

    for metric, config in metric_config.items():
        # TiDB (solid line)
        tidb_ys = [getattr(tidb_map.get(o, float('nan')), metric, float('nan')) for o in x_order]
        ax.plot(x_order, tidb_ys, marker=config['marker'], linestyle='solid', color=config['color'])
        _annotate_plot(ax, x_order, tidb_ys, config['color'], 15)

        # TiProxy (dashed line)
        tiproxy_ys = [getattr(tiproxy_map.get(o, float('nan')), metric, float('nan')) for o in x_order]
        ax.plot(x_order, tiproxy_ys, marker=config['marker'], linestyle='dashed', color=config['color'])
        _annotate_plot(ax, x_order, tiproxy_ys, config['color'], -25)

    ax.set_ylabel('Value')
    ax.set_title(title)
    ax.grid(True, which='major', alpha=0.4, linestyle='--', linewidth=0.6)
    ax.tick_params(axis='x', rotation=15, labelsize=9)

def _create_legend(fig: Figure):
    """Creates a clear, consolidated legend for the figure."""
    legend_elems = [
        Line2D([0], [0], color='tab:blue', lw=2, marker='o', label='Latency (95%)'),
        Line2D([0], [0], color='tab:green', lw=2, marker='^', label='QPS'),
        Line2D([0], [0], color='tab:red', lw=2, marker='s', label='TPS'),
        Line2D([0], [0], color='black', lw=2, linestyle='solid', label='TiDB'),
        Line2D([0], [0], color='black', lw=2, linestyle='dashed', label='TiProxy'),
    ]
    fig.legend(handles=legend_elems, loc='upper center', bbox_to_anchor=(0.5, 0.98), ncol=5, fontsize=9, frameon=False)

def plot_performance_comparison(all_data):
    """Creates and shows the combined plot for all conditions."""
    fig, axes = plt.subplots(2, 2, figsize=(20, 14), sharex=True)
    
    _plot_performance(axes[0, 0], 'IDC On-Peak', all_data['tidb_idc_on'], all_data['tiproxy_idc_on'])
    _plot_performance(axes[0, 1], 'GCP On-Peak', all_data['tidb_gcp_on'], all_data['tiproxy_gcp_on'])
    _plot_performance(axes[1, 0], 'IDC Off-Peak', all_data['tidb_idc_off'], all_data['tiproxy_idc_off'])
    _plot_performance(axes[1, 1], 'GCP Off-Peak', all_data['tidb_gcp_off'], all_data['tiproxy_gcp_off'])
    
    _create_legend(fig)
    
    axes[1, 0].set_xlabel('OLTP Test Type')
    axes[1, 1].set_xlabel('OLTP Test Type')
    
    fig.suptitle(f'Performance Comparison for "{SCENARIO_HEADER}"', fontsize=16, y=1.02)
    fig.tight_layout(rect=(0, 0.03, 1, 0.95))
    plt.show()

# -------- main -------- #

def main():
    """Main function to read, parse, and plot data."""
    content = read_md(MD_FILE)
    scenario_content = extract_section(content, SCENARIO_HEADER)
    
    if not scenario_content:
        print(f"Could not find section: {SCENARIO_HEADER}")
        return

    headers = {
        'tidb_idc_on': 'Benchmark from TiDB with IDC # 上班時段',
        'tiproxy_idc_on': 'Benchmark from TiProxy with IDC # 上班時段',
        'tidb_gcp_on': 'Benchmark from TiDB with GCP # 上班時段',
        'tiproxy_gcp_on': 'Benchmark from TiProxy with GCP # 上班時段',
        'tidb_idc_off': 'Benchmark from TiDB with IDC # 離峰時段',
        'tiproxy_idc_off': 'Benchmark from TiProxy with IDC # 離峰時段',
        'tidb_gcp_off': 'Benchmark from TiDB with GCP # 離峰時段',
        'tiproxy_gcp_off': 'Benchmark from TiProxy with GCP # 離峰時段',
    }

    all_data = {}
    for key, header in headers.items():
        block = extract_benchmark_data(scenario_content, header)
        if not block:
            print(f"Could not find data block for: {header}")
            return
        all_data[key] = parse_table(block)

    plot_performance_comparison(all_data)

if __name__ == '__main__':
    main()
