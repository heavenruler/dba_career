#!/usr/bin/env bash
# phase-crossregion/scripts/wan-probe.sh
#
# WAN passive sampler + opt-in iperf3 (per REPLAN-2026-06-15.md §4).
#
# 取樣 3 對 cross-region host pair (IDC ↔ GCP)：
#   driver:    idc-driver    (172.24.40.31)  ↔  gcp-poc-5  (10.160.152.15)
#   db:        idc-dbhost-1  (172.24.40.32)  ↔  gcp-poc-1  (10.160.152.11)
#   haproxy:   idc-haproxy   (172.24.47.20)  ↔  gcp-poc-4  (10.160.152.14)
#
# GCP 定址：.31 直連 GCP 內網 IP（比照 CLUSTER_HOSTS/run.sh，bug #11）。
#   舊版走 IAP tunnel localhost:1221x，detached 在 .31 跑時無 tunnel → 全 rc=255；已改直連。
#
# 模式：
#   passive (default)：
#     - chronyc tracking × 6 host (per pair: 兩端 Last offset / Stratum / Leap status)
#     - /proc/net/dev byte counter snapshot (RX/TX) — 兩次採樣計算 delta 需多次呼叫合併
#       (本 script 單次採樣 dump 當下 counter，由 caller 在不同 phase 比較)
#   opt-in iperf3 (WAN_PROBE_IPERF=1)：
#     - iperf3 5s TCP test idc-dbhost-1 → gcp-dbhost-1 (forward) + reverse
#     - **只在 round 間隙跑** — caller 須以 --phase warmup-post 或 sweep-pre 呼叫；
#       --phase round-pre / round-post **跳過** iperf3 (避免干擾 benchmark)
#     - 若兩端任一缺 iperf3 binary → warn-only skip
#
# 用法：
#   wan-probe.sh --phase <warmup|warmup-post|sweep-pre|sweep-post|round-pre|round-post> \
#                --out-dir <path> --ts <ts>
#
# Env overrides：
#   IDC_DRIVER_ADDR   (default root@172.24.40.31)
#   IDC_DBHOST1_ADDR  (default root@172.24.40.32)
#   IDC_HAPROXY_ADDR  (default root@172.24.47.20)
#   GCP_DRIVER_ADDR   (default root@10.160.152.15  — gcp-poc-5，直連內網 IP)
#   GCP_DBHOST1_ADDR  (default root@10.160.152.11  — gcp-poc-1)
#   GCP_HAPROXY_ADDR  (default root@10.160.152.14  — gcp-poc-4)
#   WAN_PROBE_IPERF   (default 0; set 1 to enable iperf3)
#   WAN_NIC           (default auto; auto=每台偵測 default-route NIC，IDC=ens33 / GCP=eth0)
#
# Output：
#   <out-dir>/wan-probe-<phase>.txt           # all passive + iperf3 sections appended
#   <out-dir>/wan-probe-<phase>.failed.txt    # stamp 留痕；任一 SSH/chronyc/iperf3 失敗即建立
#
# fail-closed 政策 (per REPLAN §4)：
#   採樣失敗 warn-only，不 exit 1，不阻斷 sweep。

set -uo pipefail   # 不用 -e：sampler 容忍 individual probe failure

PHASE=""
OUT_DIR=""
TS=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --phase) PHASE=$2; shift 2 ;;
    --out-dir) OUT_DIR=$2; shift 2 ;;
    --ts) TS=$2; shift 2 ;;
    *) echo "[wan-probe] unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$PHASE"   ]] || { echo "[wan-probe] --phase required" >&2; exit 1; }
[[ -n "$OUT_DIR" ]] || { echo "[wan-probe] --out-dir required" >&2; exit 1; }
[[ -n "$TS"      ]] || { echo "[wan-probe] --ts required" >&2; exit 1; }

case "$PHASE" in
  warmup|warmup-post|sweep-pre|sweep-post|round-pre|round-post) ;;
  *) echo "[wan-probe] invalid phase: $PHASE" >&2; exit 1 ;;
esac

mkdir -p "$OUT_DIR"

: "${IDC_DRIVER_ADDR:=root@172.24.40.31}"
: "${IDC_DBHOST1_ADDR:=root@172.24.40.32}"
: "${IDC_HAPROXY_ADDR:=root@172.24.47.20}"
# GCP：.31 直連內網 IP（不走 IAP tunnel localhost:1221x — 見 bug #11）
: "${GCP_DRIVER_ADDR:=root@10.160.152.15}"
: "${GCP_DBHOST1_ADDR:=root@10.160.152.11}"
: "${GCP_HAPROXY_ADDR:=root@10.160.152.14}"
: "${WAN_PROBE_IPERF:=0}"
: "${WAN_NIC:=auto}"

OUT_TXT="$OUT_DIR/wan-probe-${PHASE}.txt"
FAILED_STAMP="$OUT_DIR/wan-probe-${PHASE}.failed.txt"
FAILED=0

note_fail() {
  FAILED=1
  printf "[wan-probe][warn] %s\n" "$*" >&2
  printf "%s\n" "$*" >> "$FAILED_STAMP"
}

ssh_idc() {  # ssh_idc <user@host> <remote-cmd>
  ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
      -o BatchMode=yes -o LogLevel=ERROR "$1" "$2" 2>&1
}

ssh_gcp() {  # ssh_gcp <user@host> <remote-cmd> — .31 直連 GCP 內網 IP（與 ssh_idc 同機制）
  ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
      -o BatchMode=yes -o LogLevel=ERROR "$1" "$2" 2>&1
}

# 遠端 netdev 採樣命令：WAN_NIC=auto 時偵測 default-route NIC（IDC=ens33 / GCP=eth0 不同），
# 否則用指定 NIC；dump /proc/net/dev 該行（欄位 $2=rx_bytes、$10=tx_bytes）。
# 用 __NIC__ placeholder 避開本地 $WAN_NIC 與遠端 $ 的 escape 衝突。
NETDEV_CMD='n="__NIC__"; [ "$n" = auto ] && n=$(ip -o -4 route show to default 2>/dev/null | awk "{print \$5; exit}"); n=${n:-eth0}; awk -v nic="$n" "index(\$1, nic\":\")==1 {print}" /proc/net/dev'
NETDEV_CMD=${NETDEV_CMD/__NIC__/$WAN_NIC}

# ---- header ----------------------------------------------------------
{
  echo "=== wan-probe.sh  phase=$PHASE  ts=$TS  $(date -u +%FT%TZ) ==="
  echo "WAN_PROBE_IPERF=$WAN_PROBE_IPERF  WAN_NIC=$WAN_NIC"
  echo
} > "$OUT_TXT"

# ---- passive: chronyc tracking × 3 pair (兩端皆採) -------------------
{
  echo "--- chronyc tracking (3 pair × 2 端 = 6 host) ---"
} >> "$OUT_TXT"

probe_chrony_idc() {  # <label> <addr>
  local label=$1 addr=$2
  local raw
  raw=$(ssh_idc "$addr" "chronyc tracking")
  local rc=$?
  if [[ $rc -ne 0 || -z "$raw" ]]; then
    note_fail "chronyc IDC $label ($addr) failed rc=$rc"
    echo "[$label] (no data, rc=$rc)" >> "$OUT_TXT"
    return
  fi
  local stratum offset leap
  stratum=$(awk '/^Stratum/ {print $3; exit}'              <<< "$raw")
  offset=$( awk '/^Last offset/ {gsub(/[+s,]/,"",$4); print $4; exit}' <<< "$raw")
  leap=$(   awk -F': +' '/^Leap status/ {print $2; exit}'  <<< "$raw")
  printf "  [%-18s] stratum=%s last_offset=%s leap=%s\n" \
    "IDC/$label" "${stratum:-?}" "${offset:-?}" "${leap:-?}" >> "$OUT_TXT"
}

probe_chrony_gcp() {  # <label> <addr>
  local label=$1 addr=$2
  local raw
  raw=$(ssh_gcp "$addr" "chronyc tracking")
  local rc=$?
  if [[ $rc -ne 0 || -z "$raw" ]]; then
    note_fail "chronyc GCP $label ($addr) failed rc=$rc"
    echo "[$label] (no data, rc=$rc)" >> "$OUT_TXT"
    return
  fi
  local stratum offset leap
  stratum=$(awk '/^Stratum/ {print $3; exit}'              <<< "$raw")
  offset=$( awk '/^Last offset/ {gsub(/[+s,]/,"",$4); print $4; exit}' <<< "$raw")
  leap=$(   awk -F': +' '/^Leap status/ {print $2; exit}'  <<< "$raw")
  printf "  [%-18s] stratum=%s last_offset=%s leap=%s\n" \
    "GCP/$label" "${stratum:-?}" "${offset:-?}" "${leap:-?}" >> "$OUT_TXT"
}

# pair 1: driver
probe_chrony_idc "idc-driver"    "$IDC_DRIVER_ADDR"
probe_chrony_gcp "gcp-poc-5"     "$GCP_DRIVER_ADDR"
# pair 2: db
probe_chrony_idc "idc-dbhost-1"  "$IDC_DBHOST1_ADDR"
probe_chrony_gcp "gcp-poc-1"     "$GCP_DBHOST1_ADDR"
# pair 3: haproxy
probe_chrony_idc "idc-haproxy"   "$IDC_HAPROXY_ADDR"
probe_chrony_gcp "gcp-poc-4"     "$GCP_HAPROXY_ADDR"

echo >> "$OUT_TXT"

# ---- passive: /proc/net/dev byte counter snapshot --------------------
{
  echo "--- /proc/net/dev (NIC=$WAN_NIC) byte counter snapshot ---"
} >> "$OUT_TXT"

probe_netdev_idc() {  # <label> <addr>
  local label=$1 addr=$2
  local line
  line=$(ssh_idc "$addr" "$NETDEV_CMD")
  local rc=$?
  if [[ $rc -ne 0 || -z "$line" ]]; then
    note_fail "netdev IDC $label ($addr nic=$WAN_NIC) failed rc=$rc"
    echo "[$label] (no data, rc=$rc)" >> "$OUT_TXT"
    return
  fi
  # /proc/net/dev: iface: rx_bytes rx_packets ... tx_bytes tx_packets ...
  # columns: 2=rx_bytes, 10=tx_bytes
  local rx tx
  rx=$(awk '{print $2}' <<< "$line")
  tx=$(awk '{print $10}' <<< "$line")
  printf "  [%-18s] rx_bytes=%s tx_bytes=%s\n" \
    "IDC/$label" "${rx:-?}" "${tx:-?}" >> "$OUT_TXT"
}

probe_netdev_gcp() {  # <label> <addr>
  local label=$1 addr=$2
  local line
  line=$(ssh_gcp "$addr" "$NETDEV_CMD")
  local rc=$?
  if [[ $rc -ne 0 || -z "$line" ]]; then
    note_fail "netdev GCP $label ($addr nic=$WAN_NIC) failed rc=$rc"
    echo "[$label] (no data, rc=$rc)" >> "$OUT_TXT"
    return
  fi
  local rx tx
  rx=$(awk '{print $2}' <<< "$line")
  tx=$(awk '{print $10}' <<< "$line")
  printf "  [%-18s] rx_bytes=%s tx_bytes=%s\n" \
    "GCP/$label" "${rx:-?}" "${tx:-?}" >> "$OUT_TXT"
}

probe_netdev_idc "idc-driver"    "$IDC_DRIVER_ADDR"
probe_netdev_gcp "gcp-poc-5"     "$GCP_DRIVER_ADDR"
probe_netdev_idc "idc-dbhost-1"  "$IDC_DBHOST1_ADDR"
probe_netdev_gcp "gcp-poc-1"     "$GCP_DBHOST1_ADDR"
probe_netdev_idc "idc-haproxy"   "$IDC_HAPROXY_ADDR"
probe_netdev_gcp "gcp-poc-4"     "$GCP_HAPROXY_ADDR"

echo >> "$OUT_TXT"

# ---- opt-in iperf3 (round 間隙 only) ---------------------------------
if [[ "$WAN_PROBE_IPERF" == "1" ]]; then
  case "$PHASE" in
    round-pre|round-post)
      echo "--- iperf3: SKIP (phase=$PHASE 落在 round 內，避免干擾 benchmark) ---" >> "$OUT_TXT"
      echo >> "$OUT_TXT"
      ;;
    *)
      echo "--- iperf3 5s TCP idc-dbhost-1 ↔ gcp-dbhost-1 (forward + reverse) ---" >> "$OUT_TXT"

      # 兩端皆需 iperf3 binary
      idc_has=$(ssh_idc "$IDC_DBHOST1_ADDR" "command -v iperf3 >/dev/null 2>&1 && echo yes || echo no")
      gcp_has=$(ssh_gcp "$GCP_DBHOST1_ADDR" "command -v iperf3 >/dev/null 2>&1 && echo yes || echo no")

      if [[ "$idc_has" != "yes" || "$gcp_has" != "yes" ]]; then
        # iperf3 為 opt-in 主動壓測，缺 binary 不算 probe 失敗（不寫 failed.txt）——
        # 只做資訊性 skip。要啟用須先在缺的那端裝 iperf3（目前 IDC 端無）。
        printf "[wan-probe][info] iperf3 skip: binary missing (idc=%s gcp=%s)\n" "$idc_has" "$gcp_has" >&2
        echo "  [skip] iperf3 binary missing (opt-in，非失敗)  idc=$idc_has  gcp=$gcp_has" >> "$OUT_TXT"
      else
        # 跨區直連：idc-dbhost-1(172.24.40.32) ↔ gcp-dbhost-1(10.160.152.11)，內網 IP 直通。
        # 需目標端先啟 iperf3 -s（deployment 前置）；未啟則 -c 會回 error JSON（非空，仍留痕）。
        : "${IPERF_TARGET_GCP:=10.160.152.11}"  # idc → gcp 連線目標
        : "${IPERF_TARGET_IDC:=172.24.40.32}"   # gcp → idc 連線目標
        : "${IPERF_PORT:=5201}"
        # forward: idc-dbhost-1 client → gcp-dbhost-1 server
        echo "  [forward idc->gcp]  target=$IPERF_TARGET_GCP port=$IPERF_PORT" >> "$OUT_TXT"
        fwd=$(ssh_idc "$IDC_DBHOST1_ADDR" "iperf3 -c $IPERF_TARGET_GCP -t 5 -p $IPERF_PORT -J 2>&1 || true")
        if [[ -z "$fwd" ]]; then
          note_fail "iperf3 forward returned empty"
          echo "    (no output)" >> "$OUT_TXT"
        else
          echo "$fwd" | sed 's/^/    /' >> "$OUT_TXT"
        fi

        # reverse: gcp-dbhost-1 client → idc-dbhost-1 server
        echo "  [reverse gcp->idc]  target=$IPERF_TARGET_IDC port=$IPERF_PORT" >> "$OUT_TXT"
        rev=$(ssh_gcp "$GCP_DBHOST1_ADDR" "iperf3 -c $IPERF_TARGET_IDC -t 5 -p $IPERF_PORT -J 2>&1 || true")
        if [[ -z "$rev" ]]; then
          note_fail "iperf3 reverse returned empty"
          echo "    (no output)" >> "$OUT_TXT"
        else
          echo "$rev" | sed 's/^/    /' >> "$OUT_TXT"
        fi
      fi
      echo >> "$OUT_TXT"
      ;;
  esac
else
  echo "--- iperf3: DISABLED (WAN_PROBE_IPERF=0) ---" >> "$OUT_TXT"
  echo >> "$OUT_TXT"
fi

# ---- summary ---------------------------------------------------------
{
  if [[ $FAILED -eq 1 ]]; then
    echo "=== wan-probe done (some probes failed; see $FAILED_STAMP) ==="
  else
    echo "=== wan-probe done (all probes succeeded) ==="
  fi
} >> "$OUT_TXT"

# echo summary to stdout (caller hook 會 tee 進 run log)
cat "$OUT_TXT"

# fail-closed: warn-only，不 exit 1 (per REPLAN §4)
exit 0
