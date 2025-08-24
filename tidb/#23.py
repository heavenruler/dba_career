import re
try:
    import matplotlib.pyplot as plt
except ImportError:
    raise SystemExit("matplotlib not installed. Install with: pip install matplotlib")

SECTION_HEADER = 'GCP * 3'
MD_FILE = 'sysbench.md'

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
            rows.append({'oltype': oltype,'latency_95': latency_95,'qps': qps,'tps': tps})
        except ValueError:
            continue
    return rows

def plot(data_tidb, data_tiproxy):
    x_tidb = [d['oltype'] for d in data_tidb]
    x_tiproxy = [d['oltype'] for d in data_tiproxy]
    fig, ax = plt.subplots(figsize=(10, 6))
    # Latency
    ax.plot(x_tidb, [d['latency_95'] for d in data_tidb], marker='o', color='tab:blue', linestyle='solid', label='TiDB-latency')
    ax.plot(x_tiproxy, [d['latency_95'] for d in data_tiproxy], marker='o', color='tab:blue', linestyle='dashed', label='TiProxy-latency')
    # QPS
    ax.plot(x_tidb, [d['qps'] for d in data_tidb], marker='o', color='tab:green', linestyle='solid', label='TiDB-QPS')
    ax.plot(x_tiproxy, [d['qps'] for d in data_tiproxy], marker='o', color='tab:green', linestyle='dashed', label='TiProxy-QPS')
    # TPS
    ax.plot(x_tidb, [d['tps'] for d in data_tidb], marker='o', color='tab:red', linestyle='solid', label='TiDB-TPS')
    ax.plot(x_tiproxy, [d['tps'] for d in data_tiproxy], marker='o', color='tab:red', linestyle='dashed', label='TiProxy-TPS')
    # Annotations
    for d in data_tidb:
        ax.annotate(f"{d['latency_95']:.1f}", (d['oltype'], d['latency_95']), textcoords='offset points', xytext=(8, -10), fontsize=8, color='tab:blue')
        ax.annotate(f"{d['qps']:.0f}", (d['oltype'], d['qps']), textcoords='offset points', xytext=(8, -10), fontsize=8, color='tab:green')
        ax.annotate(f"{d['tps']:.0f}", (d['oltype'], d['tps']), textcoords='offset points', xytext=(8, -10), fontsize=8, color='tab:red')
    for d in data_tiproxy:
        ax.annotate(f"{d['latency_95']:.1f}", (d['oltype'], d['latency_95']), textcoords='offset points', xytext=(8, 8), fontsize=8, color='tab:blue')
        ax.annotate(f"{d['qps']:.0f}", (d['oltype'], d['qps']), textcoords='offset points', xytext=(8, 8), fontsize=8, color='tab:green')
        ax.annotate(f"{d['tps']:.0f}", (d['oltype'], d['tps']), textcoords='offset points', xytext=(8, 8), fontsize=8, color='tab:red')
    ax.set_xlabel('OLTP Type')
    ax.set_ylabel('Value')
    ax.set_title('GCP*3: TiDB vs TiProxy Sysbench')
    ax.grid(True, alpha=0.5)
    ax.legend(ncol=3)
    fig.tight_layout()
    plt.show()

def main():
    content = read_markdown(MD_FILE)
    section = extract_section(content, SECTION_HEADER)
    if not section:
        raise SystemExit(f'Section not found: - {SECTION_HEADER}')
    blocks = extract_blocks(section)
    if len(blocks) < 2:
        raise SystemExit('Not enough benchmark blocks (need TiDB and TiProxy).')
    data_tidb = parse_table(blocks[0])
    data_tiproxy = parse_table(blocks[1])
    plot(data_tidb, data_tiproxy)

if __name__ == '__main__':
    main()
