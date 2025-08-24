"""Compare GCP * 1 vs GCP * 3 sysbench sections and plot differences (GCP3 - GCP1)."""

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

def list_to_map(rows):
    return {r['oltype']: r for r in rows}

def compute_diff(map_a, map_b, metric):
    # b - a
    diff = {}
    for k in set(map_a.keys()) | set(map_b.keys()):
        va = map_a.get(k, {}).get(metric, float('nan'))
        vb = map_b.get(k, {}).get(metric, float('nan'))
        if math.isnan(va) or math.isnan(vb):
            diff[k] = float('nan')
        else:
            diff[k] = vb - va
    return diff

def ordered_oltypes(*maps):
    order = []
    seen = set()
    for mp in maps:
        for k in mp.keys():
            if k not in seen:
                seen.add(k)
                order.append(k)
    return order

def plot_differences(tidb_a, tidb_b, tiproxy_a, tiproxy_b):
    # Build maps
    map_tidb_a = list_to_map(tidb_a)
    map_tidb_b = list_to_map(tidb_b)
    map_tiproxy_a = list_to_map(tiproxy_a)
    map_tiproxy_b = list_to_map(tiproxy_b)

    # Only QPS & TPS like #21.py style (two subplots)
    metrics = [
        ('qps', 'ΔQPS (GCP3 - GCP1)', '{:+.0f}'),
        ('tps', 'ΔTPS (GCP3 - GCP1)', '{:+.0f}')
    ]

    order = ordered_oltypes(map_tidb_a, map_tidb_b, map_tiproxy_a, map_tiproxy_b)
    fig, axes = plt.subplots(len(metrics), 1, figsize=(12, 8), sharex=True)

    first_metric = metrics[0][0]
    for ax, (mkey, ylabel, fmt) in zip(axes, metrics):
        diff_tidb = compute_diff(map_tidb_a, map_tidb_b, mkey)
        diff_tiproxy = compute_diff(map_tiproxy_a, map_tiproxy_b, mkey)
        y_tidb = [diff_tidb.get(o, float('nan')) for o in order]
        y_tiproxy = [diff_tiproxy.get(o, float('nan')) for o in order]
        ax.axhline(0, color='#666666', linewidth=1, alpha=0.4)
        # Lines
        ax.plot(order, y_tidb, marker='o', color=ROLE_COLORS['TiDB'], linestyle=ROLE_STYLES['TiDB'], label='TiDB Δ' if mkey == first_metric else None)
        ax.plot(order, y_tiproxy, marker='o', color=ROLE_COLORS['TiProxy'], linestyle=ROLE_STYLES['TiProxy'], label='TiProxy Δ' if mkey == first_metric else None)
        # Annotations
        for ox, vy in zip(order, y_tidb):
            if math.isnan(vy):
                continue
            ax.annotate(fmt.format(vy), (ox, vy), textcoords='offset points', xytext=(6, -8), fontsize=8, color=ROLE_COLORS['TiDB'])
        for ox, vy in zip(order, y_tiproxy):
            if math.isnan(vy):
                continue
            ax.annotate(fmt.format(vy), (ox, vy), textcoords='offset points', xytext=(6, 6), fontsize=8, color=ROLE_COLORS['TiProxy'])
        ax.set_ylabel(ylabel)
        ax.grid(True, alpha=0.4)

    axes[-1].set_xlabel('OLTP Type')
    axes[-1].set_xticks(order)
    handles, labels = axes[0].get_legend_handles_labels()
    axes[0].legend(handles, labels, ncol=2, fontsize=9)
    fig.suptitle('GCP * 3 vs GCP * 1 Differences (TiDB solid / TiProxy dashed)', fontsize=14)
    plt.tight_layout(rect=(0,0,1,0.94))
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
    plot_differences(tidb_a, tidb_b, tiproxy_a, tiproxy_b)

if __name__ == '__main__':
    main()
