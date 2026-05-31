#!/usr/bin/env bash
# capture-hybrid-run.sh
# Lightweight Android-side capture helper for BLE validation runs.
# Canonical source: scripts/capture-hybrid-run.sh
# Copy into dated artifact dir (e.g. artifacts/local-ble/2026-05-19-recapture-7-t390-gatt/)
# before running so outputs land in the right structured layout.
#
# Usage (run from this directory or with full path):
#   ./capture-hybrid-run.sh --serial 5200f354f4fb277f [--run-ts 20260519-093000] [--selftest]
#
# Defaults to instrumented hybrid receive test (for carrier/negative evidence).
# With --selftest: launches main-app BleSelfTest + fetch-on-beacon for
# positive MB-legacy + GATT evidence on T390 (Android 9). iOS side: use
#   xcrun devicectl ... dev.mob.node.harness -- --mob-auto-beacon
# (MB legacy cue only; triggers Android GATT fetch).
#
# The log filter now covers both paths + fetch visibility:
#   BleSelfTest, MobBeaconFetch, MobBleFetch, BleScanner, etc.
#
# Success for T390 GATT:
#   - BleSelfTest: HEARTBEAT ... devices>0 beacon_callbacks>0 ...
#   - BleSelfTest: GATT_FETCH_RECEIVED ...
#   - MobBeaconFetch: fetch_start ...
#   - MobBleFetch JSON events for connect/read/complete (visible GATT activity)
#   - Matching messageId in iOS MB cue + Android envelope
#
# Archive under recapture-N with evidence/*.md using prior summaries as template.
set -euo pipefail

SERIAL=""
RUN_TS=""
HELP=0
SELFTEST=0
DURATION=120
SELFTEST_SEND=0
NODE_SUFFIX="t390"

usage() {
  cat <<'EOF'
capture-hybrid-run.sh --serial <adb-serial> [--run-ts <YYYYMMDD-HHMMSS>] [--selftest] [--duration <sec>] [--selftest-send true|false] [--node-suffix <suffix>]

  --serial     Android device serial (required). T390 example: 5200f354f4fb277f
  --run-ts     Timestamp prefix. Default: current time. Match with iOS capture.
  --selftest   Use main-app BleSelfTest + fetch-on-beacon (for positive MB+GATT on T390).
               Default: run IOSHybridDirectMxReceiveTest (hybrid instrumented).
  --duration   Seconds to capture when --selftest (selftest keeps running). Default: 120.
  --selftest-send true|false
               Whether selftest should also broadcast Android messages. Default: false
               for focused receive-side MB+GATT evidence, to keep logs clean.
  --node-suffix
               MOB_NODE_SUFFIX for this Android app instance. Default: t390.
  -h|--help    This help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --serial) SERIAL="${2:?--serial requires value}"; shift 2 ;;
    --run-ts) RUN_TS="${2:?--run-ts requires value}"; shift 2 ;;
    --selftest) SELFTEST=1; shift ;;
    --duration) DURATION="${2:?--duration requires value}"; shift 2 ;;
    --node-suffix) NODE_SUFFIX="${2:?--node-suffix requires value}"; shift 2 ;;
    --selftest-send)
      case "${2:?--selftest-send requires true or false}" in
        true|1|yes) SELFTEST_SEND=1 ;;
        false|0|no) SELFTEST_SEND=0 ;;
        *) echo "Invalid --selftest-send: $2 (expected true or false)"; usage; exit 1 ;;
      esac
      shift 2
      ;;
    -h|--help) HELP=1; shift ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

if [[ $HELP -eq 1 || -z "$SERIAL" ]]; then
  usage
  [[ $HELP -eq 1 ]] && exit 0 || exit 1
fi

if [[ -z "$RUN_TS" ]]; then
  RUN_TS=$(date +%Y%m%d-%H%M%S)
fi

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$BASE_DIR/android"
TEST_DIR="$BASE_DIR/test"
IOS_DIR="$BASE_DIR/ios"
EVIDENCE_DIR="$BASE_DIR/evidence"

mkdir -p "$ANDROID_DIR" "$TEST_DIR" "$IOS_DIR" "$EVIDENCE_DIR"

echo "=== BLE capture run ${RUN_TS} on ${SERIAL} (selftest=${SELFTEST}, node_suffix=${NODE_SUFFIX}) ==="

# 1. Device snapshot
{
  adb devices -l
  echo "=== props ==="
  adb -s "$SERIAL" shell getprop ro.product.model
  adb -s "$SERIAL" shell getprop ro.build.fingerprint
  adb -s "$SERIAL" shell getprop ro.build.version.release
} > "$ANDROID_DIR/${RUN_TS}-adb-devices.txt" 2>&1 || true

# 2. Clear logs (clean evidence)
adb -s "$SERIAL" logcat -c || true

# 3. Background filtered logcat — tags cover hybrid tests + selftest + GATT fetch path.
#    Elixir/BEAMout are needed to consistently capture `BleSelfTest:*` logs from
#    E2E selftest mode.
adb -s "$SERIAL" logcat \
  -s HybridExperiment:I \
  -s IOSHybridDirectMxReceiveTest:I \
  -s BleSelfTest:I \
  -s Elixir:I \
  -s BEAMout:I \
  -s MobBeaconFetch:I \
  -s MobBleFetch:I \
  -s BleScanner:I \
  -s MobBleScanRaw:I \
  -s MobBle:I \
  -s MobBleNative:I \
  '*:S' \
  > "$ANDROID_DIR/${RUN_TS}-logcat.log" 2>&1 &
LOGCAT_PID=$!
echo "logcat pid=$LOGCAT_PID → $ANDROID_DIR/${RUN_TS}-logcat.log"

cleanup() {
  if [[ -n "${LOGCAT_PID:-}" ]]; then
    kill "$LOGCAT_PID" 2>/dev/null || true
    wait "$LOGCAT_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# 4. Launch the requested path
if [[ $SELFTEST -eq 1 ]]; then
  echo ""
  echo "=== SELFTEST + GATT mode for positive MB+GATT evidence ==="
  echo "On iPhone (separate terminal):"
  echo '  UDID=1780F216-CB5C-560B-A86F-85D31F79ADEF'
  echo '  xcrun devicectl device process launch --device $UDID --terminate-existing --console \'
  echo '    dev.mob.node.harness -- --mob-auto-beacon'
  echo "Optional iOS log target for this run: $IOS_DIR/${RUN_TS}-harness.log"
  echo ""
  echo "Starting main app BleSelfTest with fetch-on-beacon (will run for ${DURATION}s)..."
  adb -s "$SERIAL" shell am force-stop dev.mob.mob || true
  adb -s "$SERIAL" shell am start -n dev.mob.mob/.MainActivity \
    --ez mob_ble_selftest true \
    --ez mob_ble_selftest_send "$([[ $SELFTEST_SEND -eq 1 ]] && echo true || echo false)" \
    --ez mob_ble_fetch_on_beacon true \
    --es mob_node_suffix "$NODE_SUFFIX" \
    -S \
    --activity-clear-top \
    > "$ANDROID_DIR/${RUN_TS}-launch.log" 2>&1 || true

  echo "Capture running. Waiting ${DURATION}s (Ctrl-C to abort early)..."
  sleep "$DURATION" || true
else
  echo "Starting instrumented test (blocks until completion)..."
  adb -s "$SERIAL" shell am instrument -w \
    -e class dev.mob.mob.ble.IOSHybridDirectMxReceiveTest \
    dev.mob.mob.test/androidx.test.runner.AndroidJUnitRunner \
    > "$ANDROID_DIR/${RUN_TS}-instrumentation.log" 2>&1 || true
fi

# 5. Stop logcat
cleanup
trap - EXIT INT TERM

# 6. Promote artifacts
if [[ -f "$ANDROID_DIR/${RUN_TS}-instrumentation.log" ]]; then
  cp "$ANDROID_DIR/${RUN_TS}-instrumentation.log" "$TEST_DIR/${RUN_TS}-test-results.txt" || true
fi

echo ""
echo "=== Capture finished for run ${RUN_TS} ==="
echo "Artifacts under android/ and test/."
echo "For selftest runs: inspect logcat for BleSelfTest: HEARTBEAT + GATT_FETCH_RECEIVED + MobBeaconFetch."
echo "Correlate messageId with iOS MB beacon logs."
echo "Write evidence/${RUN_TS}-summary.md (template from prior recapture-*/evidence/)"
