#!/usr/bin/env python3
# vm-rebuild-proof.py — F4: capture terraform resource IDs after VM rebuild.
# 由 Makefile phase1-proof 呼叫（原 python3 -c 單行版因 make 摺行把 if/else
# 壓成同一行而 SyntaxError，抽成本檔）。
# Usage: vm-rebuild-proof.py --ts <TPCC_TS> --idc-dir iac-idc --gcp-dir iac-gcp --out <json>
import argparse
import datetime
import json
import os
import subprocess


def tf_resource_ids(chdir):
    r = subprocess.run(
        ["terraform", f"-chdir={chdir}", "show", "-json"],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        return {"error": r.stderr[:200]}
    d = json.loads(r.stdout)
    out = {}
    for res in d.get("values", {}).get("root_module", {}).get("resources", []):
        out[res["address"]] = res.get("values", {}).get("id", "?")
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--ts", required=True)
    p.add_argument("--idc-dir", required=True)
    p.add_argument("--gcp-dir", required=True)
    p.add_argument("--out", required=True)
    a = p.parse_args()

    proof = {
        "ts": a.ts,
        "built_at": datetime.datetime.now().astimezone().strftime("%Y-%m-%dT%H:%M:%S%z"),
        "idc": tf_resource_ids(a.idc_dir),
        "gcp": tf_resource_ids(a.gcp_dir),
    }
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with open(a.out, "w") as f:
        json.dump(proof, f, indent=2)
    print(f"  idc_resources={len(proof['idc'])}  gcp_resources={len(proof['gcp'])}  → {a.out}")


if __name__ == "__main__":
    main()
