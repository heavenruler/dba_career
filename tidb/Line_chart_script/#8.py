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

section = extract_section(content, 'IDC * 1 + GCP * 2')
tidb_idc_table = extract_table(section, 'RPS From TiDB with IDC')
tiproxy_idc_table = extract_table(section, 'RPS From TiProxy with IDC')
tidb_gcp_table = extract_table(section, 'RPS From TiDB with GCP')
tiproxy_gcp_table = extract_table(section, 'RPS From TiProxy with GCP')

tidb_idc = parse_table(tidb_idc_table)
tiproxy_idc = parse_table(tiproxy_idc_table)
tidb_gcp = parse_table(tidb_gcp_table)
tiproxy_gcp = parse_table(tiproxy_gcp_table)

plt.figure(figsize=(10, 10))

# RPS
plt.subplot(2, 1, 1)
plt.plot([d['threads'] for d in tidb_idc], [d['rps'] for d in tidb_idc], marker='o', label='TiDB with IDC')
plt.plot([d['threads'] for d in tiproxy_idc], [d['rps'] for d in tiproxy_idc], marker='o', label='TiProxy with IDC')
plt.plot([d['threads'] for d in tidb_gcp], [d['rps'] for d in tidb_gcp], marker='o', label='TiDB with GCP')
plt.plot([d['threads'] for d in tiproxy_gcp], [d['rps'] for d in tiproxy_gcp], marker='o', label='TiProxy with GCP')
for d in tidb_idc + tiproxy_idc + tidb_gcp + tiproxy_gcp:
    plt.annotate(f"{d['rps']:.0f}", (d['threads'], d['rps']), textcoords="offset points", xytext=(0,5), ha='center')
plt.xlabel('Threads')
plt.ylabel('RPS')
plt.title('RPS vs Threads (IDC * 1 + GCP * 2)')
plt.legend()
plt.grid(True)

# Error Rate
plt.subplot(2, 1, 2)
plt.plot([d['threads'] for d in tidb_idc], [d['err_rate'] for d in tidb_idc], marker='o', label='TiDB with IDC')
plt.plot([d['threads'] for d in tiproxy_idc], [d['err_rate'] for d in tiproxy_idc], marker='o', label='TiProxy with IDC')
plt.plot([d['threads'] for d in tidb_gcp], [d['err_rate'] for d in tidb_gcp], marker='o', label='TiDB with GCP')
plt.plot([d['threads'] for d in tiproxy_gcp], [d['err_rate'] for d in tiproxy_gcp], marker='o', label='TiProxy with GCP')
for d in tidb_idc + tiproxy_idc + tidb_gcp + tiproxy_gcp:
    plt.annotate(f"{d['err_rate']:.2f}", (d['threads'], d['err_rate']), textcoords="offset points", xytext=(0,5), ha='center')
plt.xlabel('Threads')
plt.ylabel('Error Rate (%)')
plt.title('Error Rate vs Threads (IDC * 1 + GCP * 2)')
plt.legend()
plt.grid(True)

plt.tight_layout()
plt.show()
