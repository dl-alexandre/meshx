#!/usr/bin/env bash
#
# launch_mob_ble_default_path.sh
#
# Template / helper for launching the recommended `mob_ble` default path
# (post Phase 2/3) on Android (and iOS parity via AppDelegate forwarding).
# For fresh evidence captures under the canonical Mob.Ble path.
#
# This is the natural successor to the legacy meshx_ble_* launch recipes
# in CONTRIBUTING.md and docs/ble-t390-validation-notes.md.
# iOS: equivalent MOB_BLE_* may be passed via launch options / devicectl env.
#
# Usage examples:
#   ./scripts/launch_mob_ble_default_path.sh --serial 5200f354f4fb277f --selftest --local-name t390-cutover
#   ./scripts/launch_mob_ble_default_path.sh --serial R52W90AW7EN --selftest --fetch-on-beacon
#   ./scripts/launch_mob_ble_default_path.sh --serial ... --legacy   # forces MOB_BLE_TRANSPORT=0 for comparison
#
# Evidence collection: always prefix runs with a dated artifact dir and
# capture the exact launch command + `mix.lock` + `git rev-parse HEAD`
# into a cutover-manifest.txt (see the Phase 3 cutover announcement draft).
#
# Requires: adb in PATH, device authorized.
set -euo pipefail

SERIAL=""
SELFTEST=0
LOCAL_NAME="mob-ble-cutover-val"
LEGACY=0
FETCH_ON_BEACON=0
DURATION_MINUTES=0
EXTRA_EZ=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --serial) SERIAL="$2"; shift 2 ;;
    --selftest) SELFTEST=1; shift ;;
    --local-name) LOCAL_NAME="$2"; shift 2 ;;
    --legacy) LEGACY=1; shift ;;
    --fetch-on-beacon) FETCH_ON_BEACON=1; shift ;;
    --ez) EXTRA_EZ+=("$2"); shift 2 ;;
    --duration) DURATION_MINUTES="$2"; shift 2 ;;
    -h|--help)
      echo "See header comments in this script."
      exit 0
      ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -z "$SERIAL" ]]; then
  echo "ERROR: --serial <adb-serial> is required"
  exit 1
fi

# Awake preflight (critical for T390/API 28)
adb -s "$SERIAL" shell input keyevent WAKEUP || true
adb -s "$SERIAL" shell svc power stayon true || true

PKG="dev.meshx.mob"
ACT=".MainActivity"
INTENT="-n ${PKG}/${ACT}"

CMDS=( adb -s "$SERIAL" shell am start $INTENT )

if (( SELFTEST )); then
  CMDS+=( --ez mob_ble_selftest true )
fi
CMDS+=( --es mob_ble_local_name "$LOCAL_NAME" )

if (( FETCH_ON_BEACON )); then
  CMDS+=( --ez mob_ble_fetch_on_beacon true )  # preferred (MOB_BLE_* parity); Android also accepts legacy meshx_ alias
  # CMDS+=( --ez meshx_ble_fetch_on_beacon true )  # legacy alias still supported for transition
fi

if (( LEGACY )); then
  CMDS+=( --ez mob_ble_transport_0 true )
fi

if (( ${#EXTRA_EZ[@]} > 0 )); then
  for ez in "${EXTRA_EZ[@]}"; do
    CMDS+=( --ez "$ez" )
  done
fi

echo "Launching (new default mob_ble path unless --legacy):"
echo "  ${CMDS[*]}"
"${CMDS[@]}"

if (( DURATION_MINUTES > 0 )); then
  echo "Test running for ${DURATION_MINUTES} minutes (screen off + conditions)..."
  sleep $(( DURATION_MINUTES * 60 ))
  echo "Duration complete."
fi

echo
echo "Post-launch tips for evidence:"
echo "  adb -s $SERIAL logcat -d | grep -E 'MOB_BLE|MobBle|ble_peer|meshx_transport' > ${SERIAL}-launch.log"
echo "  adb -s $SERIAL shell 'pid=\$(pidof ${PKG}); cat /proc/\$pid/environ | tr \"\\0\" \"\\n\" | grep -E \"MOB_BLE|MESHX_BLE\"' "
echo
echo "Store this run under artifacts/local-ble/2026-05-19-mob-ble-cutover-XXX/"
echo "Include: this script invocation, adb devices, the log, summary.json from any verifier."

# Evidence collection template (copy into summary.md / cutover-manifest.json sidecar)
cat << 'EVIDENCE_TEMPLATE'
mob_ble_path: default (MOB_BLE_TRANSPORT unset or !=0)
mob_ble_selftest: 1
bridge: Mob.Ble.MobileBridge (via Mob.Ble.bridge_module())
event_source: Mob.Ble.Internal.BridgeProtocol + native emitters (Kotlin/Swift)
mob_ble_version: 0.1.0 (or published tar checksum)
meshx_transport_ble_version: (from mix.lock)
legacy_opt_out_used: false
capture_date: $(date -Iseconds)
device_pair: <model1> <serial1> <-> <model2> <serial2>
launch_cmd: (paste the adb / script line above)
notes: "Post-Phase-3 cutover validation of canonical mob_ble default path (MOB_BLE_* forwarding active)"
EVIDENCE_TEMPLATE
echo "(Above template + mix.lock snapshot + git rev + adb-*.txt + host-*.txt go into the artifact dir.)"
