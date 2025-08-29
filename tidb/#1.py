#!/usr/bin/env python3
"""#1.py
Compare multi_thread_multi_conn RPS scaling: TiDB vs TiProxy (IDC Peak).

Source: two benchmark blocks pasted below (only multi_thread_multi_conn lines used).

Output: #1.png (grouped bar chart), #1.csv (raw + delta dataset).

Design:
 - Grouped bars per thread: left=TiDB, right=TiProxy.
 - Delta labels above groups: TiProxy vs TiDB percentage difference.
 - Baseline vertical guideline at 100 threads; horizontal lines optional.
 - Color convention: TiDB = #1f77b4, TiProxy = #ff7f0e, delta label color red if TiProxy>TiDB, green if lower.
"""
from __future__ import annotations
import re, csv, math

RAW_TIDB = r"""
multi_thread_multi_conn   10000           1.651                0.00            16.519          605.37          1
multi_thread_multi_conn   10000           7.678                0.00            0.960           10417.45        100
multi_thread_multi_conn   10000           11.915               0.00            0.928           10776.75        200
multi_thread_multi_conn   10000           11.001               0.00            0.974           10265.02        250
multi_thread_multi_conn   10000           10.173               0.00            1.370           7297.53         500
multi_thread_multi_conn   10000           11.506               0.00            1.712           5842.36         750
multi_thread_multi_conn   10000           12.758               0.00            1.985           5038.69         1000
"""

RAW_TIPROXY = r"""
multi_thread_multi_conn   10000           2.649                0.00            26.498          377.38          1
multi_thread_multi_conn   10000           12.050               0.00            1.382           7237.95         100
multi_thread_multi_conn   10000           22.407               0.00            1.335           7493.05         200
multi_thread_multi_conn   10000           28.697               0.00            2.405           4157.55         250
multi_thread_multi_conn   10000           46.040               0.00            1.609           6213.77         500
multi_thread_multi_conn   10000           35.432               0.00            4.727           2115.66         750
multi_thread_multi_conn   10000           29.681               0.00            2.146           4658.88         1000
"""

ROW_RE = re.compile(r"multi_thread_multi_conn\s+"  # label
                    r"(\d+)\s+"                      # total tests
                    r"([0-9.]+)\s+"                  # avg ms
                    r"([0-9.]+)\s+"                  # err %
                    r"([0-9.]+)\s+"                  # total time s
                    r"([0-9.]+)\s+"                  # rps
                    r"(\d+)")                        # threads

def parse(raw: str):
    out = []
    for line in raw.splitlines():
        m = ROW_RE.search(line)
        if m:
            total, avg_ms, err, total_time, rps, threads = m.groups()
            out.append((int(threads), float(rps), float(avg_ms), float(err)))
    out.sort(key=lambda r: r[0])
    return out

tidb = parse(RAW_TIDB)
tiproxy = parse(RAW_TIPROXY)

# Merge on thread counts present in either dataset
threads = sorted({t for t, *_ in tidb} | {t for t, *_ in tiproxy})
rows = []  # (threads, tidb_rps, tiproxy_rps, delta_pct, tidb_avg_ms, tiproxy_avg_ms)
tidb_map = {t: (rps, avg, err) for t,rps,avg,err in tidb}
tiproxy_map = {t: (rps, avg, err) for t,rps,avg,err in tiproxy}
for t in threads:
    tr = tidb_map.get(t)
    pr = tiproxy_map.get(t)
    if not tr or not pr:
        continue  # skip unmatched thread counts
    tidb_rps, tidb_avg, _ = tr
    tiproxy_rps, tiproxy_avg, _ = pr
    delta = (tiproxy_rps - tidb_rps) / tidb_rps * 100 if tidb_rps else 0.0
    rows.append((t, tidb_rps, tiproxy_rps, delta, tidb_avg, tiproxy_avg))

def write_csv():
    with open('#1.csv','w',newline='') as f:
        w=csv.writer(f)
        w.writerow(['threads','tidb_rps','tiproxy_rps','delta_pct','tidb_avg_ms','tiproxy_avg_ms'])
        for r in rows:
            w.writerow(r)
    print('[OK] Wrote #1.csv')

def plot():
    try:
        import matplotlib.pyplot as plt
    except Exception:
        print('[WARN] matplotlib not installed; skipping #1.png')
        return
    t = [r[0] for r in rows]
    tidb_rps = [r[1] for r in rows]
    tip_rps = [r[2] for r in rows]
    delta = [r[3] for r in rows]
    width = 0.35
    x = range(len(t))
    fig, ax = plt.subplots(figsize=(9,5))
    ax.bar([i - width/2 for i in x], tidb_rps, width, label='TiDB', color='#1f77b4')
    ax.bar([i + width/2 for i in x], tip_rps, width, label='TiProxy', color='#ff7f0e')
    ax.set_xticks(list(x))
    ax.set_xticklabels([str(i) for i in t])
    ax.set_xlabel('Threads')
    ax.set_ylabel('Requests per second')
    ax.set_title('multi_thread_multi_conn RPS (IDC Peak): TiDB vs TiProxy')
    # Baseline vertical line at thread 100 if present
    if 100 in t:
        idx = t.index(100)
        ax.axvline(idx, color='#444', linestyle='--', linewidth=1)
        ax.text(idx, max(max(tidb_rps), max(tip_rps))*1.02, '100-thread baseline', ha='center', va='bottom', fontsize=8, color='#000')
    # Delta labels
    for i, (thr, trps, prps, d) in enumerate(rows):
        color = '#d62728' if d > 0 else ('#2ca02c' if d < 0 else '#000000')
        ax.text(i, max(trps, prps)*1.01, f"{d:+.1f}%", ha='center', va='bottom', fontsize=8, color=color)
    ax.legend(loc='upper right')
    fig.tight_layout()
    fig.savefig('#1.png', dpi=140)
    print('[OK] Saved #1.png')

def ascii():
    print('Threads | TiDB_RPS | TiProxy_RPS | Delta_%')
    print('--------+---------+-------------+--------')
    for t, tr, pr, d, *_ in rows:
        print(f"{t:>7} | {tr:7.2f} | {pr:11.2f} | {d:7.2f}")

def main():
    ascii()
    write_csv()
    plot()
    # Observations
    if rows:
        best = max(rows, key=lambda r: r[2])
        print(f"Peak TiProxy RPS {best[2]:.0f} at {best[0]} threads (delta {best[3]:+.1f}%).")
        worst_delta = min(rows, key=lambda r: r[3])
        print(f"Largest TiProxy underperformance {worst_delta[3]:+.1f}% at {worst_delta[0]} threads.")

if __name__ == '__main__':
    main()
