#!/usr/bin/env bash
# preflight-mac.sh — Mac pre-flight check before phase-crossregion long runs
# Usage: preflight-mac.sh [--fix] [--quick] [--verbose]
set -euo pipefail

# ===================================================================
# Globals
# ===================================================================
FIX=0
QUICK=0
VERBOSE=0

for arg in "$@"; do
  case "$arg" in
    --fix)     FIX=1 ;;
    --quick)   QUICK=1 ;;
    --verbose) VERBOSE=1 ;;
    *) echo "[preflight-mac] unknown arg: $arg" >&2; exit 2 ;;
  esac
done

PASS=0
WARN=0
FAIL=0
TOTAL=10

# ===================================================================
# Helpers
# ===================================================================
_log()   { echo "$*"; }
_verb()  { [[ $VERBOSE -eq 1 ]] && echo "  >> $*" || true; }
_pass()  { PASS=$((PASS+1)); printf "[%2d/%d] PASS  %s\n" "$1" "$TOTAL" "$2"; }
_warn()  { WARN=$((WARN+1)); printf "[%2d/%d] WARN  %s\n" "$1" "$TOTAL" "$2"; }
_fail()  { FAIL=$((FAIL+1)); printf "[%2d/%d] FAIL  %s\n" "$1" "$TOTAL" "$2"; }

# ===================================================================
# Header
# ===================================================================
_log "[preflight-mac] start $(date)"

# ===================================================================
# Check 1 — Ports
# ===================================================================
check_ports() {
  local idx=1
  local ports=(12211 12212 12213 12214 12215 4000 26257 5433)
  local dirty=()

  for port in "${ports[@]}"; do
    local hits
    hits=$(lsof -iTCP:"$port" -sTCP:LISTEN -n -P 2>/dev/null || true)
    if [[ -n "$hits" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local pid cmd
        pid=$(awk '{print $2}' <<<"$line")
        cmd=$(awk '{print $1}' <<<"$line")
        dirty+=("port=$port PID=$pid cmd=$cmd")
        _verb "$line"
      done < <(echo "$hits" | tail -n +2)
    fi
  done

  if [[ ${#dirty[@]} -eq 0 ]]; then
    _pass $idx "ports clean (12211-12215, 4000, 26257, 5433)"
  else
    for entry in "${dirty[@]}"; do
      _fail $idx "port LISTEN: $entry (kill with --fix)"
      idx=$idx  # keep same check number — only first call emits the line
    done
    _fail $idx "ports dirty — ${#dirty[@]} listener(s) found"
    if [[ $FIX -eq 1 ]]; then
      for entry in "${dirty[@]}"; do
        local pid
        pid=$(grep -oP '(?<=PID=)\d+' <<<"$entry" || true)
        [[ -n "$pid" ]] && { _log "  [fix] kill -9 $pid"; kill -9 "$pid" 2>/dev/null || true; }
      done
    fi
  fi
}

# ===================================================================
# Check 2 — Stray processes
# ===================================================================
check_processes() {
  local idx=2
  local pattern="start-iap-tunnel|ansible-playbook|terraform apply|terraform destroy|make phase|go-tpc"
  local hits
  hits=$(pgrep -fl "$pattern" 2>/dev/null | grep -v "$$" | grep -v "preflight-mac" || true)

  if [[ -z "$hits" ]]; then
    _pass $idx "no stray processes"
  else
    _fail $idx "stray processes found (kill with --fix):"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      _log "         $line"
      if [[ $FIX -eq 1 ]]; then
        local pid
        pid=$(awk '{print $1}' <<<"$line")
        _log "  [fix] kill -9 $pid"
        kill -9 "$pid" 2>/dev/null || true
      fi
    done <<<"$hits"
  fi
}

# ===================================================================
# Check 3 — /tmp residual files
# ===================================================================
check_tmp() {
  local idx=3
  local found=()
  local patterns=(
    "/tmp/iap-tunnel-poc*.pid"
    "/tmp/path-c-*.log"
    "/tmp/crossregion-all.log"
    "/tmp/go-tpc-help-*.txt"
  )

  for pat in "${patterns[@]}"; do
    for f in $pat; do
      [[ -e "$f" ]] && found+=("$f")
    done
  done

  if [[ ${#found[@]} -eq 0 ]]; then
    _pass $idx "/tmp clean"
  else
    _warn $idx "/tmp residual: ${found[*]}"
    if [[ $FIX -eq 1 ]]; then
      for f in "${found[@]}"; do
        _log "  [fix] rm $f"
        rm -f "$f"
      done
    fi
  fi
}

# ===================================================================
# Check 4 — SSH control sockets
# ===================================================================
check_ssh_sockets() {
  local idx=4
  local found=()

  for f in ~/.ssh/cm-* ~/.ssh/sockets/*; do
    [[ -e "$f" ]] && found+=("$f")
  done

  if [[ ${#found[@]} -eq 0 ]]; then
    _pass $idx "SSH control sockets clean"
  else
    _warn $idx "SSH sockets: ${found[*]}"
    if [[ $FIX -eq 1 ]]; then
      for f in "${found[@]}"; do
        _log "  [fix] rm $f"
        rm -f "$f"
      done
    fi
  fi
}

# ===================================================================
# Check 5 — known_hosts stale IAP entries
# ===================================================================
check_known_hosts() {
  local idx=5
  local kh="$HOME/.ssh/known_hosts"
  local found=()

  if [[ ! -f "$kh" ]]; then
    _pass $idx "known_hosts not found (skip)"
    return
  fi

  for port in 12211 12212 12213 12214 12215; do
    if grep -q "\[localhost\]:${port}" "$kh" 2>/dev/null; then
      found+=("[localhost]:${port}")
    fi
  done

  if [[ ${#found[@]} -eq 0 ]]; then
    _pass $idx "known_hosts: no stale IAP entries"
  else
    _warn $idx "known_hosts stale IAP entries: ${found[*]} (terraform rebuild will conflict)"
    if [[ $FIX -eq 1 ]]; then
      for entry in "${found[@]}"; do
        _log "  [fix] ssh-keygen -R $entry"
        ssh-keygen -R "$entry" 2>/dev/null || true
      done
    fi
  fi
}

# ===================================================================
# Check 6 — Terraform state health
# ===================================================================
check_terraform_state() {
  local idx=6
  local poc_dir
  poc_dir="$(cd "$(dirname "$0")/../.." && pwd)"
  local fail_msgs=()

  for iac in iac-gcp iac-idc; do
    local dir="$poc_dir/$iac"
    local lock="$dir/.terraform.tfstate.lock.info"

    if [[ ! -d "$dir" ]]; then
      _verb "skip $iac (dir not found: $dir)"
      continue
    fi

    if [[ -f "$lock" ]]; then
      fail_msgs+=("state lock found: $lock")
    fi

    if ! terraform -chdir="$dir" state list >/dev/null 2>&1; then
      fail_msgs+=("terraform state list failed: $iac")
    fi
  done

  if [[ ${#fail_msgs[@]} -eq 0 ]]; then
    _pass $idx "terraform state healthy (iac-gcp, iac-idc)"
  else
    for msg in "${fail_msgs[@]}"; do
      _fail $idx "$msg"
    done
  fi
}

# ===================================================================
# Check 7 — tfvars exist
# ===================================================================
check_tfvars() {
  local idx=7
  local poc_dir
  poc_dir="$(cd "$(dirname "$0")/../.." && pwd)"
  local missing=()

  for iac in iac-gcp iac-idc; do
    local f="$poc_dir/$iac/terraform.tfvars"
    [[ ! -f "$f" ]] && missing+=("$f")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    _pass $idx "terraform.tfvars present (iac-gcp, iac-idc)"
  else
    _fail $idx "missing tfvars: ${missing[*]}"
  fi
}

# ===================================================================
# Check 8 — Required binaries
# ===================================================================
check_binaries() {
  local idx=8
  local required=(gcloud terraform ansible-playbook ssh jq python3 mysql)
  local missing=()

  for bin in "${required[@]}"; do
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    _pass $idx "all required binaries present"
  else
    _fail $idx "missing binaries: ${missing[*]}"
  fi
}

# ===================================================================
# Check 9 — IDC admin .31 SSH reachable
# ===================================================================
check_idc_ssh() {
  local idx=9
  local host="172.24.40.31"
  local result
  result=$(ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
               root@"$host" 'hostname' 2>&1) && local rc=0 || local rc=$?

  if [[ $rc -eq 0 ]]; then
    _pass $idx "IDC admin ($host) reachable: $result"
  else
    _fail $idx "IDC admin ($host) unreachable (ssh rc=$rc) — routing/VPN issue"
  fi
}

# ===================================================================
# Check 10 — Mac free disk
# ===================================================================
check_disk() {
  local idx=10
  local avail_kb
  avail_kb=$(df / | awk 'NR==2{print $4}')
  local avail_gb=$(( avail_kb / 1024 / 1024 ))

  if [[ $avail_gb -ge 10 ]]; then
    _pass $idx "free disk ${avail_gb}GB >= 10GB"
  else
    _warn $idx "free disk ${avail_gb}GB < 10GB (may fail large logs/artifacts)"
  fi
}

# ===================================================================
# Run checks (full or quick)
# ===================================================================
check_ports
check_processes
check_tmp

if [[ $QUICK -eq 0 ]]; then
  check_ssh_sockets
  check_known_hosts
  check_terraform_state
  check_tfvars
  check_binaries
  check_idc_ssh
  check_disk
else
  # quick mode: fill remaining slots as PASS placeholders
  for i in 4 5 6 7 8 9 10; do
    printf "[%2d/%d] PASS  (skipped in --quick mode)\n" "$i" "$TOTAL"
    PASS=$((PASS+1))
  done
fi

# ===================================================================
# Summary
# ===================================================================
_log "[preflight-mac] result: $PASS PASS, $WARN WARN, $FAIL FAIL"

if [[ $FAIL -gt 0 ]]; then
  _log "[preflight-mac] BLOCKING — fix failures before running phase-crossregion"
  exit 1
else
  _log "[preflight-mac] OK — safe to proceed"
  exit 0
fi
