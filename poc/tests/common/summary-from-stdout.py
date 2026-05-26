#!/usr/bin/env python3
"""Parse go-tpc stdout artifacts and write summary.json per suite.

Usage:
  summary-from-stdout.py <suite_artifact_dir>

Designed as a one-shot retrofit tool for existing v4.7 suite results
that pre-date the summary.json convention. Output is intentionally
flat: 5-round mean tpmC / latency / error-rate per thread group, plus
per-round tpmC list for variance checks.

Error rate口徑 (per F-001 audit decision 2026-05-21):
  * NEW_ORDER err rate    = NEW_ORDER_ERR / (NEW_ORDER + NEW_ORDER_ERR)
  * All-txn err rate      = sum(*_ERR) / sum(* + *_ERR)
  * 兩種都 dump，README index 採 all_txn.error_rate_pct (per-thread mean)
"""
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from statistics import mean

TXN_TYPES = ("NEW_ORDER", "PAYMENT", "DELIVERY", "ORDER_STATUS", "STOCK_LEVEL")

TPMCS_RE = re.compile(
    r"tpmC:\s*([\d.]+),\s*tpmTotal:\s*([\d.]+),\s*efficiency:\s*([\d.]+)%"
)
SUMMARY_RE = re.compile(
    r"\[Summary\]\s+(\S+)\s+-\s+Takes\(s\):\s+\S+,\s+Count:\s+(\d+),"
    r"\s+TPM:\s+\S+,\s+Sum\(ms\):\s+\S+,\s+Avg\(ms\):\s+\S+,"
    r"\s+50th\(ms\):\s+([\d.]+),\s+90th\(ms\):\s+\S+,"
    r"\s+95th\(ms\):\s+([\d.]+),\s+99th\(ms\):\s+([\d.]+)"
)
SUITE_NAME_RE = re.compile(
    r"(tidb|crdb|ybdb)-(.+)-(rc|rr|strict)-(\d{8}T\d{6}\+\d{4})"
)


def parse_round(stdout_path):
    txns = {t: {"count": 0, "p50": None, "p95": None, "p99": None} for t in TXN_TYPES}
    errs = {t: 0 for t in TXN_TYPES}
    tpmC = tpmTotal = eff = None

    with open(stdout_path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if line.startswith("[Summary]"):
                m = SUMMARY_RE.match(line)
                if not m:
                    continue
                name, count, p50, p95, p99 = (
                    m.group(1),
                    int(m.group(2)),
                    float(m.group(3)),
                    float(m.group(4)),
                    float(m.group(5)),
                )
                if name in txns:
                    txns[name] = {"count": count, "p50": p50, "p95": p95, "p99": p99}
                elif name.endswith("_ERR"):
                    base = name[: -len("_ERR")]
                    if base in errs:
                        errs[base] = count
            elif line.startswith("tpmC:"):
                m = TPMCS_RE.match(line)
                if m:
                    tpmC = float(m.group(1))
                    tpmTotal = float(m.group(2))
                    eff = float(m.group(3))

    return {
        "tpmC": tpmC,
        "tpmTotal": tpmTotal,
        "efficiency_pct": eff,
        "txns": txns,
        "errs": errs,
    }


def mean_or_none(seq):
    seq = [x for x in seq if x is not None]
    return round(mean(seq), 1) if seq else None


def aggregate_thread_group(round_results):
    tpmCs = [r["tpmC"] for r in round_results if r["tpmC"] is not None]
    tpmC_mean = mean_or_none(tpmCs)
    range_pct = None
    if tpmCs and tpmC_mean:
        range_pct = round((max(tpmCs) - min(tpmCs)) / tpmC_mean * 100, 1)

    no_p50 = mean_or_none([r["txns"]["NEW_ORDER"]["p50"] for r in round_results])
    no_p95 = mean_or_none([r["txns"]["NEW_ORDER"]["p95"] for r in round_results])
    no_p99 = mean_or_none([r["txns"]["NEW_ORDER"]["p99"] for r in round_results])

    no_total = sum(r["txns"]["NEW_ORDER"]["count"] for r in round_results)
    no_errs = sum(r["errs"]["NEW_ORDER"] for r in round_results)
    all_total = sum(r["txns"][t]["count"] for r in round_results for t in TXN_TYPES)
    all_errs = sum(r["errs"][t] for r in round_results for t in TXN_TYPES)

    def rate(numer, denom):
        return round(numer / denom * 100, 3) if denom > 0 else 0.0

    return {
        "tpmC_mean": tpmC_mean,
        "tpmC_per_round": [round(t, 1) for t in tpmCs],
        "tpmC_range_mean_pct": range_pct,
        "tpmTotal_mean": mean_or_none([r["tpmTotal"] for r in round_results]),
        "efficiency_mean_pct": mean_or_none(
            [r["efficiency_pct"] for r in round_results]
        ),
        "NEW_ORDER": {
            "p50_mean_ms": no_p50,
            "p95_mean_ms": no_p95,
            "p99_mean_ms": no_p99,
            "total_count": no_total,
            "error_count": no_errs,
            "error_rate_pct": rate(no_errs, no_total + no_errs),
        },
        "all_txn": {
            "total_count": all_total,
            "error_count": all_errs,
            "error_rate_pct": rate(all_errs, all_total + all_errs),
        },
    }


def main():
    if len(sys.argv) < 2:
        print(f"usage: {sys.argv[0]} <suite_artifact_dir>", file=sys.stderr)
        sys.exit(1)

    suite_dir = Path(sys.argv[1])
    if not suite_dir.is_dir():
        print(f"error: {suite_dir} not a directory", file=sys.stderr)
        sys.exit(1)

    m = SUITE_NAME_RE.match(suite_dir.name)
    if not m:
        print(
            f"error: cannot parse suite name {suite_dir.name}",
            file=sys.stderr,
        )
        sys.exit(1)
    db, topology, iso, ts = m.group(1), m.group(2), m.group(3), m.group(4)

    runs_dir = suite_dir / "runs"
    if not runs_dir.exists():
        print(f"error: no runs/ in {suite_dir}", file=sys.stderr)
        sys.exit(1)

    threads = sorted(int(d.name.split("-")[1]) for d in runs_dir.glob("threads-*"))
    summary = {
        "schema_version": 1,
        "db": db,
        "topology": topology,
        "iso": iso,
        "ts": ts,
        "warehouses": 128,
        "rounds_per_thread_group": 5,
        "threads_list": threads,
        "thread_results": {},
        "generated_at": datetime.now().astimezone().isoformat(),
        "generated_by": "tests/common/summary-from-stdout.py v1",
        "source_files": "runs/threads-*/round-*/go-tpc-stdout.txt",
    }

    for t in threads:
        rounds = sorted(
            (runs_dir / f"threads-{t}").glob("round-*/go-tpc-stdout.txt")
        )
        round_results = [parse_round(r) for r in rounds]
        summary["thread_results"][str(t)] = aggregate_thread_group(round_results)

    out_path = suite_dir / "summary.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
