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

# GCP * 1
section_gcp1 = extract_section(content, 'GCP * 1')
tidb_gcp1_table = extract_table(section_gcp1, 'RPS From TiDB ; Connect From GCP')
tiproxy_gcp1_table = extract_table(section_gcp1, 'RPS From TiProxy ; Connect From GCP')
tidb_gcp1 = parse_table(tidb_gcp1_table)
tiproxy_gcp1 = parse_table(tiproxy_gcp1_table)

# GCP * 3
section_gcp3 = extract_section(content, 'GCP * 3')
tidb_gcp3_table = extract_table(section_gcp3, 'RPS From TiDB passthrough GCP Load Balance (#10.160.152.25:4000)')
tiproxy_gcp3_table = extract_table(section_gcp3, 'RPS From TiProxy passthrough GCP Load Balance (#10.160.152.26:6000)')
tidb_gcp3 = parse_table(tidb_gcp3_table)
tiproxy_gcp3 = parse_table(tiproxy_gcp3_table)

plt.figure(figsize=(10, 10))

# RPS
plt.subplot(2, 1, 1)
plt.plot([d['threads'] for d in tidb_gcp1], [d['rps'] for d in tidb_gcp1], marker='o', label='TiDB GCP*1')
plt.plot([d['threads'] for d in tiproxy_gcp1], [d['rps'] for d in tiproxy_gcp1], marker='o', label='TiProxy GCP*1')
plt.plot([d['threads'] for d in tidb_gcp3], [d['rps'] for d in tidb_gcp3], marker='o', label='TiDB GCP*3')
plt.plot([d['threads'] for d in tiproxy_gcp3], [d['rps'] for d in tiproxy_gcp3], marker='o', label='TiProxy GCP*3')
for d in tidb_gcp1 + tiproxy_gcp1 + tidb_gcp3 + tiproxy_gcp3:
    plt.annotate(f"{d['rps']:.0f}", (d['threads'], d['rps']), textcoords="offset points", xytext=(0,5), ha='center')
plt.xlabel('Threads')
plt.ylabel('RPS')
plt.title('RPS vs Threads (GCP * 1 & GCP * 3)')
plt.legend()
plt.grid(True)

# Error Rate
plt.subplot(2, 1, 2)
plt.plot([d['threads'] for d in tidb_gcp1], [d['err_rate'] for d in tidb_gcp1], marker='o', label='TiDB GCP*1')
plt.plot([d['threads'] for d in tiproxy_gcp1], [d['err_rate'] for d in tiproxy_gcp1], marker='o', label='TiProxy GCP*1')
plt.plot([d['threads'] for d in tidb_gcp3], [d['err_rate'] for d in tidb_gcp3], marker='o', label='TiDB GCP*3')
plt.plot([d['threads'] for d in tiproxy_gcp3], [d['err_rate'] for d in tiproxy_gcp3], marker='o', label='TiProxy GCP*3')
for d in tidb_gcp1 + tiproxy_gcp1 + tidb_gcp3 + tiproxy_gcp3:
    plt.annotate(f"{d['err_rate']:.2f}", (d['threads'], d['err_rate']), textcoords="offset points", xytext=(0,5), ha='center')
plt.xlabel('Threads')
plt.ylabel('Error Rate (%)')
plt.title('Error Rate vs Threads (GCP * 1 & GCP * 3)')
plt.legend()
plt.grid(True)

plt.tight_layout()
plt.show()
