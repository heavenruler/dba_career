import re
import matplotlib.pyplot as plt

with open('rps.md', 'r', encoding='utf-8') as f:
    content = f.read()

def extract_section(content, section_name):
    pattern = rf'- {re.escape(section_name)}\n(.*?)(?=\n- [A-Z0-9]|\Z)'
    match = re.search(pattern, content, re.DOTALL)
    return match.group(1) if match else ''

def extract_table(section, title):
    pattern = rf'{re.escape(title)}\n```(.*?)```'
    match = re.search(pattern, section, re.DOTALL)
    return match.group(1).strip() if match else ''

def parse_table(table_text):
    data = []
    for line in table_text.splitlines():
        if line.startswith('multi_thread_multi_conn'):
            parts = re.split(r'\s{2,}', line.strip())
            if len(parts) == 7:
                _, _, avg_resp, err_rate, _, rps, threads = parts
                data.append({
                    'threads': int(threads),
                    'rps': float(rps),
                    'err_rate': float(err_rate)
                })
    return sorted(data, key=lambda x: x['threads'])

section_name = 'IDC * 2 + GCP * 3'
section = extract_section(content, section_name)

tidb_idc_table = extract_table(section, 'RPS From TiDB with IDC')
tiproxy_idc_table = extract_table(section, 'RPS From TiProxy with IDC')
tidb_gcp_table = extract_table(section, 'RPS From TiDB with GCP')
tiproxy_gcp_table = extract_table(section, 'RPS From TiProxy with GCP')

tidb_idc_data = parse_table(tidb_idc_table)
tiproxy_idc_data = parse_table(tiproxy_idc_table)
tidb_gcp_data = parse_table(tidb_gcp_table)
tiproxy_gcp_data = parse_table(tiproxy_gcp_table)

plt.figure(figsize=(10, 10))

# RPS subplot
plt.subplot(2, 1, 1)
plt.plot([d['threads'] for d in tidb_idc_data], [d['rps'] for d in tidb_idc_data], marker='o', label='TiDB with IDC')
plt.plot([d['threads'] for d in tiproxy_idc_data], [d['rps'] for d in tiproxy_idc_data], marker='o', label='TiProxy with IDC')
plt.plot([d['threads'] for d in tidb_gcp_data], [d['rps'] for d in tidb_gcp_data], marker='o', label='TiDB with GCP')
plt.plot([d['threads'] for d in tiproxy_gcp_data], [d['rps'] for d in tiproxy_gcp_data], marker='o', label='TiProxy with GCP')

all_rps_data = tidb_idc_data + tiproxy_idc_data + tidb_gcp_data + tiproxy_gcp_data
for d in all_rps_data:
    plt.annotate(f"{d['rps']:.0f}", (d['threads'], d['rps']), textcoords="offset points", xytext=(0,5), ha='center')
plt.xlabel('Threads')
plt.ylabel('RPS')
plt.title(f'RPS vs Threads ({section_name})')
plt.legend()
plt.grid(True)

# Error Rate subplot
plt.subplot(2, 1, 2)
plt.plot([d['threads'] for d in tidb_idc_data], [d['err_rate'] for d in tidb_idc_data], marker='o', label='TiDB with IDC')
plt.plot([d['threads'] for d in tiproxy_idc_data], [d['err_rate'] for d in tiproxy_idc_data], marker='o', label='TiProxy with IDC')
plt.plot([d['threads'] for d in tidb_gcp_data], [d['err_rate'] for d in tidb_gcp_data], marker='o', label='TiDB with GCP')
plt.plot([d['threads'] for d in tiproxy_gcp_data], [d['err_rate'] for d in tiproxy_gcp_data], marker='o', label='TiProxy with GCP')

all_err_rate_data = tidb_idc_data + tiproxy_idc_data + tidb_gcp_data + tiproxy_gcp_data
for d in all_err_rate_data:
    plt.annotate(f"{d['err_rate']:.2f}", (d['threads'], d['err_rate']), textcoords="offset points", xytext=(0,5), ha='center')
plt.xlabel('Threads')
plt.ylabel('Error Rate (%)')
plt.title(f'Error Rate vs Threads ({section_name})')
plt.legend()
plt.grid(True)

plt.tight_layout()
plt.show()
