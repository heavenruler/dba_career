import matplotlib.pyplot as plt
import re

def read_markdown(file_path: str) -> str:
    with open(file_path, 'r', encoding='utf-8') as f:
        return f.read()

def extract_section(content: str, section_header: str) -> str:
    pattern = rf"- {re.escape(section_header)}\n(.*?)(?=\n- |\Z)"
    match = re.search(pattern, content, re.DOTALL)
    return match.group(1).strip() if match else ''

def extract_table(section: str, title: str) -> str:
    pattern = rf"{re.escape(title)}\n```(.*?)```"
    match = re.search(pattern, section, re.DOTALL)
    return match.group(1).strip() if match else ''

def parse_table(table_text: str):
    rows = []
    for line in table_text.splitlines():
        line = line.rstrip()
        if not line or line.startswith('Test Type') or set(line) == {'-'}:
            continue
        if line.startswith('multi_thread_multi_conn'):
            parts = re.split(r"\s{2,}", line.strip())
            if len(parts) >= 7:
                try:
                    threads = int(parts[-1])
                    rps = float(parts[-2])
                    err_rate = float(parts[-4])
                    rows.append({
                        'threads': threads,
                        'rps': rps,
                        'err_rate': err_rate,
                    })
                except ValueError:
                    continue
    return sorted(rows, key=lambda x: x['threads'])

def plot_groups(groups, section_names):
    plt.figure(figsize=(10, 10))
    color_map = {
        'TiDB_IDC': 'tab:blue',
        'TiProxy_IDC': 'tab:green',
        'TiDB_GCP': 'tab:orange',
        'TiProxy_GCP': 'tab:red',
    }
    style_map = {'TiDB': 'solid', 'TiProxy': 'dashed'}

    def get_color(label):
        if 'IDC' in label:
            loc = 'IDC'
        else:
            loc = 'GCP'
        if 'TiProxy' in label:
            typ = 'TiProxy'
        else:
            typ = 'TiDB'
        return color_map[f'{typ}_{loc}']

    # RPS subplot
    plt.subplot(2, 1, 1)
    for section, data_groups in groups.items():
        linestyle = 'solid' if section == 'IDC * 3 + GCP * 2' else 'dashed'
        for label, data in data_groups.items():
            if not data:
                continue
            color = get_color(label)
            x = [d['threads'] for d in data]
            y = [d['rps'] for d in data]
            plt.plot(x, y, marker='o', label=f"{section}: {label}", color=color, linestyle=linestyle)
            for d in data:
                # 偶數 threads 右上，奇數 threads 左下
                if d['threads'] % 2 == 0:
                    xytext = (10, -10)
                    ha = 'left'
                else:
                    xytext = (-10, 10)
                    ha = 'right'
                plt.annotate(
                    f"{d['rps']:.0f}",
                    (d['threads'], d['rps']),
                    textcoords="offset points",
                    xytext=xytext,
                    ha=ha,
                    fontsize=7,
                    color=color,
                    bbox=dict(boxstyle="round,pad=0.2", fc="white", ec="none", alpha=0.5)
                )
    plt.xlabel('Threads')
    plt.ylabel('RPS')
    plt.title('RPS vs Threads')
    plt.legend()
    plt.grid(True)

    # Error Rate subplot
    plt.subplot(2, 1, 2)
    for section, data_groups in groups.items():
        linestyle = 'solid' if section == 'IDC * 3 + GCP * 2' else 'dashed'
        for label, data in data_groups.items():
            if not data:
                continue
            color = get_color(label)
            x = [d['threads'] for d in data]
            y = [d['err_rate'] for d in data]
            plt.plot(x, y, marker='o', label=f"{section}: {label}", color=color, linestyle=linestyle)
            for d in data:
                if d['threads'] % 2 == 0:
                    xytext = (10, -10)
                    ha = 'left'
                else:
                    xytext = (-10, 10)
                    ha = 'right'
                plt.annotate(
                    f"{d['err_rate']:.2f}",
                    (d['threads'], d['err_rate']),
                    textcoords="offset points",
                    xytext=xytext,
                    ha=ha,
                    fontsize=7,
                    color=color,
                    bbox=dict(boxstyle="round,pad=0.2", fc="white", ec="none", alpha=0.5)
                )
    plt.xlabel('Threads')
    plt.ylabel('Error Rate (%)')
    plt.title('Error Rate vs Threads')
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.show()

def main():
    md_path = 'rps.md'
    section_headers = [
        'IDC * 3 + GCP * 2',
        'IDC * 2 + GCP * 3',
    ]
    titles = [
        'RPS From TiDB with IDC',
        'RPS From TiProxy with IDC',
        'RPS From TiDB with GCP',
        'RPS From TiProxy with GCP',
    ]
    content = read_markdown(md_path)
    groups = {}
    for section_header in section_headers:
        section = extract_section(content, section_header)
        if not section:
            continue
        tables = {title: extract_table(section, title) for title in titles}
        data_groups = {title: parse_table(table_text) for title, table_text in tables.items()}
        groups[section_header] = data_groups
    plot_groups(groups, section_headers)

if __name__ == '__main__':
    main()
