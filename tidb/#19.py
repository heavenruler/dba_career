import matplotlib.pyplot as plt
import re

def read_markdown(file_path: str) -> str:
    with open(file_path, 'r', encoding='utf-8') as f:
        return f.read()

def extract_section(content: str, section_header: str) -> str:
    pattern = rf"- {re.escape(section_header)}\n(.*?)(?=\n- |\Z)"
    match = re.search(pattern, content, re.DOTALL)
    return match.group(1).strip() if match else ''

def extract_blocks(section: str):
    # 取出所有 code block
    return re.findall(r"```(.*?)```", section, re.DOTALL)

def parse_table(table_text: str):
    rows = []
    for line in table_text.splitlines():
        line = line.rstrip()
        if not line or line.startswith('OLTP Type') or set(line) == {'-'}:
            continue
        parts = re.split(r"\s{2,}", line.strip())
        if len(parts) >= 10:
            try:
                oltype = parts[0]
                latency_95 = float(parts[1])
                qps = float(parts[7].replace('per sec.', '').strip())
                tps = float(parts[9].replace('per sec.', '').strip())
                oltype_short = oltype.replace('oltp_', '').replace('select_', '').replace('random_', 'rnd_').replace('read_only', 'RO').replace('read_write', 'RW').replace('write_only', 'WO').replace('points', 'pts').replace('ranges', 'rngs')
                rows.append({
                    'oltype': oltype_short,
                    'latency_95': latency_95,
                    'qps': qps,
                    'tps': tps,
                })
            except ValueError:
                continue
    return rows

def plot_idc3(data_tidb, data_tiproxy):
    plt.figure(figsize=(10, 6))
    x_tidb = [d['oltype'] for d in data_tidb]
    x_tiproxy = [d['oltype'] for d in data_tiproxy]
    plt.plot(x_tidb, [d['latency_95'] for d in data_tidb], marker='o', color='tab:blue', label='TiDB-latency', linestyle='solid')
    plt.plot(x_tiproxy, [d['latency_95'] for d in data_tiproxy], marker='o', color='tab:blue', label='TiProxy-latency', linestyle='dashed')
    plt.plot(x_tidb, [d['qps'] for d in data_tidb], marker='o', color='tab:green', label='TiDB-QPS', linestyle='solid')
    plt.plot(x_tiproxy, [d['qps'] for d in data_tiproxy], marker='o', color='tab:green', label='TiProxy-QPS', linestyle='dashed')
    plt.plot(x_tidb, [d['tps'] for d in data_tidb], marker='o', color='tab:red', label='TiDB-TPS', linestyle='solid')
    plt.plot(x_tiproxy, [d['tps'] for d in data_tiproxy], marker='o', color='tab:red', label='TiProxy-TPS', linestyle='dashed')
    for d in data_tidb:
        plt.annotate(f"{d['latency_95']:.1f}", (d['oltype'], d['latency_95']), textcoords="offset points", xytext=(8, -8), ha='left', fontsize=8, color='tab:blue')
        plt.annotate(f"{d['qps']:.0f}", (d['oltype'], d['qps']), textcoords="offset points", xytext=(8, -8), ha='left', fontsize=8, color='tab:green')
        plt.annotate(f"{d['tps']:.0f}", (d['oltype'], d['tps']), textcoords="offset points", xytext=(8, -8), ha='left', fontsize=8, color='tab:red')
    for d in data_tiproxy:
        plt.annotate(f"{d['latency_95']:.1f}", (d['oltype'], d['latency_95']), textcoords="offset points", xytext=(8, 8), ha='left', fontsize=8, color='tab:blue')
        plt.annotate(f"{d['qps']:.0f}", (d['oltype'], d['qps']), textcoords="offset points", xytext=(8, 8), ha='left', fontsize=8, color='tab:green')
        plt.annotate(f"{d['tps']:.0f}", (d['oltype'], d['tps']), textcoords="offset points", xytext=(8, 8), ha='left', fontsize=8, color='tab:red')
    plt.xlabel('OLTP Type')
    plt.ylabel('Value')
    plt.title('IDC*3 (4vCPU 8GB Ram): TiDB vs TiProxy Sysbench')
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.show()

def main():
    md_path = 'sysbench.md'
    section_header = 'IDC * 3 (4vCPU 8GB Ram)'
    content = read_markdown(md_path)
    section = extract_section(content, section_header)
    if not section:
        raise SystemExit(f"Section not found: - {section_header}")
    blocks = extract_blocks(section)
    if len(blocks) < 2:
        raise SystemExit("Not enough benchmark blocks found.")
    data_tidb = parse_table(blocks[0])
    data_tiproxy = parse_table(blocks[1])
    plot_idc3(data_tidb, data_tiproxy)

if __name__ == '__main__':
    main()
