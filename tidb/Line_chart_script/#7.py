import re
import matplotlib.pyplot as plt

with open('rps.md', 'r', encoding='utf-8') as f:
    content = f.read()

def extract_section(content, section_name):
    pattern = rf'- {re.escape(section_name)}\n(.*?)(?:={5,}|- [A-Z])'
    match = re.search(pattern, content, re.DOTALL)
    return match.group(1) if match else ''

def extract_table(section, title):
    table_pattern = rf'{re.escape(title)}\n```(.*?)```'
    match = re.search(table_pattern, section, re.DOTALL)
    return match.group(1) if match else ''

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

section_gcp1 = extract_section(content, 'GCP * 1')
tidb_table = extract_table(section_gcp1, 'RPS From TiDB ; Connect From GCP')
tiproxy_table = extract_table(section_gcp1, 'RPS From TiProxy ; Connect From GCP')
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
plt.title('RPS vs Threads (GCP * 1)')
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
plt.title('Error Rate vs Threads (GCP * 1)')
plt.legend()
plt.grid(True)

plt.tight_layout()
plt.show()
