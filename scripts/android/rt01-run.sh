#!/usr/bin/env bash
# rt01-run.sh — one-command RT-01 locked-delivery capture for two attached Android tablets.
#
# Prereq: BOTH devices on power (AC/USB powered: true) so `svc power stayon true`
# can hold the sender awake. Run with the devices physically in BLE range.
#
# Flow: stayon + Doze-whitelist -> launch both apps with RT-01 event logging ->
# confirm awake peering (sent>0 / peers>=1, ABORTS fast if not) -> sleep the
# receiver -> hold -> wake -> capture logcat -> mix meshx.mobile.rt01.analyze.
#
# Usage:
#   scripts/android/rt01-run.sh \
#     --sender 5200f354f4fb277f --receiver R52W90AW7EN \
#     [--run-id rt-01-<label>] [--hold-secs 900] [--peer-timeout 120]
set -euo pipefail

PKG=dev.meshx.mob
SENDER="5200f354f4fb277f"      # T390 default
RECEIVER="R52W90AW7EN"          # T577U default (the locked device)
RUN_ID="rt-01-$(date -u +%Y%m%dT%H%M%SZ)"
HOLD_SECS=900
PEER_TIMEOUT=120
SENDER_SUFFIX=t390
RECEIVER_SUFFIX=t577

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sender) SENDER="$2"; shift 2 ;;
    --receiver) RECEIVER="$2"; shift 2 ;;
    --run-id) RUN_ID="$2"; shift 2 ;;
    --hold-secs) HOLD_SECS="$2"; shift 2 ;;
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
heartbeat() { adb -s "$1" logcat -d 2>/dev/null | tr -d '\r' | grep "BleSelfTest: HEARTBEAT" | tail -1; }
hb_field() { sed -nE "s/.*\b$2=([0-9]+).*/\1/p" <<<"$1"; }

launch() {  # serial suffix send?
  adbq "$1" am force-stop "$PKG" || true
  sleep 1
  adb -s "$1" shell am start -n "$PKG/.MainActivity" \
    --ez meshx_rt_event_log true --es meshx_rt_run_id "$RUN_ID" \
    --ez meshx_ble_selftest true --ez meshx_ble_selftest_send "$3" \
    --es mob_node_suffix "$2" >/dev/null 2>&1
}

say "Power check"
for s in "$SENDER" "$RECEIVER"; do
  if powered "$s"; then echo "$s: powered OK"; else
    echo "WARNING: $s reports not powered — svc stayon will NOT hold the screen; peering may not sustain." >&2
  fi
done

say "stayon + Doze whitelist"
for s in "$SENDER" "$RECEIVER"; do
  adbq "$s" svc power stayon true || true
  adbq "$s" settings put system screen_off_timeout 1800000 || true
  adbq "$s" dumpsys deviceidle whitelist +$PKG || true
  adbq "$s" input keyevent KEYCODE_WAKEUP || true
done

say "Launch apps (sender=$SENDER send=true, receiver=$RECEIVER send=false)"
launch "$SENDER" "$SENDER_SUFFIX" true
launch "$RECEIVER" "$RECEIVER_SUFFIX" false

say "Awake peering check (timeout ${PEER_TIMEOUT}s) — aborts if no sent>0/peers>=1"
deadline=$(( $(date +%s) + PEER_TIMEOUT ))
peered=0
while [[ $(date +%s) -lt $deadline ]]; do
  sh=$(heartbeat "$SENDER"); rh=$(heartbeat "$RECEIVER")
  ssent=$(hb_field "$sh" sent); rpeers=$(hb_field "$rh" meshx_peers)
  echo "  sender sent=${ssent:-?}  receiver peers=${rpeers:-?}"
  if [[ "${ssent:-0}" -gt 0 && "${rpeers:-0}" -ge 1 ]]; then peered=1; break; fi
  sleep 10
done
if [[ $peered -ne 1 ]]; then
  echo "ABORT: peering not established (sent>0 & peers>=1) within ${PEER_TIMEOUT}s." >&2
  echo "Last sender HB: $(heartbeat "$SENDER")" >&2
  echo "Last receiver HB: $(heartbeat "$RECEIVER")" >&2
  exit 1
fi
echo "Peering confirmed."

say "Begin locked window — sleeping receiver $RECEIVER"
adb -s "$RECEIVER" logcat -c 2>/dev/null || true
adb -s "$RECEIVER" logcat -v time > "$LOG" 2>&1 &
LOGCAT_PID=$!
adbq "$RECEIVER" svc power stayon false || true   # allow it to sleep
sleep 1
adbq "$RECEIVER" input keyevent KEYCODE_SLEEP || adbq "$RECEIVER" input keyevent 26 || true
LOCK_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "locked_from=$LOCK_AT  holding ${HOLD_SECS}s..."

sleep "$HOLD_SECS"

say "Unlock receiver"
adbq "$RECEIVER" input keyevent KEYCODE_WAKEUP || true
adbq "$RECEIVER" wm dismiss-keyguard || true
UNLOCK_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sleep 12   # capture the post-unlock resume window
kill "$LOGCAT_PID" 2>/dev/null || true
echo "unlock_at=$UNLOCK_AT  log: $LOG"

say "Analyze (strict gate)"
cd "$ROOT"
mix meshx.mobile.rt01.analyze \
  --input "$LOG" \
  --locked-from "$LOCK_AT" \
  --unlock-at "$UNLOCK_AT" \
  --json \
  --out "$OUT_DIR/rt01-analysis.json"

echo
echo "=== VERDICT ==="
grep -oE '"status":"[a-z]+"|"receive_events_after_5m":[0-9]+|"receive_events_in_window":[0-9]+|"post_unlock_receive_events":[0-9]+' \
  "$OUT_DIR/rt01-analysis.json" || cat "$OUT_DIR/rt01-analysis.json"
echo
echo "Artifacts in: $OUT_DIR"
