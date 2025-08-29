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


def plot_sections(data_sections):
    # 建立兩個圖表：RPS 和 Error Rate（上下排列）
    plt.figure(figsize=(10, 10))
    
    # 為不同區段使用不同顏色和標記
    colors = ['blue', 'red', 'green', 'orange', 'purple', 'brown']
    markers = ['o', 's', '^', 'D', 'v', '<']
    
    # RPS subplot (上方)
    plt.subplot(2, 1, 1)
    for i, (section_name, data_groups) in enumerate(data_sections.items()):
        for j, (label, data) in enumerate(data_groups.items()):
            if not data:
                continue
            
            # 為每個系列添加區段名稱前綴以區分
            series_label = f"{section_name} - {label}"
            color = colors[(i * len(data_groups) + j) % len(colors)]
            marker = markers[(i * len(data_groups) + j) % len(markers)]
            
            x = [d['threads'] for d in data]
            y_rps = [d['rps'] for d in data]
            
            plt.plot(x, y_rps, marker=marker, color=color, label=series_label, linewidth=2, markersize=6)
            for d in data:
                plt.annotate(f"{d['rps']:.0f}", (d['threads'], d['rps']), 
                           textcoords="offset points", xytext=(0, 5), ha='center', fontsize=8)
    
    plt.xlabel('Threads')
    plt.ylabel('RPS')
    plt.title('RPS vs Threads (All Sections)')
    plt.legend()
    plt.grid(True)

    # Error Rate subplot (下方)
    plt.subplot(2, 1, 2)
    for i, (section_name, data_groups) in enumerate(data_sections.items()):
        for j, (label, data) in enumerate(data_groups.items()):
            if not data:
                continue
            
            # 為每個系列添加區段名稱前綴以區分
            series_label = f"{section_name} - {label}"
            color = colors[(i * len(data_groups) + j) % len(colors)]
            marker = markers[(i * len(data_groups) + j) % len(markers)]
            
            x = [d['threads'] for d in data]
            y_err = [d['err_rate'] for d in data]
            
            plt.plot(x, y_err, marker=marker, color=color, label=series_label, linewidth=2, markersize=6)
            for d in data:
                plt.annotate(f"{d['err_rate']:.2f}", (d['threads'], d['err_rate']), 
                           textcoords="offset points", xytext=(0, 5), ha='center', fontsize=8)
    
    plt.xlabel('Threads')
    plt.ylabel('Error Rate (%)')
    plt.title('Error Rate vs Threads (All Sections)')
    plt.legend()
    plt.grid(True)

    plt.tight_layout()
    plt.show()


def main():
    md_path = 'rps.md'
    content = read_markdown(md_path)
    
    # 定義要處理的區段
    sections = [
        'IDC * 3',
        'tidb numbers updated 3 to 9.'
    ]
    
    all_data_sections = {}
    
    for section_name in sections:
        section = extract_section(content, section_name)
        if not section:
            print(f"Warning: Section not found: - {section_name}")
            continue
            
        # 根據區段名稱定義要提取的表格標題
        if section_name == 'IDC * 3':
            titles = [
                'RPS From TiProxy passthrough A10 NAT'
            ]
        elif section_name == 'tidb numbers updated 3 to 9.':
            titles = [
                'RPS by TiProxy from IDC'
            ]
        else:
            continue
            
        tables = {title: extract_table(section, title) for title in titles}
        data_groups = {title: parse_table(table_text) for title, table_text in tables.items()}
        all_data_sections[section_name] = data_groups
    
    if all_data_sections:
        plot_sections(all_data_sections)
    else:
        print("No valid sections found!")


if __name__ == '__main__':
    main()
