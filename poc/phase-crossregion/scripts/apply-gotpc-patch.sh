#!/usr/bin/env bash
# phase-crossregion/scripts/apply-gotpc-patch.sh
#
# 固化 §8 A8 發現的 go-tpc/lib/pq 近讀結構性衝突修法：從原始碼重建
# patched go-tpc 並部署到 GCP client，不依賴人工記得套用。每次 GCP
# client 重建，phase2-bootstrap-gcp-client 都會裝回未 patch 的官方
# release binary——若忘記重新套用此步驟，CRDB 會 100% 查詢報錯、YBDB
# 會延遲/吞吐量靜默劣化（不報錯）。詳見 patches/README.md、報告
# §5.7/§5.8/§8 A8。
#
# 冪等：每次呼叫都重新 clone+build+部署，不做「已套用就跳過」判斷——
# 建置成本低（~30s），不值得為了省時間引入「怎麼判斷已套用」的額外
# 複雜度與潛在誤判風險。
#
# 前提：跑在 .31 上（有 git／可用 dnf 裝 golang／對 GCP client 可 ssh）。
#
# 注意：跑在 .31 上時，phase-crossregion/scripts/ 的內容會被攤平 rsync 到
# /tmp/poc-tpcc/scripts/crossregion/（同層，非巢狀），與本機 phase-crossregion/
# 下 scripts/、patches/ 是手足目錄的結構不同，所以 patch 檔路徑不能用
# `$SCRIPT_DIR/../patches` 這種相對路徑推導，改用 $POC=/tmp/poc 這個各 driver
# （win-aaro-w128.sh、verify-a7/a8-smoke.sh）共用的錨點（見 --patch-file 預設值），
# Makefile detach targets 需確保 phase-crossregion/patches/ 也 rsync 到
# /tmp/poc/phase-crossregion/patches/。
#
# Usage: apply-gotpc-patch.sh [--gcp-client root@10.160.152.15] [--patch-file <path>]
set -euo pipefail

GCP_CLIENT="root@10.160.152.15"
PATCH_FILE="/tmp/poc/phase-crossregion/patches/go-tpc-readonly-fix.patch"
while [[ $# -gt 0 ]]; do
  case $1 in
    --gcp-client) GCP_CLIENT=$2; shift 2 ;;
    --patch-file) PATCH_FILE=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
BASE_COMMIT="a9ca4818625deef91ff80f6c395a575ccae22b7c"
BUILD_DIR="/tmp/go-tpc-patch-build"

[[ -f "$PATCH_FILE" ]] || { echo "[apply-gotpc-patch] FATAL: patch 檔不存在 $PATCH_FILE" >&2; exit 1; }

echo "[apply-gotpc-patch] 確認 golang 已安裝（冪等）"
command -v go >/dev/null 2>&1 || dnf install -y -q golang

echo "[apply-gotpc-patch] clone go-tpc @ $BASE_COMMIT"
rm -rf "$BUILD_DIR"
git clone --quiet https://github.com/pingcap/go-tpc.git "$BUILD_DIR"
(cd "$BUILD_DIR" && git checkout --quiet "$BASE_COMMIT")

echo "[apply-gotpc-patch] apply patch"
(cd "$BUILD_DIR" && git apply "$PATCH_FILE")

echo "[apply-gotpc-patch] build linux/amd64"
(cd "$BUILD_DIR" && GOOS=linux GOARCH=amd64 GOEXPERIMENT=jsonv2 CGO_ENABLED=0 GO111MODULE=on \
  go build -o ./bin/go-tpc-patched ./cmd/go-tpc/)

echo "[apply-gotpc-patch] 部署到 $GCP_CLIENT（首次備份原始 binary 為 go-tpc.orig）"
ssh -o ConnectTimeout=8 "$GCP_CLIENT" \
  "[ -f /usr/local/bin/go-tpc.orig ] || cp -f /usr/local/bin/go-tpc /usr/local/bin/go-tpc.orig"
scp -o ConnectTimeout=8 "$BUILD_DIR/bin/go-tpc-patched" "$GCP_CLIENT:/usr/local/bin/go-tpc"
ssh -o ConnectTimeout=8 "$GCP_CLIENT" "chmod +x /usr/local/bin/go-tpc"

echo "[apply-gotpc-patch] 驗證部署後的 binary 可執行"
ssh -o ConnectTimeout=8 "$GCP_CLIENT" "/usr/local/bin/go-tpc tpcc --help >/dev/null 2>&1" \
  && echo "[apply-gotpc-patch] PASS：patched go-tpc 已部署到 $GCP_CLIENT" \
  || { echo "[apply-gotpc-patch] FAIL: 部署後的 go-tpc 無法執行" >&2; exit 1; }

rm -rf "$BUILD_DIR"
