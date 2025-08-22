import matplotlib.pyplot as plt
import re

# Read rps.md
with open('rps.md', 'r', encoding='utf-8') as f:
    content = f.read()

# Extract the "- IDC * 3" section
idc3_section = re.search(r'- IDC \* 3(.*?)(={5,}|- GCP \* 3)', content, re.DOTALL)
if not idc3_section:
    raise ValueError("IDC * 3 section not found")
section_text = idc3_section.group(1)

tables = [
    ("RPS From TiDB passthrough A10 NAT", "TiDB-NAT", "blue"),
    ("RPS From TiProxy passthrough A10 NAT", "TiProxy-NAT", "green"),
]

def parse_table(table_title):
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
    data = parse_table(table_title)
    threads = [d['threads'] for d in data]
    rps = [d['rps'] for d in data]
    error_rate = [d['error_rate'] for d in data]
    ax1.plot(threads, rps, marker='o', label=label, color=color)
    for x, y in zip(threads, rps):
        ax1.text(x, y, f'{y:.2f}', ha='center', va='bottom', fontsize=8, color=color)
    ax2.plot(threads, error_rate, marker='x', linestyle='--', label=label, color=color)
    for x, y in zip(threads, error_rate):
        ax2.text(x, y, f'{y:.2f}', ha='center', va='bottom', fontsize=8, color=color)

ax1.set_ylabel('RPS (Req/sec)')
ax1.set_title('IDC * 3 - RPS Line Chart')
ax1.grid(True)
ax1.legend(loc='upper left')

ax2.set_xlabel('Threads')
ax2.set_ylabel('Error Rate (%)')
ax2.set_title('IDC * 3 - Error Rate Line Chart')
ax2.grid(True)
ax2.legend(loc='upper left')

plt.tight_layout()
plt.show()
