#!/usr/bin/env python3
"""Generate a repository commit-frequency heatmap from Git history."""

from __future__ import annotations

import argparse
import math
import subprocess
import sys
import xml.etree.ElementTree as ET
from collections import Counter
from datetime import date, datetime, timedelta, timezone
from pathlib import Path


SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)

MONTHS = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
WEEKDAY_LABELS = {1: "Mon", 3: "Wed", 5: "Fri"}
COLORS = ("#ebedf0", "#9be9a8", "#40c463", "#30a14e", "#216e39")
BOT_AUTHOR = "github-actions[bot]"
AUTOMATION_MESSAGE = "chore: update commit heatmap"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a GitHub-style SVG heatmap from reachable Git commits."
    )
    parser.add_argument("--branch", default="master", help="Branch or revision to inspect")
    parser.add_argument("--days", type=int, default=365, help="Number of inclusive calendar days")
    parser.add_argument("--output", type=Path, required=True, help="Destination SVG path")
    parser.add_argument(
        "--end-date",
        type=date.fromisoformat,
        help="Inclusive UTC end date in YYYY-MM-DD form (default: current UTC date)",
    )
    args = parser.parse_args()
    if args.days <= 0:
        parser.error("--days must be greater than zero")
    return args


def git_log(branch: str) -> bytes:
    command = [
        "git",
        "log",
        "--no-decorate",
        "--pretty=format:%H%x00%aI%x00%an%x00%ae%x00%B%x00",
        branch,
    ]
    try:
        return subprocess.run(command, check=True, stdout=subprocess.PIPE).stdout
    except FileNotFoundError as exc:
        raise RuntimeError("git executable was not found") from exc
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(f"git log failed for revision {branch!r}") from exc


def commit_counts(branch: str, start: date, end: date) -> Counter[date]:
    fields = git_log(branch).split(b"\0")
    if fields and fields[-1] == b"":
        fields.pop()
    if len(fields) % 5 != 0:
        raise RuntimeError("unexpected git log record format")

    counts: Counter[date] = Counter()
    seen_shas: set[str] = set()
    for offset in range(0, len(fields), 5):
        sha_raw, authored_raw, author_raw, email_raw, message_raw = fields[offset : offset + 5]
        sha = sha_raw.decode("ascii").strip()
        if not sha or sha in seen_shas:
            continue
        seen_shas.add(sha)

        author = author_raw.decode("utf-8", errors="replace").strip().casefold()
        email = email_raw.decode("utf-8", errors="replace").strip().casefold()
        message = message_raw.decode("utf-8", errors="replace").casefold()
        if author == BOT_AUTHOR or BOT_AUTHOR in email:
            continue
        if AUTOMATION_MESSAGE in message:
            continue

        authored_at = datetime.fromisoformat(authored_raw.decode("ascii").strip())
        authored_date = authored_at.astimezone(timezone.utc).date()
        if start <= authored_date <= end:
            counts[authored_date] += 1
    return counts


def level_thresholds(counts: Counter[date]) -> tuple[int, int, int]:
    positive = sorted(value for value in counts.values() if value > 0)
    if not positive:
        return (1, 1, 1)

    def percentile(fraction: float) -> int:
        index = math.ceil(fraction * len(positive)) - 1
        return positive[max(0, min(index, len(positive) - 1))]

    return percentile(0.25), percentile(0.50), percentile(0.75)


def contribution_level(value: int, thresholds: tuple[int, int, int]) -> int:
    if value <= 0:
        return 0
    if value <= thresholds[0]:
        return 1
    if value <= thresholds[1]:
        return 2
    if value <= thresholds[2]:
        return 3
    return 4


def sunday_on_or_before(day: date) -> date:
    return day - timedelta(days=(day.weekday() + 1) % 7)


def svg_element(tag: str, attributes: dict[str, str] | None = None) -> ET.Element:
    return ET.Element(f"{{{SVG_NS}}}{tag}", attributes or {})


def add_text(parent: ET.Element, x: int, y: int, text: str, css_class: str) -> None:
    element = ET.SubElement(
        parent,
        f"{{{SVG_NS}}}text",
        {"x": str(x), "y": str(y), "class": css_class},
    )
    element.text = text


def build_svg(counts: Counter[date], start: date, end: date, branch: str) -> ET.Element:
    grid_start = sunday_on_or_before(start)
    grid_end = end + timedelta(days=(5 - end.weekday()) % 7)
    weeks = ((grid_end - grid_start).days // 7) + 1

    cell = 11
    gap = 3
    pitch = cell + gap
    grid_x = 48
    grid_y = 67
    width = grid_x + weeks * pitch + 18
    height = grid_y + 7 * pitch + 42
    thresholds = level_thresholds(counts)

    root = svg_element(
        "svg",
        {
            "viewBox": f"0 0 {width} {height}",
            "width": "100%",
            "role": "img",
            "aria-labelledby": "heatmap-title heatmap-description",
            "preserveAspectRatio": "xMinYMin meet",
        },
    )
    title = ET.SubElement(root, f"{{{SVG_NS}}}title", {"id": "heatmap-title"})
    title.text = f"Repository commit frequency for {branch}"
    description = ET.SubElement(root, f"{{{SVG_NS}}}desc", {"id": "heatmap-description"})
    description.text = f"Daily author-date commit counts from {start.isoformat()} through {end.isoformat()} UTC."

    style = ET.SubElement(root, f"{{{SVG_NS}}}style")
    style.text = """
      .heading { fill: #24292f; font: 600 14px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
      .label { fill: #57606a; font: 10px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
      .summary { fill: #57606a; font: 11px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
      .day { shape-rendering: geometricPrecision; stroke: rgba(27, 31, 36, 0.06); stroke-width: 1px; }
      @media (prefers-color-scheme: dark) {
        .heading { fill: #e6edf3; }
        .label, .summary { fill: #8b949e; }
        .day { stroke: rgba(240, 246, 252, 0.08); }
        .level-0 { fill: #161b22 !important; }
      }
    """

    add_text(root, 0, 16, "Repository Commit Frequency", "heading")
    add_text(root, 0, 35, f"{sum(counts.values())} commits on {branch} by UTC author date", "summary")

    for row, label in WEEKDAY_LABELS.items():
        add_text(root, 0, grid_y + row * pitch + 9, label, "label")

    last_month: tuple[int, int] | None = None
    for week in range(weeks):
        week_start = grid_start + timedelta(days=week * 7)
        for day_offset in range(7):
            current = week_start + timedelta(days=day_offset)
            if current < start or current > end:
                continue

            month_key = (current.year, current.month)
            if (current == start or current.day == 1) and month_key != last_month:
                add_text(root, grid_x + week * pitch, grid_y - 9, MONTHS[current.month - 1], "label")
                last_month = month_key

            value = counts.get(current, 0)
            level = contribution_level(value, thresholds)
            rect = ET.SubElement(
                root,
                f"{{{SVG_NS}}}rect",
                {
                    "x": str(grid_x + week * pitch),
                    "y": str(grid_y + day_offset * pitch),
                    "width": str(cell),
                    "height": str(cell),
                    "rx": "2",
                    "class": f"day level-{level}",
                    "fill": COLORS[level],
                    "data-date": current.isoformat(),
                    "data-count": str(value),
                },
            )
            tooltip = ET.SubElement(rect, f"{{{SVG_NS}}}title")
            tooltip.text = f"{current.isoformat()}: {value} commit{'s' if value != 1 else ''}"

    footer_y = grid_y + 7 * pitch + 18
    add_text(root, 0, footer_y, f"{start.isoformat()} to {end.isoformat()} UTC", "summary")
    legend_x = max(grid_x + weeks * pitch - 112, 250)
    add_text(root, legend_x, footer_y, "Less", "label")
    for level, color in enumerate(COLORS):
        ET.SubElement(
            root,
            f"{{{SVG_NS}}}rect",
            {
                "x": str(legend_x + 28 + level * pitch),
                "y": str(footer_y - 9),
                "width": str(cell),
                "height": str(cell),
                "rx": "2",
                "class": f"day level-{level}",
                "fill": color,
            },
        )
    add_text(root, legend_x + 28 + len(COLORS) * pitch + 2, footer_y, "More", "label")
    return root


def write_svg(root: ET.Element, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(root, space="  ")
    tree = ET.ElementTree(root)
    tree.write(output, encoding="utf-8", xml_declaration=True, short_empty_elements=True)
    with output.open("ab") as stream:
        stream.write(b"\n")


def main() -> int:
    args = parse_args()
    end = args.end_date or datetime.now(timezone.utc).date()
    start = end - timedelta(days=args.days - 1)
    try:
        counts = commit_counts(args.branch, start, end)
        write_svg(build_svg(counts, start, end, args.branch), args.output)
    except (RuntimeError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(
        f"Generated {args.output} with {sum(counts.values())} commits "
        f"from {start.isoformat()} through {end.isoformat()} UTC."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
