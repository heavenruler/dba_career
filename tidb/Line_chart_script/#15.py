import re
import matplotlib.pyplot as plt


def read_markdown(file_path: str) -> str:
    with open(file_path, 'r', encoding='utf-8') as f:
        return f.read()


def extract_section(content: str, section_header: str) -> str:
    # 抓取指定章節到下一個以 '- ' 開頭的章節或文件結尾
    pattern = rf"- {re.escape(section_header)}\n(.*?)(?=\n- |\Z)"
    match = re.search(pattern, content, re.DOTALL)
    return match.group(1).strip() if match else ''


def extract_table(section: str, title: str) -> str:
    # 取出 title 底下第一個 markdown code block 的內容
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
            # 以兩個以上空白切割欄位
            parts = re.split(r"\s{2,}", line.strip())
            # 預期欄位：Test Type, Total Tests, Avg Response (ms), Error Rate %, Total Time (s), Req/sec, Threads
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
                    # 跳過不合法數值列
                    continue
    return sorted(rows, key=lambda x: x['threads'])


def plot_section(data_groups, section_header: str):
    plt.figure(figsize=(10, 10))

    # RPS subplot
    plt.subplot(2, 1, 1)
    for label, data in data_groups.items():
        if not data:
            continue
        x = [d['threads'] for d in data]
        y = [d['rps'] for d in data]
        plt.plot(x, y, marker='o', label=label)
        for d in data:
            plt.annotate(f"{d['rps']:.0f}", (d['threads'], d['rps']), textcoords="offset points", xytext=(0, 5), ha='center')
    plt.xlabel('Threads')
    plt.ylabel('RPS')
    plt.title(f'RPS vs Threads ({section_header})')
    plt.legend()
    plt.grid(True)

    # Error Rate subplot
    plt.subplot(2, 1, 2)
    for label, data in data_groups.items():
        if not data:
            continue
        x = [d['threads'] for d in data]
        y = [d['err_rate'] for d in data]
        plt.plot(x, y, marker='o', label=label)
        for d in data:
            plt.annotate(f"{d['err_rate']:.2f}", (d['threads'], d['err_rate']), textcoords="offset points", xytext=(0, 5), ha='center')
    plt.xlabel('Threads')
    plt.ylabel('Error Rate (%)')
    plt.title(f'Error Rate vs Threads ({section_header})')
    plt.legend()
    plt.grid(True)

    plt.tight_layout()
    plt.show()


def main():
    md_path = 'rps.md'
    section_header = 'proxy.local-tidb-only: true Enabled.'
    content = read_markdown(md_path)

    section = extract_section(content, section_header)
    if not section:
        raise SystemExit(f"Section not found: - {section_header}")

    titles = [
        'RPS by TiDB from IDC',
        'RPS by TiProxy from IDC',
        'RPS by TiDB from GCP',
        'RPS by TiProxy from GCP',
    ]

    tables = {title: extract_table(section, title) for title in titles}
    data_groups = {title: parse_table(table_text) for title, table_text in tables.items()}

    plot_section(data_groups, section_header)


if __name__ == '__main__':
    main()