import re
import matplotlib.pyplot as plt

with open('rps.md', 'r', encoding='utf-8') as f:
    content = f.read()

section_pattern = r'- GCP \* 3\n(.*?)(?:={5,}|- [A-Z])'
section_match = re.search(section_pattern, content, re.DOTALL)
section = section_match.group(1) if section_match else ''

def extract_table(section, title):
    table_pattern = rf'{re.escape(title)}\n```(.*?)```'
    match = re.search(table_pattern, section, re.DOTALL)
    return match.group(1) if match else ''

tidb_table = extract_table(section, 'RPS From TiDB passthrough GCP Load Balance (#10.160.152.25:4000)')
tiproxy_table = extract_table(section, 'RPS From TiProxy passthrough GCP Load Balance (#10.160.152.26:6000)')

def parse_table(table):
    lines = table.strip().split('\n')
    data = []
    for line in lines:
        if line.startswith('multi_thread_multi_conn'):
            parts = re.split(r'\s{2,}', line)
            if len(parts) == 7:
                _, _, avg_resp, err_rate, _, rps, threads = parts
                data.append({
                    'threads': int(threads),
                    'rps': float(rps),
                    'err_rate': float(err_rate)
                })
    return data

tidb_data = parse_table(tidb_table)
tiproxy_data = parse_table(tiproxy_table)

plt.figure(figsize=(10, 10))

plt.subplot(2, 1, 1)
plt.plot([d['threads'] for d in tidb_data], [d['rps'] for d in tidb_data], marker='o', label='TiDB')
plt.plot([d['threads'] for d in tiproxy_data], [d['rps'] for d in tiproxy_data], marker='o', label='TiProxy')
for d in tidb_data:
    plt.annotate(f"{d['rps']:.0f}", (d['threads'], d['rps']), textcoords="offset points", xytext=(0,5), ha='center')
for d in tiproxy_data:
    plt.annotate(f"{d['rps']:.0f}", (d['threads'], d['rps']), textcoords="offset points", xytext=(0,5), ha='center')
plt.xlabel('Threads')
plt.ylabel('RPS')
plt.title('RPS vs Threads (GCP * 3)')
plt.legend()
plt.grid(True)

plt.subplot(2, 1, 2)
plt.plot([d['threads'] for d in tidb_data], [d['err_rate'] for d in tidb_data], marker='o', label='TiDB')
plt.plot([d['threads'] for d in tiproxy_data], [d['err_rate'] for d in tiproxy_data], marker='o', label='TiProxy')
for d in tidb_data:
    plt.annotate(f"{d['err_rate']:.2f}", (d['threads'], d['err_rate']), textcoords="offset points", xytext=(0,5), ha='center')
for d in tiproxy_data:
    plt.annotate(f"{d['err_rate']:.2f}", (d['threads'], d['err_rate']), textcoords="offset points", xytext=(0,5), ha='center')
plt.xlabel('Threads')
plt.ylabel('Error Rate (%)')
plt.title('Error Rate vs Threads (GCP * 3)')
plt.legend()
plt.grid(True)

plt.tight_layout()
plt.show()
