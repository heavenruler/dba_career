import matplotlib.pyplot as plt
import re

with open('rps.md', 'r', encoding='utf-8') as f:
    content = f.read()

# Extract IDC * 1 and IDC * 3 sections
idc1_section = re.search(r'- IDC \* 1(.*?)(={5,}|- GCP \* 1)', content, re.DOTALL)
idc3_section = re.search(r'- IDC \* 3(.*?)(={5,}|- GCP \* 3)', content, re.DOTALL)
if not idc1_section or not idc3_section:
    raise ValueError("IDC * 1 or IDC * 3 section not found")
idc1_text = idc1_section.group(1)
idc3_text = idc3_section.group(1)

tables = [
    ("RPS From TiDB passthrough A10 NAT", "TiDB-NAT", "blue"),
    ("RPS From TiProxy passthrough A10 NAT", "TiProxy-NAT", "green"),
]

def parse_table(table_title, section_text):
    match = re.search(rf"{re.escape(table_title)}\n```(.*?)```", section_text, re.DOTALL)
    if not match:
        return []
    table = match.group(1)
    lines = [line for line in table.strip().split('\n') if line.strip()]
    data = []
    for line in lines:
        if line.startswith("multi_thread_multi_conn"):
            parts = re.split(r'\s{2,}', line.strip())
            if len(parts) == 7:
                data.append({
                    'threads': int(parts[6]),
                    'error_rate': float(parts[3]),
                    'rps': float(parts[5])
                })
    return data

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10,10), sharex=True)

for table_title, label, color in tables:
    # IDC * 1
    data1 = parse_table(table_title, idc1_text)
    threads1 = [d['threads'] for d in data1]
    rps1 = [d['rps'] for d in data1]
    error_rate1 = [d['error_rate'] for d in data1]
    ax1.plot(threads1, rps1, marker='o', label=f'{label} IDC*1', color=color, linestyle='-')
    for x, y in zip(threads1, rps1):
        ax1.text(x, y, f'{y:.2f}', ha='center', va='bottom', fontsize=8, color=color)
    ax2.plot(threads1, error_rate1, marker='x', label=f'{label} IDC*1', color=color, linestyle='-')
    for x, y in zip(threads1, error_rate1):
        ax2.text(x, y, f'{y:.2f}', ha='center', va='bottom', fontsize=8, color=color)
    # IDC * 3
    data3 = parse_table(table_title, idc3_text)
    threads3 = [d['threads'] for d in data3]
    rps3 = [d['rps'] for d in data3]
    error_rate3 = [d['error_rate'] for d in data3]
    ax1.plot(threads3, rps3, marker='o', label=f'{label} IDC*3', color=color, linestyle='--')
    for x, y in zip(threads3, rps3):
        ax1.text(x, y, f'{y:.2f}', ha='center', va='bottom', fontsize=8, color=color)
    ax2.plot(threads3, error_rate3, marker='x', label=f'{label} IDC*3', color=color, linestyle='--')
    for x, y in zip(threads3, error_rate3):
        ax2.text(x, y, f'{y:.2f}', ha='center', va='bottom', fontsize=8, color=color)

ax1.set_ylabel('RPS (Req/sec)')
ax1.set_title('IDC * 1 & IDC * 3 - RPS Line Chart')
ax1.grid(True)
ax1.legend(loc='upper left')

ax2.set_xlabel('Threads')
ax2.set_ylabel('Error Rate (%)')
ax2.set_title('IDC * 1 & IDC * 3 - Error Rate Line Chart')
ax2.grid(True)
ax2.legend(loc='upper left')

plt.tight_layout()
plt.show()
