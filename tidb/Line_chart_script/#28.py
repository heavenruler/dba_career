import re
from typing import List, Dict, Tuple
from dataclasses import dataclass

try:
    import matplotlib.pyplot as plt
    from matplotlib.lines import Line2D
    from matplotlib.figure import Figure
    from matplotlib.axes import Axes
except ImportError:
    raise SystemExit("Need matplotlib: pip install matplotlib")

MD_FILE = 'sysbench.md'
SCENARIO_HEADER = 'IDC * 2 + GCP * 3'

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

def _plot_time_performance(ax: Axes, title: str, tidb_data: List[SysbenchResult], tiproxy_data: List[SysbenchResult]):
    """Plots TiDB vs TiProxy performance for a specific time (On-Peak or Off-Peak)."""
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
    fig.legend(handles=legend_elems, loc='upper center', bbox_to_anchor=(0.5, 0.95), ncol=5, fontsize=9, frameon=False)

def plot_performance_comparison(tidb_on_peak, tiproxy_on_peak, tidb_off_peak, tiproxy_off_peak):
    """Creates and shows the combined plot for On-Peak vs Off-Peak performance."""
    fig, (ax_on_peak, ax_off_peak) = plt.subplots(2, 1, figsize=(15, 14), sharex=True)
    
    _plot_time_performance(ax_on_peak, 'On-Peak Performance (TiDB vs TiProxy)', tidb_on_peak, tiproxy_on_peak)
    _plot_time_performance(ax_off_peak, 'Off-Peak Performance (TiDB vs TiProxy)', tidb_off_peak, tiproxy_off_peak)
    
    _create_legend(fig)
    
    ax_off_peak.set_xlabel('OLTP Test Type')
    fig.suptitle(f'Performance Comparison for "{SCENARIO_HEADER}" (Access from IDC)', fontsize=16, y=0.98)
    fig.tight_layout(rect=(0, 0.03, 1, 0.93))
    plt.show()

# -------- main -------- #

def main():
    """Main execution function."""
    content = read_md(MD_FILE)
    
    section_content = extract_section(content, SCENARIO_HEADER)
    if not section_content:
        raise SystemExit(f'Main section not found: - {SCENARIO_HEADER}')

    headers = {
        "tidb_on_peak": "Benchmark from TiDB with IDC # 上班時段",
        "tiproxy_on_peak": "Benchmark from TiProxy with IDC # 上班時段",
        "tidb_off_peak": "Benchmark from TiDB with IDC # 離峰時段",
        "tiproxy_off_peak": "Benchmark from TiProxy with IDC # 離峰時段"
    }
    
    data = {}
    for key, header in headers.items():
        block = extract_benchmark_data(section_content, header)
        if not block:
            raise SystemExit(f'Data block not found for header: {header}')
        data[key] = parse_table(block)

    plot_performance_comparison(
        data["tidb_on_peak"], data["tiproxy_on_peak"],
        data["tidb_off_peak"], data["tiproxy_off_peak"]
    )

if __name__ == '__main__':
    main()
