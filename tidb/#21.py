import re
import math
try:
    import matplotlib.pyplot as plt
except ImportError:
    raise SystemExit("matplotlib not installed. Install with: pip install matplotlib")

SYSBENCH_MD = 'sysbench.md'
SECTIONS = [
    'IDC * 1',
    'IDC * 3 (4vCPU 8GB Ram)',
    'IDC * 3 (8vCPU 16GB Ram)'
]
SHORT_ENV = {
    'IDC * 1': 'IDC1',
    'IDC * 3 (4vCPU 8GB Ram)': 'IDC3-4c',
    'IDC * 3 (8vCPU 16GB Ram)': 'IDC3-8c'
}
COLOR_MAP = {
    'IDC * 1': 'tab:blue',
    'IDC * 3 (4vCPU 8GB Ram)': 'tab:green',
    'IDC * 3 (8vCPU 16GB Ram)': 'tab:orange'
}


def read_markdown(path: str) -> str:
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()


def extract_section(content: str, header: str) -> str:
    pattern = rf"- {re.escape(header)}\n(.*?)(?=\n- |\Z)"
    m = re.search(pattern, content, re.DOTALL)
    return m.group(1).strip() if m else ''


def extract_blocks(section: str):
    return re.findall(r"```(.*?)```", section, re.DOTALL)


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
            oltype = parts[0]
            latency_95 = float(parts[1])
            qps = float(parts[7].replace('per sec.', '').strip())
            tps = float(parts[9].replace('per sec.', '').strip())
            ol_short = (oltype.replace('oltp_', '')
                               .replace('select_', '')
                               .replace('random_', 'rnd_')
                               .replace('read_only', 'RO')
                               .replace('read_write', 'RW')
                               .replace('write_only', 'WO')
                               .replace('points', 'pts')
                               .replace('ranges', 'rngs'))
            rows.append({'oltype': ol_short, 'latency_95': latency_95, 'qps': qps, 'tps': tps})
        except ValueError:
            continue
    return rows


def load_env_data(content: str, section_header: str):
    section = extract_section(content, section_header)
    if not section:
        raise RuntimeError(f"Section not found: - {section_header}")
    blocks = extract_blocks(section)
    if len(blocks) < 2:
        raise RuntimeError(f"Not enough benchmark blocks in section: {section_header}")
    tidb = parse_table(blocks[0])
    tiproxy = parse_table(blocks[1])
    return tidb, tiproxy


def ensure_same_order(env_datasets):
    # Collect union of oltypes keeping first seen order from first env's TiDB list
    base_order = []
    seen = set()
    for tidb, tiproxy in env_datasets.values():
        for d in tidb + tiproxy:
            if d['oltype'] not in seen:
                seen.add(d['oltype'])
                base_order.append(d['oltype'])
    # Reorder each list following base_order
    for key, (tidb, tiproxy) in env_datasets.items():
        order_index = {o: i for i, o in enumerate(base_order)}
        tidb.sort(key=lambda x: order_index.get(x['oltype'], 1e9))
        tiproxy.sort(key=lambda x: order_index.get(x['oltype'], 1e9))
    return base_order


def plot_all(env_datasets):
    # Only QPS & TPS
    metrics = [
        ('qps', 'Queries / sec'),
        ('tps', 'Transactions / sec'),
    ]
    base_order = ensure_same_order(env_datasets)

    fig, axes = plt.subplots(len(metrics), 1, figsize=(12, 10), sharex=True)

    first_metric = metrics[0][0]
    for ax, (mkey, mlabel) in zip(axes, metrics):
        for section in SECTIONS:
            tidb, tiproxy = env_datasets[section]
            color = COLOR_MAP[section]
            x = [d['oltype'] for d in tidb]
            y_tidb = [d[mkey] for d in tidb]
            tip_map = {d['oltype']: d[mkey] for d in tiproxy}
            y_tiproxy = [tip_map.get(ol, float('nan')) for ol in x]
            # Lines
            ax.plot(x, y_tidb, marker='o', color=color, linestyle='solid', label=f"{SHORT_ENV[section]} TiDB" if mkey == first_metric else None)
            ax.plot(x, y_tiproxy, marker='o', color=color, linestyle='dashed', label=f"{SHORT_ENV[section]} TiProxy" if mkey == first_metric else None)
            # Annotations (integers)
            for ox, vy in zip(x, y_tidb):
                if vy is None or (isinstance(vy, float) and math.isnan(vy)):
                    continue
                ax.annotate(f"{vy:.0f}", (ox, vy), textcoords='offset points', xytext=(6, -8), fontsize=7, color=color)
            for ox, vy in zip(x, y_tiproxy):
                if vy is None or (isinstance(vy, float) and math.isnan(vy)):
                    continue
                ax.annotate(f"{vy:.0f}", (ox, vy), textcoords='offset points', xytext=(6, 6), fontsize=7, color=color)
        ax.set_ylabel(mlabel)
        ax.grid(True, alpha=0.4)

    axes[-1].set_xlabel('OLTP Type')
    axes[-1].set_xticks(base_order)
    handles, labels = axes[0].get_legend_handles_labels()
    axes[0].legend(handles, labels, ncol=3, fontsize=9)

    fig.suptitle('Sysbench QPS / TPS: IDC1 vs IDC3 (4c) vs IDC3 (8c)  TiDB(solid) / TiProxy(dashed)', fontsize=14)
    plt.tight_layout(rect=(0, 0, 1, 0.95))
    plt.show()


def main():
    content = read_markdown(SYSBENCH_MD)
    env_datasets = {}
    for sec in SECTIONS:
        env_datasets[sec] = load_env_data(content, sec)
    plot_all(env_datasets)


if __name__ == '__main__':
    main()
