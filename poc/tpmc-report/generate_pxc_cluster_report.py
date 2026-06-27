#!/usr/bin/env python3
"""Generate a logical-demand and per-node capacity report for one PXC cluster."""

from __future__ import annotations

import argparse
import datetime as dt
import pathlib
import re
import time

import generate_instance_report as common


def selector(members: list[str]) -> str:
    # PromQL string literals reject Python's unnecessary `\-` regex escape.
    return "|".join(re.escape(member).replace(r"\-", "-") for member in members)


def range_series(
    endpoint: str,
    query: str,
    start: int,
    end: int,
    step: int,
) -> dict[str, dict[int, float]]:
    try:
        data = common.prometheus_get(
            endpoint,
            "/api/v1/query_range",
            {"query": query, "start": str(start), "end": str(end), "step": str(step)},
        )
    except Exception as error:  # The report must survive individual 1-second request failures.
        common.WARNINGS.append(f"Range query unavailable ({type(error).__name__}): `{query}`")
        return {}

    result: dict[str, dict[int, float]] = {}
    for series in data.get("result", []):
        instance = series.get("metric", {}).get("instance")
        if not instance:
            continue
        result[instance] = {
            int(timestamp): float(value)
            for timestamp, value in series.get("values", [])
            if value not in ("NaN", "+Inf", "-Inf")
        }
    return result


def query_rate(metric: str, member_regex: str, labels: str = "", multiplier: float = 60.0) -> str:
    extra = f",{labels}" if labels else ""
    return f'rate({metric}{{instance=~"{member_regex}"{extra}}}[5m])*{multiplier:g}'


def aligned_points(
    series: dict[str, dict[int, float]], members: list[str], operation: str = "sum"
) -> list[tuple[int, float]]:
    if any(member not in series for member in members):
        return []
    timestamps = set(series[members[0]])
    for member in members[1:]:
        timestamps &= set(series[member])
    points = []
    for timestamp in sorted(timestamps):
        values = [series[member][timestamp] for member in members]
        value = sum(values) if operation == "sum" else min(values)
        points.append((timestamp, value))
    return points


def stats(points: list[tuple[int, float]], step: int) -> dict[str, float | int | None]:
    values = [value for _, value in points]
    rolling = [
        (points[index][0], sum(value for _, value in points[index - 2 : index + 1]) / 3)
        for index in range(2, len(points))
        if points[index][0] - points[index - 2][0] == 2 * step
    ]
    peak = max(rolling, key=lambda item: item[1]) if rolling else None
    return {
        "samples": len(values),
        "p50": common.percentile(values, 0.50),
        "p95": common.percentile(values, 0.95),
        "p99": common.percentile(values, 0.99),
        "max15": peak[1] if peak else None,
        "max15_at": peak[0] if peak else None,
    }


def member_stats(series: dict[str, dict[int, float]], member: str, step: int) -> dict[str, float | int | None]:
    return stats(sorted(series.get(member, {}).items()), step)


def current_values(endpoint: str, metric: str, members: list[str]) -> dict[str, float | None]:
    return {member: common.instant_value(endpoint, f'{metric}{{instance="{member}"}}') for member in members}


def format_peak(timestamp: float | int | None) -> str:
    if timestamp is None:
        return "N/A"
    return dt.datetime.fromtimestamp(timestamp, dt.timezone.utc).astimezone().strftime("%m-%d %H:%M")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("cluster", help="Cluster prefix, for example p-pxc-n")
    parser.add_argument("--members", nargs="+", help="Explicit member instance names")
    parser.add_argument("--endpoint", default=common.DEFAULT_ENDPOINT)
    parser.add_argument("--hours", type=int, default=24)
    parser.add_argument("--request-timeout", type=float, default=1.0)
    parser.add_argument("--output", type=pathlib.Path)
    args = parser.parse_args()

    common.REQUEST_TIMEOUT_SECONDS = args.request_timeout
    common.WARNINGS.clear()
    members = args.members or [f"{args.cluster}-{index}" for index in range(1, 4)]
    member_regex = selector(members)
    end = int(time.time())
    start = end - args.hours * 3600
    step = 300
    expected_samples = (end - start) // step + 1

    local_commits = range_series(
        args.endpoint,
        query_rate("mysql_global_status_wsrep_local_commits", member_regex),
        start,
        end,
        step,
    )
    rw_commits = range_series(
        args.endpoint,
        query_rate("mysql_info_schema_innodb_metrics_transaction_trx_rw_commits_total", member_regex),
        start,
        end,
        step,
    )
    ro_commits = range_series(
        args.endpoint,
        query_rate("mysql_info_schema_innodb_metrics_transaction_trx_ro_commits_total", member_regex),
        start,
        end,
        step,
    )
    rollbacks = range_series(
        args.endpoint,
        query_rate("mysql_info_schema_innodb_metrics_transaction_trx_rollbacks_total", member_regex),
        start,
        end,
        step,
    )
    row_reads = range_series(
        args.endpoint,
        query_rate("mysql_global_status_innodb_row_ops_total", member_regex, 'operation="read"'),
        start,
        end,
        step,
    )

    cpu_busy = range_series(
        args.endpoint,
        f'100*(1-avg by(instance)(rate(node_cpu{{instance=~"{member_regex}",mode="idle"}}[5m])))',
        start,
        end,
        step,
    )
    memory_used = range_series(
        args.endpoint,
        f'100*(1-node_memory_MemAvailable{{instance=~"{member_regex}"}}/node_memory_MemTotal{{instance=~"{member_regex}"}})',
        start,
        end,
        step,
    )
    disk_write = range_series(
        args.endpoint,
        f'sum by(instance)(rate(node_disk_bytes_written{{instance=~"{member_regex}"}}[5m]))/1024/1024',
        start,
        end,
        step,
    )

    cluster_metrics = [
        ("Logical writes originated", "txn/min", stats(aligned_points(local_commits, members), step)),
        ("Read-only transactions", "txn/min", stats(aligned_points(ro_commits, members), step)),
        ("Rollbacks", "txn/min", stats(aligned_points(rollbacks, members), step)),
        ("Physical RW commits across nodes", "txn/min", stats(aligned_points(rw_commits, members), step)),
        ("Physical rows read across nodes", "rows/min", stats(aligned_points(row_reads, members), step)),
    ]

    local_points = dict(aligned_points(local_commits, members))
    physical_points = dict(aligned_points(rw_commits, members))
    shared = sorted(set(local_points) & set(physical_points))
    amplification_points = [
        (timestamp, physical_points[timestamp] / local_points[timestamp])
        for timestamp in shared
        if local_points[timestamp] > 0
    ]
    amplification = stats(amplification_points, step)
    origin_totals = {
        member: sum(local_commits.get(member, {}).values()) for member in members
    }
    all_originated = sum(origin_totals.values())
    origin_leader = max(origin_totals, key=origin_totals.get)
    origin_leader_share = (
        100 * origin_totals[origin_leader] / all_originated if all_originated else None
    )

    health_metrics = {
        "mysql_up": range_series(
            args.endpoint, f'mysql_up{{instance=~"{member_regex}"}}', start, end, step
        ),
        "ready": range_series(
            args.endpoint, f'mysql_global_status_wsrep_ready{{instance=~"{member_regex}"}}', start, end, step
        ),
        "connected": range_series(
            args.endpoint, f'mysql_global_status_wsrep_connected{{instance=~"{member_regex}"}}', start, end, step
        ),
        "state": range_series(
            args.endpoint, f'mysql_global_status_wsrep_local_state{{instance=~"{member_regex}"}}', start, end, step
        ),
    }
    health_timestamps: set[int] | None = None
    for metric_series in health_metrics.values():
        for member in members:
            timestamps = set(metric_series.get(member, {}))
            health_timestamps = timestamps if health_timestamps is None else health_timestamps & timestamps
    health_timestamps = health_timestamps or set()
    healthy_counts = []
    for timestamp in sorted(health_timestamps):
        healthy = sum(
            health_metrics["mysql_up"][member][timestamp] == 1
            and health_metrics["ready"][member][timestamp] == 1
            and health_metrics["connected"][member][timestamp] == 1
            and health_metrics["state"][member][timestamp] == 4
            for member in members
        )
        healthy_counts.append(healthy)
    quorum_availability = (
        100 * sum(count >= len(members) // 2 + 1 for count in healthy_counts) / len(healthy_counts)
        if healthy_counts
        else None
    )
    all_nodes_healthy = (
        100 * sum(count == len(members) for count in healthy_counts) / len(healthy_counts)
        if healthy_counts
        else None
    )

    current = {
        "up": current_values(args.endpoint, "mysql_up", members),
        "ready": current_values(args.endpoint, "mysql_global_status_wsrep_ready", members),
        "connected": current_values(args.endpoint, "mysql_global_status_wsrep_connected", members),
        "state": current_values(args.endpoint, "mysql_global_status_wsrep_local_state", members),
        "cluster_size": current_values(args.endpoint, "mysql_global_status_wsrep_cluster_size", members),
    }

    period_start = dt.datetime.fromtimestamp(start, dt.timezone.utc).astimezone()
    period_end = dt.datetime.fromtimestamp(end, dt.timezone.utc).astimezone()
    logical_stats = cluster_metrics[0][2]
    design_demand = max(
        value for value in (logical_stats["p99"], logical_stats["max15"]) if value is not None
    ) if logical_stats["p99"] is not None or logical_stats["max15"] is not None else None

    lines = [
        f"# PMM PXC cluster capacity sample: {args.cluster}",
        "",
        "## Scope",
        "",
        f"- Members: {', '.join(members)}",
        f"- Observation: {period_start:%Y-%m-%d %H:%M %z} to {period_end:%Y-%m-%d %H:%M %z} ({args.hours} hours)",
        "- Sampling/rate window: 5 minutes; sustained peak is a rolling three-sample mean.",
        f"- Per-request HTTP timeout: {args.request_timeout:g} second(s)",
        "- Cluster totals use only timestamps present for every member.",
        "- This is a capacity-equivalence input, not an audited TPC-C result.",
        "",
        "## Calculation rules",
        "",
        "For metric `m`, member `i`, and aligned timestamp `t`:",
        "",
        "1. Per-member rate: `x_i(t) = rate(m_i[5m]) * 60`.",
        "2. Cluster series: `X(t) = x_1(t) + x_2(t) + x_3(t)`; use only timestamps present for all three members.",
        "3. P50/P95/P99: calculate percentiles over `X(t)`, not by adding member percentiles.",
        "4. Max 15m avg: maximum rolling mean of three consecutive `X(t)` samples.",
        "5. Physical/logical ratio: `sum(RW commits_i(t)) / sum(local commits_i(t))`, calculated per timestamp before percentiles.",
        "",
        "| Report row | Source metric | Aggregation | Meaning |",
        "|---|---|---|---|",
        "| Logical writes originated | `mysql_global_status_wsrep_local_commits` | Sum 3 members | Logical write transactions originating in the cluster |",
        "| Read-only transactions | `...trx_ro_commits_total` | Sum 3 members | Read workload, kept separate from tpmC-equivalent |",
        "| Rollbacks | `...trx_rollbacks_total` | Sum 3 members | Cluster rollback activity |",
        "| Physical RW commits across nodes | `...trx_rw_commits_total` | Sum 3 members | Physical work including replicated commits |",
        "| Physical rows read across nodes | `mysql_global_status_innodb_row_ops_total{operation=\"read\"}` | Sum 3 members | Physical row-read work handled by all nodes |",
        "| Observed physical/logical commit-work | RW total / local total | Per timestamp | Diagnostic ratio; not PXC replication factor |",
        "",
        "## Logical and physical demand",
        "",
        "| Metric | Unit | P50 | P95 | P99 | Max 15m avg | Peak end | Aligned samples |",
        "|---|---|---:|---:|---:|---:|---|---:|",
    ]
    for label, unit, metric in cluster_metrics:
        lines.append(
            f"| {label} | {unit} | {common.fmt(metric['p50'])} | {common.fmt(metric['p95'])} | "
            f"{common.fmt(metric['p99'])} | {common.fmt(metric['max15'])} | "
            f"{format_peak(metric['max15_at'])} | {metric['samples']:,} |"
        )
    lines.extend(
        [
            f"| Observed physical/logical commit-work | ratio | {common.fmt(amplification['p50'], 2)} | "
            f"{common.fmt(amplification['p95'], 2)} | {common.fmt(amplification['p99'], 2)} | "
            f"{common.fmt(amplification['max15'], 2)} | {format_peak(amplification['max15_at'])} | "
            f"{amplification['samples']:,} |",
            "",
            f"- 24-hour logical-write design candidate: **{common.fmt(design_demand)} txn/min** (`max(P99, max 15m avg)`).",
            f"- Write origin concentration: **{origin_leader} = {common.fmt(origin_leader_share, 2)}%** of observed local commits.",
            "- Capacity-equivalent tpmC remains N/A until benchmark calibration supplies `logical local commits per tpmC`.",
            "",
            "## HA health",
            "",
            "| Metric | Value |",
            "|---|---:|",
            f"| Health telemetry coverage | {common.fmt(100 * len(healthy_counts) / expected_samples, 1)}% ({len(healthy_counts):,}/{expected_samples:,}) |",
            f"| Quorum available (at least 2 healthy nodes) | {common.fmt(quorum_availability, 3)}% |",
            f"| All 3 nodes healthy | {common.fmt(all_nodes_healthy, 3)}% |",
            "",
            "A healthy member requires `mysql_up=1`, `wsrep_ready=1`, `wsrep_connected=1`, and `wsrep_local_state=4` (Synced). This is database health, not application/proxy availability.",
            "",
            "### Current member state",
            "",
            "| Member | up | ready | connected | local state | cluster size |",
            "|---|---:|---:|---:|---:|---:|",
        ]
    )
    for member in members:
        lines.append(
            f"| {member} | {common.fmt(current['up'][member], 0)} | "
            f"{common.fmt(current['ready'][member], 0)} | {common.fmt(current['connected'][member], 0)} | "
            f"{common.fmt(current['state'][member], 0)} | {common.fmt(current['cluster_size'][member], 0)} |"
        )

    lines.extend(
        [
            "",
            "## Member capacity comparison",
            "",
            "| Member | Local commit P99 | Physical RW P99 | RO P99 | CPU P99 | Memory P99 | Disk write P99 |",
            "|---|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for member in members:
        local = member_stats(local_commits, member, step)
        rw = member_stats(rw_commits, member, step)
        ro = member_stats(ro_commits, member, step)
        cpu = member_stats(cpu_busy, member, step)
        memory = member_stats(memory_used, member, step)
        disk = member_stats(disk_write, member, step)
        lines.append(
            f"| {member} | {common.fmt(local['p99'])} txn/min | {common.fmt(rw['p99'])} txn/min | "
            f"{common.fmt(ro['p99'])} txn/min | {common.fmt(cpu['p99'])}% | "
            f"{common.fmt(memory['p99'])}% | {common.fmt(disk['p99'])} MiB/s |"
        )

    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "- Logical write demand is the time-aligned sum of `wsrep_local_commits` across all members.",
            "- Physical RW commits and row operations include replicated work and must not be used directly as cluster tpmC.",
            "- The physical/logical commit-work ratio is diagnostic only; it is not the PXC replication factor.",
            "- Read-only transactions remain separate from write tpmC-equivalent.",
            "- N-1 sizing must verify that either surviving member can absorb the cluster logical demand; summed CPU percentages are not capacity.",
            "- The 24-hour range validates collection and report shape. Final sizing requires representative business peaks and benchmark calibration.",
            "",
        ]
    )
    if common.WARNINGS:
        lines.extend(["## Collection warnings", ""])
        lines.extend(f"- {warning}" for warning in common.WARNINGS)
        lines.append("")

    output = args.output or pathlib.Path(f"{args.cluster}.md")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
