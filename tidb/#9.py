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

# IDC * 1 + GCP * 2
section_idc1gcp2 = extract_section(content, 'IDC * 1 + GCP * 2')
tidb_idc_table = extract_table(section_idc1gcp2, 'RPS From TiDB with IDC')
tiproxy_idc_table = extract_table(section_idc1gcp2, 'RPS From TiProxy with IDC')
tidb_idc = parse_table(tidb_idc_table)
tiproxy_idc = parse_table(tiproxy_idc_table)

# IDC * 3
section_idc3 = extract_section(content, 'IDC * 3')
tidb_nat_table = extract_table(section_idc3, 'RPS From TiDB passthrough A10 NAT')
tiproxy_nat_table = extract_table(section_idc3, 'RPS From TiProxy passthrough A10 NAT')
tidb_nat = parse_table(tidb_nat_table)
tiproxy_nat = parse_table(tiproxy_nat_table)

plt.figure(figsize=(10, 10))

# RPS
plt.subplot(2, 1, 1)
plt.plot([d['threads'] for d in tidb_idc], [d['rps'] for d in tidb_idc], marker='o', label='TiDB with IDC * 1 + GCP * 2')
plt.plot([d['threads'] for d in tiproxy_idc], [d['rps'] for d in tiproxy_idc], marker='o', label='TiProxy with IDC * 1 + GCP * 2')
plt.plot([d['threads'] for d in tidb_nat], [d['rps'] for d in tidb_nat], marker='o', label='TiDB passthrough A10 NAT (IDC * 3)')
plt.plot([d['threads'] for d in tiproxy_nat], [d['rps'] for d in tiproxy_nat], marker='o', label='TiProxy passthrough A10 NAT (IDC * 3)')
for d in tidb_idc + tiproxy_idc + tidb_nat + tiproxy_nat:
    plt.annotate(f"{d['rps']:.0f}", (d['threads'], d['rps']), textcoords="offset points", xytext=(0,5), ha='center')
plt.xlabel('Threads')
plt.ylabel('RPS')
plt.title('RPS vs Threads (IDC * 1 + GCP * 2 & IDC * 3 passthrough A10 NAT)')
plt.legend()
plt.grid(True)

# Error Rate
plt.subplot(2, 1, 2)
plt.plot([d['threads'] for d in tidb_idc], [d['err_rate'] for d in tidb_idc], marker='o', label='TiDB with IDC * 1 + GCP * 2')
plt.plot([d['threads'] for d in tiproxy_idc], [d['err_rate'] for d in tiproxy_idc], marker='o', label='TiProxy with IDC * 1 + GCP * 2')
plt.plot([d['threads'] for d in tidb_nat], [d['err_rate'] for d in tidb_nat], marker='o', label='TiDB passthrough A10 NAT (IDC * 3)')
plt.plot([d['threads'] for d in tiproxy_nat], [d['err_rate'] for d in tiproxy_nat], marker='o', label='TiProxy passthrough A10 NAT (IDC * 3)')
for d in tidb_idc + tiproxy_idc + tidb_nat + tiproxy_nat:
    plt.annotate(f"{d['err_rate']:.2f}", (d['threads'], d['err_rate']), textcoords="offset points", xytext=(0,5), ha='center')
plt.xlabel('Threads')
plt.ylabel('Error Rate (%)')
plt.title('Error Rate vs Threads (IDC * 1 + GCP * 2 & IDC * 3 passthrough A10 NAT)')
plt.legend()
plt.grid(True)

plt.tight_layout()
plt.show()
