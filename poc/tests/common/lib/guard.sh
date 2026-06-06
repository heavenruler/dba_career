#!/usr/bin/env bash
# guard.sh — phase isolation hard gate helpers (T105 Layer 3).
#
# Sources: phase-threadcontrol/guardrails.md + results/PHASES.md.
#
# Helpers (callers source this file then invoke functions):
#
#   assert_baseline_target <output_path>
#     - baseline target (vm1/vm3/phase-k8s/phase-crossregion) refuses if:
#       * $TUNING_PROFILE is set (any non-empty value)
#       * <output_path> contains /T-THRD/
#
#   assert_threadcontrol_target <output_path>
#     - phase-threadcontrol target refuses if:
#       * <output_path> missing /T-THRD/
#       * <output_path> contains /S-BASE/ /S-K8S/ /X-CROSS/
#       * $TUNING_PROFILE is unset OR equals "default"
#
#   assert_phase_k8s_target <output_path>
#     - phase-k8s target requires /S-K8S/, refuses /T-THRD/ /S-BASE/ /X-CROSS/
#
#   assert_phase_crossregion_target <output_path>
#     - phase-crossregion target requires /X-CROSS/, refuses /T-THRD/ /S-BASE/ /S-K8S/
#
# Exit 1 on guard fail. Caller is expected to invoke before any side-effecting work.

# Internal die — uses local stderr if common.sh die() not available.
_guard_die() {
  echo "[guard] FAIL: $*" >&2
  exit 1
}

# Helper: does path contain a /SCOPE/ segment?
_path_has_scope() {
  local p="$1" scope="$2"
  [[ "$p" == *"/$scope/"* ]]
}

assert_baseline_target() {
  local out="${1:-}"
  [[ -n "$out" ]] || _guard_die "assert_baseline_target: missing output_path arg"
  if [[ -n "${TUNING_PROFILE:-}" ]]; then
    _guard_die "TUNING_PROFILE='$TUNING_PROFILE' set on baseline target — refusing (would taint baseline)."
  fi
  if _path_has_scope "$out" "T-THRD"; then
    _guard_die "baseline target output_path='$out' contains /T-THRD/ — wrong scope."
  fi
  return 0
}

assert_threadcontrol_target() {
  local out="${1:-}"
  [[ -n "$out" ]] || _guard_die "assert_threadcontrol_target: missing output_path arg"
  _path_has_scope "$out" "T-THRD" || _guard_die "phase-threadcontrol output_path='$out' missing /T-THRD/."
  for forbidden in S-BASE S-K8S X-CROSS; do
    if _path_has_scope "$out" "$forbidden"; then
      _guard_die "phase-threadcontrol output_path='$out' contains forbidden scope /$forbidden/."
    fi
  done
  local prof="${TUNING_PROFILE:-}"
  [[ -n "$prof" ]] || _guard_die "TUNING_PROFILE unset — phase-threadcontrol requires a non-default profile id."
  [[ "$prof" != "default" ]] || _guard_die "TUNING_PROFILE='default' — must be specific (e.g. tidb-readpool-a)."
  return 0
}

assert_phase_k8s_target() {
  local out="${1:-}"
  [[ -n "$out" ]] || _guard_die "assert_phase_k8s_target: missing output_path arg"
  _path_has_scope "$out" "S-K8S" || _guard_die "phase-k8s output_path='$out' missing /S-K8S/."
  for forbidden in S-BASE T-THRD X-CROSS; do
    if _path_has_scope "$out" "$forbidden"; then
      _guard_die "phase-k8s output_path='$out' contains forbidden scope /$forbidden/."
    fi
  done
  return 0
}

assert_phase_crossregion_target() {
  local out="${1:-}"
  [[ -n "$out" ]] || _guard_die "assert_phase_crossregion_target: missing output_path arg"
  _path_has_scope "$out" "X-CROSS" || _guard_die "phase-crossregion output_path='$out' missing /X-CROSS/."
  for forbidden in S-BASE S-K8S T-THRD; do
    if _path_has_scope "$out" "$forbidden"; then
      _guard_die "phase-crossregion output_path='$out' contains forbidden scope /$forbidden/."
    fi
  done
  return 0
}

# Self-test mode: invoke `guard.sh --self-test` to verify expected exits.
if [[ "${1:-}" == "--self-test" ]]; then
  set +e
  rc=0

  echo "== assert_baseline_target with valid path"
  ( assert_baseline_target "results/tidb-tc1/S-BASE/foo-rc-ts" ) && echo "  pass" || { echo "  FAIL"; rc=1; }

  echo "== assert_baseline_target rejects TUNING_PROFILE"
  ( TUNING_PROFILE="tidb-readpool-a" assert_baseline_target "results/tidb-tc1/S-BASE/foo" ) \
    && { echo "  FAIL (should have rejected)"; rc=1; } || echo "  pass"

  echo "== assert_baseline_target rejects T-THRD path"
  ( assert_baseline_target "results/tidb-tc1/T-THRD/foo" ) \
    && { echo "  FAIL (should have rejected)"; rc=1; } || echo "  pass"

  echo "== assert_threadcontrol_target accepts valid path + profile"
  ( TUNING_PROFILE="tidb-readpool-a" assert_threadcontrol_target "results/tidb-tc1/T-THRD/foo" ) \
    && echo "  pass" || { echo "  FAIL"; rc=1; }

  echo "== assert_threadcontrol_target rejects missing profile"
  ( assert_threadcontrol_target "results/tidb-tc1/T-THRD/foo" ) \
    && { echo "  FAIL (should have rejected)"; rc=1; } || echo "  pass"

  echo "== assert_threadcontrol_target rejects default profile"
  ( TUNING_PROFILE="default" assert_threadcontrol_target "results/tidb-tc1/T-THRD/foo" ) \
    && { echo "  FAIL"; rc=1; } || echo "  pass"

  echo "== assert_threadcontrol_target rejects S-BASE path"
  ( TUNING_PROFILE="tidb-readpool-a" assert_threadcontrol_target "results/tidb-tc1/S-BASE/foo" ) \
    && { echo "  FAIL"; rc=1; } || echo "  pass"

  echo "== assert_phase_k8s_target accepts /S-K8S/"
  ( assert_phase_k8s_target "results/tidb-tc1/S-K8S/foo" ) \
    && echo "  pass" || { echo "  FAIL"; rc=1; }

  echo "== assert_phase_k8s_target rejects /S-BASE/"
  ( assert_phase_k8s_target "results/tidb-tc1/S-BASE/foo" ) \
    && { echo "  FAIL"; rc=1; } || echo "  pass"

  echo "== assert_phase_crossregion_target accepts /X-CROSS/"
  ( assert_phase_crossregion_target "results/tidb-tc1/X-CROSS/foo" ) \
    && echo "  pass" || { echo "  FAIL"; rc=1; }

  exit $rc
fi
