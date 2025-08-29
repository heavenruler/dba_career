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
SECTION_HEADER = 'IDC * 2 + GCP * 1'

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

def extract_blocks(section: str) -> List[str]:
    """Extracts all code blocks from a section."""
    return re.findall(r"```(.*?)```", section, re.DOTALL)

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

def _prepare_plot_data(tidb_rows: List[SysbenchResult], tiproxy_rows: List[SysbenchResult]) -> Tuple[List[str], Dict[str, SysbenchResult], Dict[str, SysbenchResult]]:
    """Creates a common x-axis order and data maps for plotting."""
    x_order = sorted(list(set(r.oltype for r in tidb_rows + tiproxy_rows)))
    tidb_map = {r.oltype: r for r in tidb_rows}
    tiproxy_map = {r.oltype: r for r in tiproxy_rows}
    return x_order, tidb_map, tiproxy_map

def _annotate_plot(ax: Axes, plotted_series: List[Dict]):
    """Adds value annotations to the plot points."""
    fmt_map = {'latency_95': '{:.1f}', 'qps': '{:.0f}', 'tps': '{:.0f}'}
    
    for series in plotted_series:
        metric = series['metric']
        vertical_offset = 12 if metric in ['qps', 'latency_95'] else -20
        if metric == 'qps':
             vertical_offset = 24 # Further up to avoid latency label

        for x, y in zip(series['xs'], series['ys']):
            if y != y:  # is NaN
                continue
            
            ax.annotate(
                fmt_map[metric].format(y),
                (x, y),
                textcoords='offset points',
                xytext=(0, vertical_offset),
                ha='center',
                fontsize=8,
                color=series['color'],
                bbox=dict(boxstyle='round,pad=0.2', fc='white', ec='none', alpha=0.7)
            )

def _plot_site_performance(ax: Axes, site_name: str, tidb_rows: List[SysbenchResult], tiproxy_rows: List[SysbenchResult]):
    """Plots the performance data for a single site (IDC or GCP) on a given Axes."""
    metric_config = {
        'latency_95': {'color': 'tab:blue', 'marker': 'o'},
        'qps': {'color': 'tab:green', 'marker': '^'},
        'tps': {'color': 'tab:red', 'marker': 's'}
    }
    comp_styles = {'tidb': 'solid', 'tiproxy': 'dashed'}
    
    x_order, tidb_map, tiproxy_map = _prepare_plot_data(tidb_rows, tiproxy_rows)
    plotted_series = []

    for comp, comp_map in [('tidb', tidb_map), ('tiproxy', tiproxy_map)]:
        for metric, config in metric_config.items():
            ys = [getattr(comp_map.get(o, float('nan')), metric, float('nan')) for o in x_order]
            
            ax.plot(x_order, ys, marker=config['marker'], linestyle=comp_styles[comp], 
                    color=config['color'], linewidth=1.6, markersize=6)
            
            plotted_series.append({'metric': metric, 'xs': x_order, 'ys': ys, 'color': config['color']})

    _annotate_plot(ax, plotted_series)
    ax.set_ylabel('Value')
    ax.set_title(f'{site_name} Connections Performance')
    ax.grid(True, which='major', alpha=0.4, linestyle='--', linewidth=0.6)
    ax.tick_params(axis='x', rotation=15, labelsize=9)

def _create_legend(fig: Figure):
    """Creates a clear, consolidated legend for the figure."""
    legend_elems = [
        Line2D([0], [0], color='tab:blue', lw=2, marker='o', label='Latency (95%)'),
        Line2D([0], [0], color='tab:green', lw=2, marker='^', label='QPS'),
        Line2D([0], [0], color='tab:red', lw=2, marker='s', label='TPS'),
        Line2D([0], [0], color='black', lw=2, linestyle='solid', label='TiDB Direct'),
        Line2D([0], [0], color='black', lw=2, linestyle='dashed', label='TiProxy'),
    ]
    fig.legend(handles=legend_elems, loc='upper center', bbox_to_anchor=(0.5, 0.98), ncol=5, fontsize=9, frameon=False)

def plot_combined(tidb_idc: List[SysbenchResult], tiproxy_idc: List[SysbenchResult], 
                  tidb_gcp: List[SysbenchResult], tiproxy_gcp: List[SysbenchResult]):
    """Creates and shows the combined plot for IDC and GCP performance."""
    fig, (ax_idc, ax_gcp) = plt.subplots(2, 1, figsize=(14, 11), sharex=True)
    
    _plot_site_performance(ax_idc, 'IDC', tidb_idc, tiproxy_idc)
    _plot_site_performance(ax_gcp, 'GCP', tidb_gcp, tiproxy_gcp)
    
    _create_legend(fig)
    
    ax_gcp.set_xlabel('OLTP Test Type')
    fig.suptitle(SECTION_HEADER, fontsize=16, y=0.99)
    fig.tight_layout(rect=(0, 0.02, 1, 0.95))
    plt.show()

# -------- main -------- #

def main():
    """Main execution function."""
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
