#!/usr/bin/env python3
"""Generate a reproducible PMM/Prometheus capacity report for one MySQL instance."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import pathlib
import time
import urllib.error
import urllib.parse
import urllib.request


DEFAULT_ENDPOINT = "http://pmm.104.com.tw/prometheus"
REQUEST_TIMEOUT_SECONDS = 1.0
WARNINGS: list[str] = []


def prometheus_get(endpoint: str, path: str, params: dict[str, str]) -> dict:
    url = f"{endpoint.rstrip('/')}{path}?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url, timeout=REQUEST_TIMEOUT_SECONDS) as response:
        payload = json.load(response)
    if payload.get("status") != "success":
        raise RuntimeError(f"Prometheus query failed: {payload}")
    return payload["data"]


def range_values(endpoint: str, query: str, start: int, end: int, step: int) -> list[tuple[int, float]]:
    try:
        data = prometheus_get(
            endpoint,
            "/api/v1/query_range",
            {"query": query, "start": str(start), "end": str(end), "step": str(step)},
        )
    except (TimeoutError, urllib.error.URLError) as error:
        WARNINGS.append(f"Range query unavailable ({type(error).__name__}): `{query}`")
        return []
    values: list[tuple[int, float]] = []
    for series in data.get("result", []):
        values.extend(
            (int(timestamp), float(value))
            for timestamp, value in series.get("values", [])
            if value not in ("NaN", "+Inf", "-Inf")
        )
    return values


def instant_value(endpoint: str, query: str) -> float | None:
    try:
        data = prometheus_get(endpoint, "/api/v1/query", {"query": query})
    except (TimeoutError, urllib.error.URLError) as error:
        WARNINGS.append(f"Instant query unavailable ({type(error).__name__}): `{query}`")
        return None
    result = data.get("result", [])
    return float(result[0]["value"][1]) if result else None


def percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def fmt(value: float | None, decimals: int = 1) -> str:
    if value is None:
        return "N/A"
    return f"{value:,.{decimals}f}"


def metric_stats(
    endpoint: str,
    query_5m: str,
    start: int,
    end: int,
    step: int,
) -> dict[str, float | int | None]:
    points = range_values(endpoint, query_5m, start, end, step)
    values = [value for _, value in points]
    sustained = [
        (points[index][0], sum(value for _, value in points[index - 2 : index + 1]) / 3)
        for index in range(2, len(points))
        if points[index][0] - points[index - 2][0] == 2 * step
    ]
    max15_point = max(sustained, key=lambda point: point[1]) if sustained else None
    return {
        "samples": len(values),
        "p50": percentile(values, 0.50),
        "p95": percentile(values, 0.95),
        "p99": percentile(values, 0.99),
        "max15": max15_point[1] if max15_point else None,
        "max15_at": max15_point[0] if max15_point else None,
    }


def rate(metric: str, instance: str, window: str, multiplier: float = 60.0, labels: str = "") -> str:
    extra = f",{labels}" if labels else ""
    return f'rate({metric}{{instance="{instance}"{extra}}}[{window}])*{multiplier:g}'


def main() -> None:
    global REQUEST_TIMEOUT_SECONDS

    parser = argparse.ArgumentParser()
    parser.add_argument("instance")
    parser.add_argument("--endpoint", default=DEFAULT_ENDPOINT)
    parser.add_argument("--hours", type=int, default=24)
    parser.add_argument("--request-timeout", type=float, default=1.0)
    parser.add_argument("--output", type=pathlib.Path)
    args = parser.parse_args()
    REQUEST_TIMEOUT_SECONDS = args.request_timeout

    end = int(time.time())
    start = end - args.hours * 3600
    step = 300
    instance = args.instance

    rate_metrics = [
        ("PXC local commits", "mysql_global_status_wsrep_local_commits", "txn/min", ""),
        ("InnoDB RW commits", "mysql_info_schema_innodb_metrics_transaction_trx_rw_commits_total", "txn/min", ""),
        ("InnoDB RO commits", "mysql_info_schema_innodb_metrics_transaction_trx_ro_commits_total", "txn/min", ""),
        ("Rollbacks", "mysql_info_schema_innodb_metrics_transaction_trx_rollbacks_total", "txn/min", ""),
        ("Rows read", "mysql_global_status_innodb_row_ops_total", "rows/min", 'operation="read"'),
        ("Rows inserted", "mysql_global_status_innodb_row_ops_total", "rows/min", 'operation="inserted"'),
        ("Rows updated", "mysql_global_status_innodb_row_ops_total", "rows/min", 'operation="updated"'),
        ("Rows deleted", "mysql_global_status_innodb_row_ops_total", "rows/min", 'operation="deleted"'),
        ("Deadlocks", "mysql_info_schema_innodb_metrics_lock_lock_deadlocks_total", "events/min", ""),
        ("Row lock waits", "mysql_info_schema_innodb_metrics_lock_lock_row_lock_waits_total", "events/min", ""),
        ("PXC cert failures", "mysql_global_status_wsrep_local_cert_failures", "events/min", ""),
        ("PXC BF aborts", "mysql_global_status_wsrep_local_bf_aborts", "events/min", ""),
    ]

    results: list[tuple[str, str, dict[str, float | int | None]]] = []
    for label, metric, unit, labels in rate_metrics:
        results.append(
            (
                label,
                unit,
                metric_stats(
                    args.endpoint,
                    rate(metric, instance, "5m", labels=labels),
                    start,
                    end,
                    step,
                ),
            )
        )

    cpu_busy = metric_stats(
        args.endpoint,
        f'100*(1-avg(rate(node_cpu{{instance="{instance}",mode="idle"}}[5m])))',
        start,
        end,
        step,
    )
    cpu_iowait = metric_stats(
        args.endpoint,
        f'100*avg(rate(node_cpu{{instance="{instance}",mode="iowait"}}[5m]))',
        start,
        end,
        step,
    )
    memory_used = metric_stats(
        args.endpoint,
        f'100*(1-node_memory_MemAvailable{{instance="{instance}"}}/node_memory_MemTotal{{instance="{instance}"}})',
        start,
        end,
        step,
    )
    disk_read = metric_stats(
        args.endpoint,
        f'sum(rate(node_disk_bytes_read{{instance="{instance}"}}[5m]))/1024/1024',
        start,
        end,
        step,
    )
    disk_write = metric_stats(
        args.endpoint,
        f'sum(rate(node_disk_bytes_written{{instance="{instance}"}}[5m]))/1024/1024',
        start,
        end,
        step,
    )

    up_points = range_values(args.endpoint, f'mysql_up{{instance="{instance}"}}', start, end, step)
    up_values = [value for _, value in up_points]
    expected_samples = (end - start) // step + 1
    telemetry_coverage = min(100.0, 100 * len(up_values) / expected_samples)
    observed_availability = 100 * sum(up_values) / len(up_values) if up_values else None
    cpu_count = instant_value(args.endpoint, f'count(node_cpu{{instance="{instance}",mode="idle"}})')
    memory_bytes = instant_value(args.endpoint, f'node_memory_MemTotal{{instance="{instance}"}}')
    cluster_size = instant_value(args.endpoint, f'mysql_global_status_wsrep_cluster_size{{instance="{instance}"}}')
    wsrep_ready = instant_value(args.endpoint, f'mysql_global_status_wsrep_ready{{instance="{instance}"}}')
    wsrep_connected = instant_value(args.endpoint, f'mysql_global_status_wsrep_connected{{instance="{instance}"}}')
    read_only = instant_value(args.endpoint, f'mysql_global_variables_read_only{{instance="{instance}"}}')
    master_server_id = instant_value(args.endpoint, f'mysql_slave_status_master_server_id{{instance="{instance}"}}')
    is_pxc = cluster_size is not None
    if is_pxc:
        topology = "PXC/Galera member"
    elif master_server_id is not None:
        topology = "Async replica candidate"
    else:
        topology = "Async/standalone primary candidate"

    generated = dt.datetime.fromtimestamp(end, dt.timezone.utc).astimezone()
    period_start = dt.datetime.fromtimestamp(start, dt.timezone.utc).astimezone()
    period_end = dt.datetime.fromtimestamp(end, dt.timezone.utc).astimezone()

    lines = [
        f"# PMM instance capacity sample: {instance}",
        "",
        "## Scope",
        "",
        f"- Observation: {period_start:%Y-%m-%d %H:%M %z} to {period_end:%Y-%m-%d %H:%M %z} ({args.hours} hours)",
        "- Sampling and rate window: 5 minutes",
        "- Sustained peak: maximum rolling mean of three consecutive 5-minute samples",
        f"- Per-request HTTP timeout: {args.request_timeout:g} second(s)",
        f"- Generated: {generated:%Y-%m-%d %H:%M:%S %z}",
        "- This is an instance capacity report, not an audited TPC-C result.",
        "",
        "## Inventory and health",
        "",
        "| Item | Value |",
        "|---|---:|",
        f"| Inferred topology | {topology} |",
        f"| Telemetry coverage of requested period | {fmt(telemetry_coverage, 1)}% ({len(up_values):,}/{expected_samples:,}) |",
        f"| MySQL availability within observed samples | {fmt(observed_availability, 3)}% |",
        f"| Logical CPU | {fmt(cpu_count, 0)} |",
        f"| Memory | {fmt(memory_bytes / 1024**3 if memory_bytes is not None else None, 1)} GiB |",
        f"| Current PXC cluster size | {fmt(cluster_size, 0)} |",
        f"| Current wsrep ready | {fmt(wsrep_ready, 0)} |",
        f"| Current wsrep connected | {fmt(wsrep_connected, 0)} |",
        f"| Current read_only | {fmt(read_only, 0)} |",
        f"| Replication master_server_id | {fmt(master_server_id, 0)} |",
        "",
        "## Transaction and row demand",
        "",
        "| Metric | Unit | P50 | P95 | P99 | Max 15m avg | 5m samples |",
        "|---|---|---:|---:|---:|---:|---:|",
    ]
    for label, unit, stats in results:
        lines.append(
            f"| {label} | {unit} | {fmt(stats['p50'])} | {fmt(stats['p95'])} | "
            f"{fmt(stats['p99'])} | {fmt(stats['max15'])} | {stats['samples']:,} |"
        )

    lines.extend(
        [
            "",
            "## Resource demand",
            "",
            "| Metric | Unit | P50 | P95 | P99 | Max 15m avg |",
            "|---|---|---:|---:|---:|---:|",
            f"| CPU busy | % | {fmt(cpu_busy['p50'])} | {fmt(cpu_busy['p95'])} | {fmt(cpu_busy['p99'])} | {fmt(cpu_busy['max15'])} |",
            f"| CPU iowait | % | {fmt(cpu_iowait['p50'])} | {fmt(cpu_iowait['p95'])} | {fmt(cpu_iowait['p99'])} | {fmt(cpu_iowait['max15'])} |",
            f"| Memory used | % | {fmt(memory_used['p50'])} | {fmt(memory_used['p95'])} | {fmt(memory_used['p99'])} | {fmt(memory_used['max15'])} |",
            f"| Disk read | MiB/s | {fmt(disk_read['p50'])} | {fmt(disk_read['p95'])} | {fmt(disk_read['p99'])} | {fmt(disk_read['max15'])} |",
            f"| Disk write | MiB/s | {fmt(disk_write['p50'])} | {fmt(disk_write['p95'])} | {fmt(disk_write['p99'])} | {fmt(disk_write['max15'])} |",
            "",
            "## Interpretation",
            "",
            "- For PXC, `PXC local commits` represents logical writes originated on this node; time-align and sum it across cluster members.",
            "- For async replication, use `InnoDB RW commits` as logical write demand only on the confirmed writer. Replica RW commits are physical replay load.",
            "- `InnoDB RW commits` may include replicated writes. Never add it to `PXC local commits`.",
            "- `InnoDB RO commits` is reported separately; it is not folded into tpmC-equivalent.",
            "- Convert logical write demand to capacity-equivalent tpmC only after a controlled benchmark establishes `local commits per tpmC`.",
            "- Use P99 or maximum 15-minute average for design demand. Raw single-sample maximum is intentionally excluded.",
            "",
            "## Review gates before batch generation",
            "",
            "1. Confirm instance-to-cluster membership and which nodes accept application traffic.",
            "2. The 24-hour sample validates collection and report shape only; production sizing still needs representative peak periods.",
            "3. Confirm the disk-device filter. Current disk figures sum all exporter-visible block devices.",
            "4. Add PMM/QAN latency percentiles if this PMM deployment exposes them outside the Prometheus metric set.",
            "5. Keep `N/A` as missing telemetry; never convert missing series to zero.",
            "",
        ]
    )

    if WARNINGS:
        lines.extend(["## Collection warnings", ""])
        lines.extend(f"- {warning}" for warning in WARNINGS)
        lines.append("")

    output = args.output or pathlib.Path(f"{instance}.md")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
