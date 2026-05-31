#!/usr/bin/env bash
# Verify key signals from a T390 focused GATT capture run.
# Usage:
#   ./verify-t390-gatt-capture.sh <run_ts> [artifacts_root]
#
# Example:
#   ./verify-t390-gatt-capture.sh 20260518-164256 \
#     artifacts/local-ble/2026-05-18-recapture-7-t390-gatt

set -euo pipefail

RUN_TS="${1:?Missing run_ts e.g. 20260518-164256}"
ROOT="${2:-artifacts/local-ble/2026-05-18-recapture-7-t390-gatt}"

ANDROID_LOG="$ROOT/android/${RUN_TS}-logcat.log"
# iOS capture helpers use either a stable filename convention in different
# runbooks (`...-ios-harness.log`, `...-harness.log`, etc.).
IOS_LOG_CANDIDATES=(
  "$ROOT/ios/${RUN_TS}-ios-emitter.log"
  "$ROOT/ios/${RUN_TS}-harness.log"
  "$ROOT/ios/${RUN_TS}-ios.log"
)

resolve_ios_log() {
  for candidate in "${IOS_LOG_CANDIDATES[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  local newest
  newest=$(ls -1t "$ROOT/ios" 2>/dev/null | grep -m1 "$RUN_TS\|harness\|emitter\|ios" || true)
  if [[ -n "$newest" ]]; then
    echo "$ROOT/ios/$newest"
    return 0
  fi

  echo ""
  return 1
}

IOS_LOG="$(resolve_ios_log || true)"

need() {
  local needle="$1"
  local fixed="${2:-0}"
  local cmd=(rg)

  if [[ "$fixed" == "1" ]]; then
    cmd+=( -F )
  fi

  local search_files=("$ANDROID_LOG")
  if [[ -n "$IOS_LOG" ]]; then
    search_files+=("$IOS_LOG")
  fi

  local match_file
  match_file="$(mktemp -t t390_verify_match.XXXXXX)"

  if "${cmd[@]}" -n "$needle" "${search_files[@]}" >"$match_file" 2>/dev/null; then
    echo "PASS: $needle"
    cat "$match_file"
    rm -f "$match_file"
    return 0
  else
    echo "FAIL: $needle"
    rm -f "$match_file"
    return 1
  fi
}

need_any() {
  local label="$1"
  shift

  local failed=()
  for needle in "$@"; do
    if need "$needle" 1; then
      echo "PASS: $label (matched: $needle)"
      return 0
    fi
    failed+=("$needle")
  done

  echo "FAIL: $label"
  printf '  missing alternative: %s\n' "${failed[@]}"
  return 1
}

if [[ ! -f "$ANDROID_LOG" ]]; then
  echo "ERROR: Android log not found: $ANDROID_LOG"
  exit 1
fi

echo "Verifying T390 capture signals for $RUN_TS"
echo "  root: $ROOT"

ok=0

need "BleSelfTest: HEARTBEAT" 1 || ok=1
need_any "GATT envelope surfaced to selftest" \
  "BleSelfTest: GATT_FETCH_RECEIVED" \
  "BleSelfTest: DISTINCT MESH MESSAGE kind=envelope" || ok=1
need "MobBeaconFetch: fetch_start" 1 || ok=1
need "\"event\":\"fetch_connect_result\"" 1 || ok=1
need "\"event\":\"fetch_service_discovery_result\"" 1 || ok=1
need "\"event\":\"fetch_response_received\"" 1 || ok=1

if [[ -f "$IOS_LOG" ]]; then
  need "MobMessageObserver: beacon_dispatched" 1 || ok=1
  need "MobMessageObserver: fetch_responder_served" 1 || ok=1
else
  echo "WARN: iOS log not found: $IOS_LOG"
fi

if [[ $ok -eq 0 ]]; then
  echo "RESULT: PASS (all required signals found)"
  exit 0
fi

echo "RESULT: FAIL (one or more required signals missing)"
exit 2
