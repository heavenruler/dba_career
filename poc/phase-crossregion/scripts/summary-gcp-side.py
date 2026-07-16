#!/usr/bin/env python3
"""Inject GCP-side go-tpc results into an existing suite summary.json.

雙端（IDC + GCP client）數據彙整規則（decisions-2026-06-08.md，2026-07-15 拍板 G1-G6）：
  * G1 永不合併：IDC 既有欄位零變動；GCP 端自成 summary.json 頂層 `gcp_side` 區塊。
  * G2 GCP RO 端吞吐主欄 = `read_tpmTotal`（A-A-RO 的 GCP mix 無 NEW_ORDER，tpmC
    依定義恆 0 → 指標無定義，非量到零）；欄名明標非 tpmC，不可與 IDC tpmC 比大小。
    A-A（雙端同 standard mix）gcp 端才是真 tpmC → `tpmC_mean` 有值；RO 時為 null。
  * G3 輸入 = 同 suite 目錄 `runs/threads-*/round-*/go-tpc-stdout-gcp.txt`
    （由 merge-gcp-stdout.sh 落位，與 IDC 端 go-tpc-stdout.txt 並排）。

Usage:
  summary-gcp-side.py [--profile A-A-RO|A-A] <suite_artifact_dir>

  --profile 省略時由目錄名的 Q17 token 推斷（-aaro- → A-A-RO；-aa- → A-A）。

零依賴（stdlib only）；冪等（重跑覆寫 gcp_side，IDC 既有鍵一律不動）。
無 NEW_ORDER 行的輸入（A-A-RO 唯讀 mix）不報錯。
"""
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from statistics import mean

TXN_TYPES = ("NEW_ORDER", "PAYMENT", "DELIVERY", "ORDER_STATUS", "STOCK_LEVEL")

# go-tpc [Summary] 交易型別行（含 TPM；tests/common/summary-from-stdout.py 同源格式）
SUMMARY_RE = re.compile(
    r"\[Summary\]\s+(\S+)\s+-\s+Takes\(s\):\s+([\d.]+),\s+Count:\s+(\d+),"
    r"\s+TPM:\s+([\d.]+),\s+Sum\(ms\):\s+\S+,\s+Avg\(ms\):\s+\S+,"
    r"\s+50th\(ms\):\s+([\d.]+),\s+90th\(ms\):\s+\S+,"
    r"\s+95th\(ms\):\s+([\d.]+),\s+99th\(ms\):\s+([\d.]+)"
)
TPMC_RE = re.compile(r"tpmC:\s*([\d.]+),\s*tpmTotal:\s*([\d.]+)")
# Q17 token 藏 topology 段：{db}-vm-6node-{P}-{aa|aaro}-{iso}-{ts}
PROFILE_TOKEN_RE = re.compile(r"-(aaro|aa)-(rc|rr|strict)-")


def parse_round(stdout_path):
    """單輪 go-tpc stdout → {tpmC, tpmTotal, txns{name: {...}}, errs{name: count}}.

    無 NEW_ORDER 行（A-A-RO 唯讀 mix）為合法輸入：txns 只收實際出現的型別。
    """
    txns = {}
    errs = {}
    tpmC = tpmTotal = None

    with open(stdout_path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if line.startswith("[Summary]"):
                m = SUMMARY_RE.match(line)
                if not m:
                    continue
                name = m.group(1)
                count = int(m.group(3))
                tpm, p50, p95, p99 = (float(m.group(i)) for i in (4, 5, 6, 7))
                if name in TXN_TYPES:
                    txns[name] = {
                        "count": count, "tpm": tpm,
                        "p50": p50, "p95": p95, "p99": p99,
                    }
                elif name.endswith("_ERR"):
                    base = name[: -len("_ERR")]
                    if base in TXN_TYPES:
                        errs[base] = errs.get(base, 0) + count
            elif line.startswith("tpmC:"):
                m = TPMC_RE.match(line)
                if m:
                    tpmC = float(m.group(1))
                    tpmTotal = float(m.group(2))

    # RO mix 理論上 go-tpc 仍印 tpmC/tpmTotal 行；缺行時 fallback 用逐型別 TPM 加總
    if tpmTotal is None and txns:
        tpmTotal = round(sum(t["tpm"] for t in txns.values()), 1)

    return {"tpmC": tpmC, "tpmTotal": tpmTotal, "txns": txns, "errs": errs}


def mean_or_none(seq):
    seq = [x for x in seq if x is not None]
    return round(mean(seq), 1) if seq else None


def aggregate_thread_group(round_results, profile):
    tpmTotals = [r["tpmTotal"] for r in round_results if r["tpmTotal"] is not None]
    out = {
        # G2: RO 情境吞吐主欄；A-A 情境亦保留（雙端同量綱時仍是 read+write 總 TPM）
        "read_tpmTotal_mean": mean_or_none(tpmTotals),
        "tpmTotal_per_round": [round(t, 1) for t in tpmTotals],
        # G2/G5: A-A 才有真 tpmC（gcp 列照標 tpmC，可與 idc 列並讀對照）；RO 時 null
        "tpmC_mean": (
            mean_or_none([r["tpmC"] for r in round_results])
            if profile == "A-A" else None
        ),
    }

    seen_txns = sorted(
        {t for r in round_results for t in r["txns"]},
        key=TXN_TYPES.index,
    )
    for t in seen_txns:
        rounds_with = [r for r in round_results if t in r["txns"]]
        out[t] = {
            "TPM_mean": mean_or_none([r["txns"][t]["tpm"] for r in rounds_with]),
            "p50_mean_ms": mean_or_none([r["txns"][t]["p50"] for r in rounds_with]),
            "p95_mean_ms": mean_or_none([r["txns"][t]["p95"] for r in rounds_with]),
            "p99_mean_ms": mean_or_none([r["txns"][t]["p99"] for r in rounds_with]),
            "total_count": sum(r["txns"][t]["count"] for r in rounds_with),
            "error_count": sum(r["errs"].get(t, 0) for r in round_results),
        }
    return out


def infer_profile(suite_name):
    m = PROFILE_TOKEN_RE.search(suite_name)
    if not m:
        return None
    return {"aaro": "A-A-RO", "aa": "A-A"}[m.group(1)]


def main():
    args = sys.argv[1:]
    profile = None
    positional = []
    i = 0
    while i < len(args):
        if args[i] == "--profile":
            profile = args[i + 1]
            i += 2
        else:
            positional.append(args[i])
            i += 1

    if len(positional) != 1:
        print(f"usage: {sys.argv[0]} [--profile A-A-RO|A-A] <suite_artifact_dir>",
              file=sys.stderr)
        sys.exit(1)

    suite_dir = Path(positional[0])
    if not suite_dir.is_dir():
        print(f"error: {suite_dir} not a directory", file=sys.stderr)
        sys.exit(1)

    if profile is None:
        profile = infer_profile(suite_dir.name)
    if profile not in ("A-A-RO", "A-A"):
        print(
            f"error: profile 無法判定（--profile 未給且目錄名 {suite_dir.name} "
            "無 Q17 token -aa/-aaro）；gcp_side 只適用 A-A / A-A-RO",
            file=sys.stderr,
        )
        sys.exit(1)

    summary_path = suite_dir / "summary.json"
    if not summary_path.is_file():
        print(
            f"error: {summary_path} 不存在 — 先跑 tests/common/summary-from-stdout.py "
            "產 IDC 主表，再注入 gcp_side",
            file=sys.stderr,
        )
        sys.exit(1)

    runs_dir = suite_dir / "runs"
    gcp_files = sorted(runs_dir.glob("threads-*/round-*/go-tpc-stdout-gcp.txt"))
    if not gcp_files:
        print(
            f"error: {runs_dir}/threads-*/round-*/go-tpc-stdout-gcp.txt 一個都沒有 "
            "— 先跑 merge-gcp-stdout.sh 落檔（G3）",
            file=sys.stderr,
        )
        sys.exit(1)

    threads = sorted(
        {int(p.parent.parent.name.split("-")[1]) for p in gcp_files}
    )
    thread_results = {}
    for t in threads:
        rounds = sorted(
            (runs_dir / f"threads-{t}").glob("round-*/go-tpc-stdout-gcp.txt")
        )
        round_results = [parse_round(r) for r in rounds]
        thread_results[str(t)] = aggregate_thread_group(round_results, profile)

    with open(summary_path, encoding="utf-8") as f:
        summary = json.load(f)

    # 冪等：只覆寫頂層 gcp_side；IDC 既有鍵零變動（G1/G3）
    summary["gcp_side"] = {
        "profile": profile,
        "throughput_note": (
            "read_tpmTotal 為 GCP 端 go-tpc [Summary] tpmTotal；A-A-RO 唯讀 mix 無 "
            "NEW_ORDER → tpmC 無定義（null），不可與 IDC tpmC 比大小（G2）"
        ),
        "source_files": "runs/threads-*/round-*/go-tpc-stdout-gcp.txt",
        "generated_at": datetime.now().astimezone().isoformat(),
        "generated_by": "phase-crossregion/scripts/summary-gcp-side.py v1",
        "thread_results": thread_results,
    }

    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"wrote gcp_side ({profile}, threads={threads}) → {summary_path}")


if __name__ == "__main__":
    main()
