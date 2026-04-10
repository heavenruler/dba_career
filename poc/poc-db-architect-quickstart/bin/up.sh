#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_REDIS_IMAGE="docker.io/library/redis:7.2-alpine"
DEFAULT_MYSQL_IMAGE="__MYSQL_IMAGE__"
DEFAULT_MARIADB_IMAGE="__MARIADB_IMAGE__"
DEFAULT_PROXYSQL_IMAGE="__PROXYSQL_IMAGE__"
DEFAULT_MYSQL_ROUTER_IMAGE="__MYSQL_ROUTER_IMAGE__"
ROOT_DIR_PLACEHOLDER="__ROOT_DIR__"

usage() {
  echo "Usage: $0 [--logs] <scenario>"
}

if [[ "${1:-}" == "--logs" ]]; then
  SCENARIO="${2:-}"
  [[ -n "${SCENARIO}" ]] || { usage; exit 1; }
  CONTAINERS="$(podman ps --format '{{.Names}}' | grep "^${SCENARIO}-" || true)"
  if [[ -z "${CONTAINERS}" ]]; then
    echo "[WARN] 找不到執行中的容器: ${SCENARIO}-*"
    exit 0
  fi
  while read -r c; do
    echo "===== $c ====="
    podman logs --tail 80 "$c"
  done <<<"${CONTAINERS}"
  exit 0
fi

SCENARIO="${1:-}"
[[ -n "${SCENARIO}" ]] || { usage; exit 1; }

KUBE_FILE="${ROOT_DIR}/scenarios/${SCENARIO}/kube.yaml"
[[ -f "${KUBE_FILE}" ]] || { echo "[ERROR] 找不到 scenario: ${SCENARIO}"; exit 1; }

REDIS_VERSION="${REDIS_VERSION:-7.2-alpine}"
REDIS_IMAGE="docker.io/library/redis:${REDIS_VERSION}"
MYSQL_VERSION="${MYSQL_VERSION:-8.4}"
MYSQL_IMAGE="docker.io/library/mysql:${MYSQL_VERSION}"
MARIADB_VERSION="${MARIADB_VERSION:-10.11}"
MARIADB_IMAGE="docker.io/library/mariadb:${MARIADB_VERSION}"
PROXYSQL_VERSION="${PROXYSQL_VERSION:-2.6.6}"
PROXYSQL_IMAGE="docker.io/proxysql/proxysql:${PROXYSQL_VERSION}"

case "${MYSQL_VERSION}" in
  8.0*) MYSQL_ROUTER_IMAGE="container-registry.oracle.com/mysql/community-router:8.0.43" ;;
  8.4*) MYSQL_ROUTER_IMAGE="container-registry.oracle.com/mysql/community-router:8.4.8" ;;
  9.6*) MYSQL_ROUTER_IMAGE="container-registry.oracle.com/mysql/community-router:9.6.0" ;;
  5.7*) MYSQL_ROUTER_IMAGE="" ;;
  *) MYSQL_ROUTER_IMAGE="container-registry.oracle.com/mysql/community-router:8.4.8" ;;
esac

case "${SCENARIO}" in
  mysql-group-replication|mysql-innodb-cluster)
    if [[ "${MYSQL_VERSION}" == 5.7* ]]; then
      echo "[ERROR] ${SCENARIO} 不支援 MYSQL_VERSION=${MYSQL_VERSION}，請改用 8.0 / 8.4 / 9.6"
      exit 1
    fi
    ;;
esac

if [[ "${SCENARIO}" == "mysql-innodb-cluster" && -z "${MYSQL_ROUTER_IMAGE}" ]]; then
  echo "[ERROR] mysql-innodb-cluster 找不到對應的 MySQL Router image"
  exit 1
fi

TMP_KUBE_FILE="$(mktemp)"
trap 'rm -f "${TMP_KUBE_FILE}"' EXIT

sed \
  -e "s|${DEFAULT_REDIS_IMAGE}|${REDIS_IMAGE}|g" \
  -e "s|${DEFAULT_MYSQL_IMAGE}|${MYSQL_IMAGE}|g" \
  -e "s|${DEFAULT_MARIADB_IMAGE}|${MARIADB_IMAGE}|g" \
  -e "s|${DEFAULT_PROXYSQL_IMAGE}|${PROXYSQL_IMAGE}|g" \
  -e "s|${DEFAULT_MYSQL_ROUTER_IMAGE}|${MYSQL_ROUTER_IMAGE}|g" \
  -e "s|${ROOT_DIR_PLACEHOLDER}|${ROOT_DIR}|g" \
  "${KUBE_FILE}" >"${TMP_KUBE_FILE}"

podman kube play --replace "${TMP_KUBE_FILE}"
echo "[OK] Scenario 已啟動: ${SCENARIO}"
echo "[INFO] REDIS_IMAGE=${REDIS_IMAGE} MYSQL_IMAGE=${MYSQL_IMAGE} MARIADB_IMAGE=${MARIADB_IMAGE} PROXYSQL_IMAGE=${PROXYSQL_IMAGE} MYSQL_ROUTER_IMAGE=${MYSQL_ROUTER_IMAGE}"
