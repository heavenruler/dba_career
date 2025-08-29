import re
import matplotlib.pyplot as plt

MD = 'rps.md'

def read_md(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def extract_section(content, section_name):
    pattern = rf'- {re.escape(section_name)}\n(.*?)(?=\n- [A-Z0-9]|\Z)'
    m = re.search(pattern, content, re.DOTALL)
    return m.group(1) if m else ''

def extract_table(section, title):
    pattern = rf'{re.escape(title)}\n```(.*?)```'
    m = re.search(pattern, section, re.DOTALL)
    return m.group(1).strip() if m else ''

def parse_table(table_text):
    rows = []
    if not table_text:
        return rows
    for line in table_text.splitlines():
        if line.startswith('multi_thread_multi_conn'):
            parts = re.split(r'\s{2,}', line.strip())
            if len(parts) == 7:
                _, _, avg_resp, err_rate, _, rps, threads = parts
                rows.append({
                    'threads': int(threads),
                    'rps': float(rps),
                    'err_rate': float(err_rate)
                })
    # sort by threads
    return sorted(rows, key=lambda x: x['threads'])

def load_section_data(content, section_name):
    sec = extract_section(content, section_name)
    data = {}
    data['tidb_idc'] = parse_table(extract_table(sec, 'RPS From TiDB with IDC'))
    data['tiproxy_idc'] = parse_table(extract_table(sec, 'RPS From TiProxy with IDC'))
    data['tidb_gcp'] = parse_table(extract_table(sec, 'RPS From TiDB with GCP'))
    data['tiproxy_gcp'] = parse_table(extract_table(sec, 'RPS From TiProxy with GCP'))
    return data

content = read_md(MD)
secA_name = 'IDC * 2 + GCP * 1'
secB_name = 'IDC * 1 + GCP * 2'
A = load_section_data(content, secA_name)
B = load_section_data(content, secB_name)

plt.figure(figsize=(11,10))

colors = {'tidb_idc':'C0','tiproxy_idc':'C1','tidb_gcp':'C2','tiproxy_gcp':'C3'}

# RPS subplot
ax = plt.subplot(2,1,1)
for key in ['tidb_idc','tiproxy_idc','tidb_gcp','tiproxy_gcp']:
    for data, label_suffix, ls in [(A, f'{key} ({secA_name})', '-'), (B, f'{key} ({secB_name})', '--')]:
        pts = data.get(key, [])
        if not pts: continue
        xs = [p['threads'] for p in pts]
        ys = [p['rps'] for p in pts]
        ax.plot(xs, ys, marker='o', linestyle=ls, color=colors[key], label=label_suffix)
        for x,y in zip(xs,ys):
            ax.annotate(f"{y:.0f}", (x,y), textcoords="offset points", xytext=(0,6), ha='center', fontsize=8)
ax.set_xlabel('Threads')
ax.set_ylabel('RPS')
ax.set_title(f'RPS comparison: {secA_name} vs {secB_name}')
ax.grid(True)
ax.legend(fontsize=8)

# Error Rate subplot
ax2 = plt.subplot(2,1,2)
for key in ['tidb_idc','tiproxy_idc','tidb_gcp','tiproxy_gcp']:
    for data, label_suffix, ls in [(A, f'{key} ({secA_name})', '-'), (B, f'{key} ({secB_name})', '--')]:
        pts = data.get(key, [])
        if not pts: continue
        xs = [p['threads'] for p in pts]
        ys = [p['err_rate'] for p in pts]
        ax2.plot(xs, ys, marker='o', linestyle=ls, color=colors[key], label=label_suffix)
        for x,y in zip(xs,ys):
            ax2.annotate(f"{y:.2f}", (x,y), textcoords="offset points", xytext=(0,6), ha='center', fontsize=8)
ax2.set_xlabel('Threads')
ax2.set_ylabel('Error Rate (%)')
ax2.set_title('Error Rate comparison')
ax2.grid(True)
ax2.legend(fontsize=8)

plt.tight_layout()
plt.show()
