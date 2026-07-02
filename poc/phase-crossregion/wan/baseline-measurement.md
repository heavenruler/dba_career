# WAN Baseline Measurement（原 B4 Pre-P0 hard gate — 已被 Q2 取消）

> **Superseded by [`decisions-2026-06-08.md`](../decisions-2026-06-08.md) Q2**：B4 「RTT p50<50 /
> p99<200 / BW>100Mbps / loss<1%」**hard gate 已取消**。改為 mrtg 即時觀察 + benchmark 期間
> 隨 workload inline 採樣（寫入 `runs/threads-N/round-N/wan-probe.txt`；見 `scripts/wan-probe.sh`），
> 偏離 mrtg 趨勢則記 warn，不再作前置獨立階段 / 不 fail-closed。以下腳本與門檻保留為量測方法參考。

## 為何必須

phase-crossregion 任何 tpmC / latency 數據要可歸因，必須先量化 WAN 本身：
- 若 RTT > 50ms → Test 1 tpmC 預期 < 30% baseline → 須與 user 重議 PoC 假設
- 若 throughput 不穩 → 結果無法跨時段比較

決議來源：[`0602-decisions-track-E.md`](../../1_MeetingMinutes/0602-decisions-track-E.md) B4 ✓ Pre-P0 hard gate。

## 量測腳本（建議落地至 phase-crossregion/wan/baseline.sh）

```bash
#!/usr/bin/env bash
# Pre-P0 WAN baseline; runs against IDC ↔ GCP per direction.
# Output: phase-crossregion/wan/baseline-<TS>/

set -euo pipefail
TS=$(date '+%Y%m%dT%H%M%S%z')
OUT="phase-crossregion/wan/baseline-${TS}"
mkdir -p "$OUT"

# Endpoints
IDC_HOST=172.24.40.32
GCP_HOST=10.160.152.13   # via IAP tunnel localhost:12213

# --- 1. iperf3 throughput (forward + reverse) ---
ssh root@$IDC_HOST 'iperf3 -s -D -p 5201'        # start GCP-side server (one-time)
iperf3 -c $IDC_HOST -p 5201 -t 60 -J > "$OUT/iperf3-idc-to-gcp.json"
iperf3 -c $IDC_HOST -p 5201 -t 60 -R -J > "$OUT/iperf3-gcp-to-idc.json"

# --- 2. ping p50/p99 (60s + 60s, business hour) ---
ssh root@$GCP_HOST "ping -c 18000 -i 0.2 $IDC_HOST" > "$OUT/ping-gcp-to-idc.txt"
ssh root@$IDC_HOST "ping -c 18000 -i 0.2 $GCP_HOST" > "$OUT/ping-idc-to-gcp.txt"

# --- 3. MTU 探測 ---
ssh root@$GCP_HOST "tracepath -n $IDC_HOST" > "$OUT/tracepath-gcp-to-idc.txt"
ssh root@$IDC_HOST "tracepath -n $GCP_HOST" > "$OUT/tracepath-idc-to-gcp.txt"

# --- 4. 飽和 packet loss (背景 iperf3 + ping) ---
ssh root@$GCP_HOST "iperf3 -c $IDC_HOST -p 5201 -t 120 -P 4 &"
ssh root@$GCP_HOST "ping -c 1000 -i 0.1 $IDC_HOST" > "$OUT/ping-during-saturation.txt"

# --- 5. 分析 + 報表 ---
python3 tests/common/wan-baseline-analyze.py "$OUT" > "$OUT/SUMMARY.md"
```

## 多時段抽樣

| 時段 | 預期 |
|---|---|
| Business hour (09-18) | 較高負載，p99 可能 spike |
| Off-peak (00-06) | baseline |
| Lunch (12-13) | 偶有 spike（intra-IDC 影響）|

至少 3 時段抽樣，取代表值。

## 通過標準

| 維度 | 必須條件 |
|---|---|
| RTT p50 | < 50 ms（必要 hard gate；超過須重議 PoC）|
| RTT p99 | < 200 ms |
| Throughput | > 100 Mbps（單向）|
| MTU | ≥ 1500 (no fragmentation in tunnel) |
| Packet loss (飽和下) | < 1% |

不通過任一項 → Pre-P0 fail，須與 user 議是否調整 PoC scope 或網路配置。

## 落地交付物（per measurement run）

```
phase-crossregion/wan/baseline-<TS>/
├── iperf3-idc-to-gcp.json
├── iperf3-gcp-to-idc.json
├── ping-idc-to-gcp.txt
├── ping-gcp-to-idc.txt
├── tracepath-gcp-to-idc.txt
├── tracepath-idc-to-gcp.txt
├── ping-during-saturation.txt
└── SUMMARY.md (auto-generated)
```

## Pending

- `phase-crossregion/wan/baseline.sh` 實作（本 commit 只落 spec markdown，腳本待 Pre-P0）
- `tests/common/wan-baseline-analyze.py` Python parser 實作

## 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-06 | (本) | 初版 measurement plan + 通過標準 + 腳本骨架 |
