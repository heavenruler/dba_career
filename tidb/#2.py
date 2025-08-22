import matplotlib.pyplot as plt
import re

# Read rps.md
with open('rps.md', 'r', encoding='utf-8') as f:
    content = f.read()

sections = [
    ("RPS From TiDB ; Connect From IDC", "TiDB-From IDC", "blue"),
    ("RPS From TiProxy ; Connect From IDC", "TiProxy-From IDC", "green"),
    ("RPS From TiDB ; Connect From GCP", "TiDB-From GCP", "red"),
    ("RPS From TiProxy ; Connect From GCP", "TiProxy-From GCP", "orange"),
]

def parse_table(section_title):
    match = re.search(rf"{re.escape(section_title)}\n```(.*?)```", content, re.DOTALL)
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

for section_title, label, color in sections:
    data = parse_table(section_title)
    threads = [d['threads'] for d in data]
    rps = [d['rps'] for d in data]
    error_rate = [d['error_rate'] for d in data]
    # RPS line
    ax1.plot(threads, rps, marker='o', label=label, color=color)
    for x, y in zip(threads, rps):
        ax1.text(x, y, f'{y:.2f}', ha='center', va='bottom', fontsize=8, color=color)
    # Error rate line
    ax2.plot(threads, error_rate, marker='x', linestyle='--', label=label, color=color)
    for x, y in zip(threads, error_rate):
        ax2.text(x, y, f'{y:.2f}', ha='center', va='bottom', fontsize=8, color=color)

ax1.set_ylabel('RPS (Req/sec)')
ax1.set_title('GCP * 1 - RPS Line Chart')
ax1.grid(True)
ax1.legend(loc='upper left')

ax2.set_xlabel('Threads')
ax2.set_ylabel('Error Rate (%)')
ax2.set_title('GCP * 1 - Error Rate Line Chart')
ax2.grid(True)
ax2.legend(loc='upper left')

plt.tight_layout()
plt.show()
