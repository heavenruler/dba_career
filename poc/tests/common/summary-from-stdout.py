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
import hashlib
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
    r"(tidb|crdb|ybdb)-(.+?)-(rc|rr|strict)(?:-run\d+)?-(\d{8}T\d{6}\+\d{4})"
)

PHASE_MANIFESTS = {
    "S-K8S": "phase-k8s/manifest.yaml",
    "T-THRD": "phase-threadcontrol/manifest.yaml",
    "X-CROSS": "phase-crossregion/manifest.yaml",
}


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


def parse_manifest(path):
    values = {}
    if not path:
        return values
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.split("#", 1)[0].strip()
            if ":" not in line:
                continue
            key, value = line.split(":", 1)
            key = key.strip()
            value = value.strip().strip("'\"")
            if key in {"phase", "result_scope", "baseline_family"}:
                values[key] = value
    return values


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def repo_root_from_script():
    return Path(__file__).resolve().parents[2]


def collect_region_routing_evidence(suite_dir):
    """Collect near-read setup + placement gate artifacts from prepare/.

    Returns None for non-X-CROSS suites (no prepare/near-read* / no prepare/placement-gate-*).
    For X-CROSS (vm-6node-*) suites returns:
      {
        "near_read_setup": {
          "log_present": bool,
          "vars_snapshot": str | None,    # raw content of near-read-vars.txt
        },
        "placement_gate": {
          "verdict": str | None,
          "reason": str | None,
          "placement": str | None,        # P-A / P-B
          "idc_leader_count": int | None,
          "gcp_leader_count": int | None,
          "total_leader_samples": int | None,
          "json_path": str | None,
        }
      }
    """
    prep = suite_dir / "prepare"
    if not prep.is_dir():
        return None

    evidence = {}

    near_read_vars = prep / "near-read-vars.txt"
    near_read_log = prep / "near-read-setup.log"
    if near_read_vars.is_file() or near_read_log.is_file():
        snap = None
        if near_read_vars.is_file():
            with open(near_read_vars, encoding="utf-8", errors="replace") as f:
                snap = f.read().strip()
        evidence["near_read_setup"] = {
            "log_present": near_read_log.is_file(),
            "vars_snapshot": snap,
        }

    gate_jsons = sorted(prep.glob("placement-gate-*.json"))
    if gate_jsons:
        gate_json = gate_jsons[0]
        try:
            with open(gate_json, encoding="utf-8") as f:
                gate_data = json.load(f)
            evidence["placement_gate"] = {
                "verdict": gate_data.get("verdict"),
                "reason": gate_data.get("reason"),
                "placement": gate_data.get("placement"),
                "idc_leader_count": gate_data.get("idc_leader_count"),
                "gcp_leader_count": gate_data.get("gcp_leader_count"),
                "total_leader_samples": gate_data.get("total_leader_samples"),
                "json_path": str(gate_json.relative_to(suite_dir)),
            }
        except (json.JSONDecodeError, OSError) as e:
            evidence["placement_gate"] = {"error": f"failed to parse {gate_json.name}: {e}"}

    return evidence if evidence else None


def infer_scope_and_manifest(suite_dir):
    parts = set(suite_dir.resolve().parts)
    repo_root = repo_root_from_script()

    if "S-BASE" in parts:
        return {"result_scope": "S-BASE", "baseline_family": "vm"}, None

    for scope, manifest_rel in PHASE_MANIFESTS.items():
        if scope in parts or (scope == "X-CROSS" and "x-cross" in parts):
            return {}, repo_root / manifest_rel

    return {}, None


def main():
    args = sys.argv[1:]
    warehouses = 128
    skip_rounds = 0
    phase = None
    result_scope = None
    baseline_family = None
    manifest = None
    manifest_sha256 = None
    positional = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--warehouses":
            warehouses = int(args[i + 1])
            i += 2
        elif a == "--skip-rounds":
            skip_rounds = int(args[i + 1])
            i += 2
        elif a == "--phase":
            phase = args[i + 1]
            i += 2
        elif a == "--result-scope":
            result_scope = args[i + 1]
            i += 2
        elif a == "--baseline-family":
            baseline_family = args[i + 1]
            i += 2
        elif a == "--manifest":
            manifest = Path(args[i + 1])
            i += 2
        elif a == "--manifest-sha256":
            manifest_sha256 = args[i + 1]
            i += 2
        else:
            positional.append(a)
            i += 1

    if not positional:
        print(
            "usage: "
            f"{sys.argv[0]} [--warehouses N] [--skip-rounds K] "
            "[--phase NAME] [--result-scope SCOPE] [--baseline-family FAMILY] "
            "[--manifest PATH] [--manifest-sha256 SHA256] <suite_artifact_dir>",
            file=sys.stderr,
        )
        sys.exit(1)

    suite_dir = Path(positional[0])
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

    inferred, inferred_manifest = infer_scope_and_manifest(suite_dir)
    if manifest is None:
        manifest = inferred_manifest

    manifest_values = {}
    if manifest is not None:
        if not manifest.is_absolute():
            manifest = repo_root_from_script() / manifest
        if manifest.is_file():
            manifest_values = parse_manifest(manifest)
            if manifest_sha256 is None:
                manifest_sha256 = sha256_file(manifest)
        else:
            print(f"error: manifest not found: {manifest}", file=sys.stderr)
            sys.exit(1)

    phase = phase if phase is not None else manifest_values.get("phase")
    result_scope = (
        result_scope
        if result_scope is not None
        else manifest_values.get("result_scope", inferred.get("result_scope"))
    )
    baseline_family = (
        baseline_family
        if baseline_family is not None
        else manifest_values.get("baseline_family", inferred.get("baseline_family"))
    )

    if result_scope == "S-BASE":
        phase = None
        manifest_sha256 = None

    threads = sorted(int(d.name.split("-")[1]) for d in runs_dir.glob("threads-*"))
    summary = {
        "schema_version": 1,
        "phase": phase,
        "result_scope": result_scope,
        "baseline_family": baseline_family,
        "manifest_sha256": manifest_sha256,
        "db": db,
        "topology": topology,
        "iso": iso,
        "ts": ts,
        "warehouses": warehouses,
        "rounds_per_thread_group": 5,
        "skip_rounds": skip_rounds,
        "threads_list": threads,
        "thread_results": {},
        "generated_at": datetime.now().astimezone().isoformat(),
        "generated_by": "tests/common/summary-from-stdout.py v1",
        "source_files": "runs/threads-*/round-*/go-tpc-stdout.txt",
        "region_routing_evidence": collect_region_routing_evidence(suite_dir),
    }

    for t in threads:
        rounds = sorted(
            (runs_dir / f"threads-{t}").glob("round-*/go-tpc-stdout.txt")
        )
        if skip_rounds:
            rounds = rounds[skip_rounds:]
        round_results = [parse_round(r) for r in rounds]
        summary["thread_results"][str(t)] = aggregate_thread_group(round_results)

    out_path = suite_dir / "summary.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
