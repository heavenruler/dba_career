"""Plot ONLY differences (GCP * 3 - GCP * 1) for QPS & TPS.

Style mimics #22/#23: single axes, color per metric (QPS green, TPS red),
TiDB solid, TiProxy dashed. No original value lines, no third group.
"""

import re
import math
try:
    import matplotlib.pyplot as plt
except ImportError:
    raise SystemExit("matplotlib not installed. Install with: pip install matplotlib")

MD_FILE = 'sysbench.md'
SEC_A = 'GCP * 1'
SEC_B = 'GCP * 3'

ROLE_STYLES = {'TiDB': 'solid', 'TiProxy': 'dashed'}
ROLE_COLORS = {'TiDB': 'tab:blue', 'TiProxy': 'tab:orange'}
METRIC_COLORS = {'qps': 'tab:green', 'tps': 'tab:red'}

def read_markdown(path: str) -> str:
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def extract_section(content: str, header: str) -> str:
    pattern = rf"- {re.escape(header)}\n(.*?)(?=\n- |\Z)"
    m = re.search(pattern, content, re.DOTALL)
    return m.group(1).strip() if m else ''

def extract_blocks(section: str):
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

def parse_table(block: str):
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

def build_order(*lists):
    order, seen = [], set()
    for lst in lists:
        for r in lst:
            k = r['oltype']
            if k not in seen:
                seen.add(k)
                order.append(k)
    return order

def align(values_map, order, metric):
    return [values_map.get(o, {}).get(metric, float('nan')) for o in order]

def to_map(rows):
    return {r['oltype']: r for r in rows}

def plot_all(tidb1, tiproxy1, tidb3, tiproxy3):
    order = build_order(tidb1, tiproxy1, tidb3, tiproxy3)
    m_tidb1 = to_map(tidb1)
    m_tiproxy1 = to_map(tiproxy1)
    m_tidb3 = to_map(tidb3)
    m_tiproxy3 = to_map(tiproxy3)

    fig, ax = plt.subplots(figsize=(11, 5))
    metrics = ['qps', 'tps']
    label_names = {'qps': 'QPS', 'tps': 'TPS'}

    # Differences only
    for metric in metrics:
        color = METRIC_COLORS[metric]
        y_t1 = align(m_tidb1, order, metric)
        y_t3 = align(m_tidb3, order, metric)
        y_tp1 = align(m_tiproxy1, order, metric)
        y_tp3 = align(m_tiproxy3, order, metric)
        diff_tidb = [b - a if not (math.isnan(b) or math.isnan(a)) else float('nan') for a, b in zip(y_t1, y_t3)]
        diff_tiproxy = [b - a if not (math.isnan(b) or math.isnan(a)) else float('nan') for a, b in zip(y_tp1, y_tp3)]
        ax.plot(order, diff_tidb, marker='o', color=color, linestyle=ROLE_STYLES['TiDB'], label=f'TiDB Δ {label_names[metric]}')
        ax.plot(order, diff_tiproxy, marker='o', color=color, linestyle=ROLE_STYLES['TiProxy'], label=f'TiProxy Δ {label_names[metric]}')
        for ox, vy in zip(order, diff_tidb):
            if math.isnan(vy):
                continue
            ax.annotate(f"{vy:+.0f}", (ox, vy), textcoords='offset points', xytext=(6, -10), fontsize=7, color=color)
        for ox, vy in zip(order, diff_tiproxy):
            if math.isnan(vy):
                continue
            ax.annotate(f"{vy:+.0f}", (ox, vy), textcoords='offset points', xytext=(6, 6), fontsize=7, color=color)

    ax.axhline(0, color='#666', linewidth=1, alpha=0.5)
    ax.set_xlabel('OLTP Type')
    ax.set_ylabel('Δ (GCP3 - GCP1)')
    ax.set_title('GCP * 3 - GCP * 1 Differences (QPS & TPS)')
    ax.grid(True, alpha=0.4)
    handles, labels = ax.get_legend_handles_labels()
    seen = set(); final_h=[]; final_l=[]
    for h,l in zip(handles, labels):
        if l not in seen:
            seen.add(l); final_h.append(h); final_l.append(l)
    ax.legend(final_h, final_l, fontsize=8, ncol=2)
    fig.tight_layout()
    plt.show()

def main():
    content = read_markdown(MD_FILE)
    sec_a = extract_section(content, SEC_A)
    sec_b = extract_section(content, SEC_B)
    if not sec_a:
        raise SystemExit(f'Section not found: - {SEC_A}')
    if not sec_b:
        raise SystemExit(f'Section not found: - {SEC_B}')
    blocks_a = extract_blocks(sec_a)
    blocks_b = extract_blocks(sec_b)
    if len(blocks_a) < 2 or len(blocks_b) < 2:
        raise SystemExit('Need at least 2 blocks (TiDB, TiProxy) in both sections.')
    # Assume first block TiDB, second TiProxy (consistent with earlier files)
    tidb_a = parse_table(blocks_a[0])
    tiproxy_a = parse_table(blocks_a[1])
    tidb_b = parse_table(blocks_b[0])
    tiproxy_b = parse_table(blocks_b[1])
    plot_all(tidb_a, tiproxy_a, tidb_b, tiproxy_b)

if __name__ == '__main__':
    main()
