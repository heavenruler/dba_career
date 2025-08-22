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

sections = ["IDC * 3 + GCP * 2", "IDC * 2 + GCP * 3"]

plt.figure(figsize=(12, 10))

# --- RPS subplot
plt.subplot(2, 1, 1)
for section_name in sections:
    section = extract_section(content, section_name)
    tidb_idc_table = extract_table(section, 'RPS From TiDB with IDC')
    tiproxy_idc_table = extract_table(section, 'RPS From TiProxy with IDC')
    tidb_gcp_table = extract_table(section, 'RPS From TiDB with GCP')
    tiproxy_gcp_table = extract_table(section, 'RPS From TiProxy with GCP')

    tidb_idc_data = parse_table(tidb_idc_table)
    tiproxy_idc_data = parse_table(tiproxy_idc_table)
    tidb_gcp_data = parse_table(tidb_gcp_table)
    tiproxy_gcp_data = parse_table(tiproxy_gcp_table)

    plt.plot([d['threads'] for d in tidb_idc_data], [d['rps'] for d in tidb_idc_data],
             marker='o', label=f'{section_name} - TiDB IDC')
    plt.plot([d['threads'] for d in tiproxy_idc_data], [d['rps'] for d in tiproxy_idc_data],
             marker='o', label=f'{section_name} - TiProxy IDC')
    plt.plot([d['threads'] for d in tidb_gcp_data], [d['rps'] for d in tidb_gcp_data],
             marker='o', label=f'{section_name} - TiDB GCP')
    plt.plot([d['threads'] for d in tiproxy_gcp_data], [d['rps'] for d in tiproxy_gcp_data],
             marker='o', label=f'{section_name} - TiProxy GCP')

plt.xlabel('Threads')
plt.ylabel('RPS')
plt.title('RPS vs Threads (IDC * 3 + GCP * 2  vs  IDC * 2 + GCP * 3)')
plt.legend()
plt.grid(True)

# --- Error Rate subplot
plt.subplot(2, 1, 2)
for section_name in sections:
    section = extract_section(content, section_name)
    tidb_idc_table = extract_table(section, 'RPS From TiDB with IDC')
    tiproxy_idc_table = extract_table(section, 'RPS From TiProxy with IDC')
    tidb_gcp_table = extract_table(section, 'RPS From TiDB with GCP')
    tiproxy_gcp_table = extract_table(section, 'RPS From TiProxy with GCP')

    tidb_idc_data = parse_table(tidb_idc_table)
    tiproxy_idc_data = parse_table(tiproxy_idc_table)
    tidb_gcp_data = parse_table(tidb_gcp_table)
    tiproxy_gcp_data = parse_table(tiproxy_gcp_table)

    plt.plot([d['threads'] for d in tidb_idc_data], [d['err_rate'] for d in tidb_idc_data],
             marker='o', label=f'{section_name} - TiDB IDC')
    plt.plot([d['threads'] for d in tiproxy_idc_data], [d['err_rate'] for d in tiproxy_idc_data],
             marker='o', label=f'{section_name} - TiProxy IDC')
    plt.plot([d['threads'] for d in tidb_gcp_data], [d['err_rate'] for d in tidb_gcp_data],
             marker='o', label=f'{section_name} - TiDB GCP')
    plt.plot([d['threads'] for d in tiproxy_gcp_data], [d['err_rate'] for d in tiproxy_gcp_data],
             marker='o', label=f'{section_name} - TiProxy GCP')

plt.xlabel('Threads')
plt.ylabel('Error Rate (%)')
plt.title('Error Rate vs Threads (IDC * 3 + GCP * 2  vs  IDC * 2 + GCP * 3)')
plt.legend()
plt.grid(True)

plt.tight_layout()
plt.show()

