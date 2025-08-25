import re
import matplotlib.pyplot as plt
from dataclasses import dataclass
from typing import List

MD_FILE = 'rps.md'
SECTION_HEADER = 'Mix GCP / IDC Galera Cluster'

@dataclass
class RpsResult:
    """Represents a single row of parsed RPS benchmark results."""
    threads: int
    req_per_sec: float
    error_rate: float

    @classmethod
    def from_line(cls, line: str) -> 'RpsResult':
        """Parses a single line from the RPS output table."""
        parts = re.split(r'\s{2,}', line.strip())
        if len(parts) < 7:
            raise ValueError("Line does not have enough columns to parse")
        
        threads = int(parts[6])
        req_per_sec = float(parts[5])
        error_rate = float(parts[3])
        
        return cls(threads=threads, req_per_sec=req_per_sec, error_rate=error_rate)

def read_md(path: str) -> str:
    """Reads the entire content of a file."""
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def extract_section(content: str, header: str) -> str:
    """Extracts a specific section from markdown content based on a header."""
    pattern = rf"- {re.escape(header)}\n(.*?)(?=\n- |\n==================================|\Z)"
    m = re.search(pattern, content, re.DOTALL)
    return m.group(1).strip() if m else ''

def parse_rps_table(block: str) -> List[RpsResult]:
    """Parses a text block containing an RPS result table."""
    rows = []
    for line in block.splitlines():
        line = line.strip()
        if line.startswith('multi_thread_multi_conn_random_node'):
            try:
                rows.append(RpsResult.from_line(line))
            except (ValueError, IndexError) as e:
                print(f"Skipping unparsable line: {line} ({e})")
                continue
    return rows

def plot_rps_performance(results: List[RpsResult]):
    """Creates and shows the plot for RPS performance."""
    if not results:
        print("No data to plot.")
        return

    results.sort(key=lambda r: r.threads)
    threads = [r.threads for r in results]
    avg_response = [r.avg_response_ms for r in results]
    req_sec = [r.req_per_sec for r in results]

    fig, ax1 = plt.subplots(figsize=(12, 7))
    fig.suptitle(f'RPS Performance for "{SECTION_HEADER}"', fontsize=16)

    # Plot Avg Response Time
    color1 = 'tab:red'
    ax1.set_xlabel('Number of Threads (log scale)')
    ax1.set_ylabel('Avg Response (ms)', color=color1)
    line1 = ax1.plot(threads, avg_response, color=color1, marker='o', label='Avg Response (ms)')
    ax1.tick_params(axis='y', labelcolor=color1)
    ax1.set_xscale('log')
    ax1.set_xticks(threads)
    ax1.get_xaxis().set_major_formatter(plt.ScalarFormatter())

    for i, txt in enumerate(avg_response):
        ax1.annotate(f'{txt:.2f}', (threads[i], avg_response[i]), textcoords="offset points", xytext=(0,10), ha='center', color=color1)

    # Create a second y-axis for Req/sec
    ax2 = ax1.twinx()
    color2 = 'tab:blue'
    ax2.set_ylabel('Requests/sec', color=color2)
    line2 = ax2.plot(threads, req_sec, color=color2, marker='s', label='Requests/sec')
    ax2.tick_params(axis='y', labelcolor=color2)

    for i, txt in enumerate(req_sec):
        ax2.annotate(f'{txt:.2f}', (threads[i], req_sec[i]), textcoords="offset points", xytext=(0,-20), ha='center', color=color2)

    # Add a legend
    lines = line1 + line2
    labels = [l.get_label() for l in lines]
    ax1.legend(lines, labels, loc='upper center')

    ax1.grid(True, which='major', axis='y', linestyle='--', linewidth=0.5)
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    plt.show()

def main():
    """Main function to read, parse, and plot data."""
    content = read_md(MD_FILE)
    section_content = extract_section(content, SECTION_HEADER)
    
    if not section_content:
        print(f"Could not find section: {SECTION_HEADER}")
        return

    data = parse_rps_table(section_content)
    
    if not data:
        print("Could not parse data from the section.")
        return
        
    plot_rps_performance(data)

if __name__ == '__main__':
    main()
