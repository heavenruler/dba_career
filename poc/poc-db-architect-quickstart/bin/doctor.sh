#!/usr/bin/env bash
set -euo pipefail

echo "== podman version =="
podman version

echo
echo "== podman machine list =="
podman machine list

echo
echo "== podman info =="
podman info --format 'Host={{.Host.Os}} Arch={{.Host.Arch}} CgroupVersion={{.Host.CgroupVersion}}'

echo
echo "[OK] 環境檢查完成"
