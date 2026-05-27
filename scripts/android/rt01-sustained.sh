#!/usr/bin/env bash
# rt01-sustained.sh — RT-01 (B): sustained locked-delivery over a multi-minute hold.
#
# Model (from the proven path): the SENDER drives the deterministic instrumented
# test (MobBleNative direct advertise + MobFetchGatt responder, bypassing the
# flaky Elixir selftest), looped every --send-interval across the hold. The
# RECEIVER runs the REAL app locked (meshx_ble_selftest + fetch_on_beacon), so we
# genuinely test backgrounded receive. The analyzer then buckets locked-window
# deliveries (after_5m / 10m / 15m) and the strict gate decides pass.
#
# Prereq: both devices on power (so stayon holds the sender awake) and in BLE
# range. Battery service must report powered:true — if a prior harness froze it,
# run `adb -s <serial> shell dumpsys battery reset` first.
#
# Usage:
#   scripts/android/rt01-sustained.sh \
#     --sender 5200f354f4fb277f --receiver R52W90AW7EN \
#     [--run-id rt-01-sustained-001] [--hold-secs 1200] [--send-interval 75] \
#     [--peer-timeout 180]
set -euo pipefail
export LC_ALL=C LC_CTYPE=C

PKG=dev.meshx.mob
RUNNER="dev.meshx.mob.test/androidx.test.runner.AndroidJUnitRunner"
SEND_CLASS="dev.meshx.mob.ble.MXFullEnvelopeSmokeTest"
SENDER="5200f354f4fb277f"      # T390 default (instrumented sender)
RECEIVER="R52W90AW7EN"          # T577U default (locked real-app receiver)
RUN_ID="rt-01-sustained-$(date -u +%Y%m%dT%H%M%SZ)"
HOLD_SECS=1200                  # 20 min
SEND_INTERVAL=75                # one instrumented send burst per cadence
PEER_TIMEOUT=180
RECEIVER_SUFFIX=t577

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sender) SENDER="$2"; shift 2 ;;
    --receiver) RECEIVER="$2"; shift 2 ;;
    --run-id) RUN_ID="$2"; shift 2 ;;
    --hold-secs) HOLD_SECS="$2"; shift 2 ;;
    --send-interval) SEND_INTERVAL="$2"; shift 2 ;;
    --peer-timeout) PEER_TIMEOUT="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$ROOT/artifacts/local-ble/$RUN_ID"
LOG="$OUT_DIR/${RECEIVER}-logcat.log"
mkdir -p "$OUT_DIR"

say() { printf '\n=== %s ===\n' "$*"; }
adbq() { adb -s "$1" shell "${@:2}" 2>/dev/null | tr -d '\r'; }
powered() { adbq "$1" dumpsys battery | grep -qE "(AC|USB|Wireless) powered: true"; }

# Fire one deterministic instrumented send burst (~30s) on the sender.
send_burst() {
  adb -s "$SENDER" shell am instrument -w -e class "$SEND_CLASS" "$RUNNER" >/dev/null 2>&1 || true
}

# Has the receiver logged a locked-window delivery since capture started?
receiver_delivery_count() {
  grep -cE "mesh_message_beacon_received|mesh_message_received|fetch_response_received|GATT_FETCH_RECEIVED" "$LOG" 2>/dev/null || echo 0
}

dump_ble_diag() {  # serial
  local s="$1" f="$OUT_DIR/${1}-blediag.txt"
  {
    echo "## $s  $(date -u +%FT%TZ)"
    adbq "$s" dumpsys battery | grep -iE "powered|level|status"
    adbq "$s" dumpsys power | grep -oE "mWakefulness=[A-Za-z]+|Display Power: state=[A-Z]+"
    echo "BT on: $(adbq "$s" settings get global bluetooth_on)"
    adb -s "$s" logcat -d 2>/dev/null | tr -cd '[:print:]\n' \
      | grep -iE "advertis|startScan|scan result|beacon|received native event|HEARTBEAT|onStartFailure|permission deni" \
      | tail -40
  } > "$f" 2>&1
  echo "  diagnostics -> $f"
}

say "Power check"
for s in "$SENDER" "$RECEIVER"; do
  if powered "$s"; then echo "$s: powered OK"; else
    echo "WARNING: $s not powered — stayon won't hold; if battery is frozen run 'dumpsys battery reset'." >&2
  fi
done

say "Prep: stayon + Doze whitelist + wake"
for s in "$SENDER" "$RECEIVER"; do
  adbq "$s" svc power stayon true || true
  adbq "$s" settings put system screen_off_timeout 1800000 || true
  adbq "$s" dumpsys deviceidle whitelist +$PKG || true
  adbq "$s" input keyevent KEYCODE_WAKEUP || true
done

say "Launch receiver app (locked-receive path: selftest + fetch_on_beacon + rt log)"
adbq "$RECEIVER" am force-stop "$PKG" || true
sleep 1
adb -s "$RECEIVER" shell am start -n "$PKG/.MainActivity" \
  --ez meshx_rt_event_log true --es meshx_rt_run_id "$RUN_ID" \
  --ez meshx_ble_selftest true --ez meshx_ble_selftest_send false \
  --ez meshx_ble_fetch_on_beacon true --es mob_node_suffix "$RECEIVER_SUFFIX" >/dev/null 2>&1
sleep 20  # let the receiver BEAM + scanner come up

say "Awake confirm: looped sends until the receiver fetches one (timeout ${PEER_TIMEOUT}s)"
adb -s "$RECEIVER" logcat -c 2>/dev/null || true
adb -s "$RECEIVER" logcat -v time > "$LOG" 2>&1 &
LOGCAT_PID=$!
deadline=$(( $(date +%s) + PEER_TIMEOUT ))
peered=0
while [[ $(date +%s) -lt $deadline ]]; do
  send_burst
  got=$(receiver_delivery_count)
  echo "  receiver deliveries so far: $got"
  if [[ "$got" -ge 1 ]]; then peered=1; break; fi
done
if [[ $peered -ne 1 ]]; then
  echo "ABORT: receiver never fetched a sender envelope while awake within ${PEER_TIMEOUT}s." >&2
  kill "$LOGCAT_PID" 2>/dev/null || true
  say "Capturing BLE diagnostics"
  dump_ble_diag "$SENDER"; dump_ble_diag "$RECEIVER"
  exit 1
fi
echo "Awake delivery confirmed — proceeding to locked hold."

say "Lock receiver $RECEIVER and begin sustained sends every ${SEND_INTERVAL}s for ${HOLD_SECS}s"
adbq "$RECEIVER" svc power stayon false || true
sleep 1
adbq "$RECEIVER" input keyevent KEYCODE_SLEEP || adbq "$RECEIVER" input keyevent 26 || true
LOCK_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "locked_from=$LOCK_AT"

end=$(( $(date +%s) + HOLD_SECS ))
burst=0
while [[ $(date +%s) -lt $end ]]; do
  send_burst        # ~30s blocking instrumented advertise/responder window
  burst=$((burst+1))
  printf '  burst %d  (t+%ds)  receiver deliveries=%s\n' "$burst" "$(( $(date +%s) - $(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$LOCK_AT" +%s) ))" "$(receiver_delivery_count)"
  remaining=$(( end - $(date +%s) ))
  [[ $remaining -le 0 ]] && break
  sleep "$(( SEND_INTERVAL - 30 < 5 ? 5 : SEND_INTERVAL - 30 ))"
done

say "Unlock receiver"
adbq "$RECEIVER" input keyevent KEYCODE_WAKEUP || true
adbq "$RECEIVER" wm dismiss-keyguard || true
UNLOCK_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sleep 12
kill "$LOGCAT_PID" 2>/dev/null || true
echo "unlock_at=$UNLOCK_AT  bursts=$burst  log=$LOG"

say "Analyze (strict gate)"
cd "$ROOT"
mix meshx.mobile.rt01.analyze \
  --input "$LOG" --locked-from "$LOCK_AT" --unlock-at "$UNLOCK_AT" \
  --json --out "$OUT_DIR/rt01-analysis.json" || \
  echo "NOTE: mix analyze failed/hung — analyze $LOG manually."

echo
echo "=== VERDICT ==="
grep -oE '"status":"[a-z]+"|"receive_events_in_window":[0-9]+|"receive_events_after_60s":[0-9]+|"receive_events_after_5m":[0-9]+|"unique_message_hashes_in_window":[0-9]+' \
  "$OUT_DIR/rt01-analysis.json" 2>/dev/null || echo "(no analysis json — see $LOG)"
echo "Artifacts: $OUT_DIR"
