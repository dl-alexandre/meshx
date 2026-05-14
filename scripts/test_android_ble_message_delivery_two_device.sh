#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES="$ROOT/scripts/fixtures/android_ble_message_delivery"
TMP_DIR="$(mktemp -d)"
EXTRA_CLEANUP_DIRS=()

cleanup() {
  rm -rf "$TMP_DIR"
  if [[ "${#EXTRA_CLEANUP_DIRS[@]}" -gt 0 ]]; then
    for dir in "${EXTRA_CLEANUP_DIRS[@]}"; do
      case "$dir" in
        /tmp/meshx-android-m26-*) rm -rf "$dir" ;;
      esac
    done
  fi
}
trap cleanup EXIT

SCRIPT="$ROOT/scripts/android_ble_message_delivery_two_device.sh"
AUDIT="$ROOT/scripts/audit_android_ble_message_delivery_completion.sh"

assert_m26_completion_schema() {
  local summary_json="$1"
  ruby -rjson -e '
    expected = %w[
      sender_attempt_dispatched
      advertising_set_started
      sender_attempt_matches_advertising_set
      sender_payload_size_matches
      sender_logcat_captured
      observer_logcat_captured
      observer_scan_started
      received_message_logged
      observer_m14_consistent
      observer_meshx_transport_metadata
      payload_match
      sender_and_observer_distinct
      sender_and_observer_logs_distinct
      sender_device_metadata_complete
      observer_device_metadata_complete
      require_scan_start
      android_logcat_provenance
      not_repo_fixture_log_pair
    ].sort
    summary = JSON.parse(File.read(ARGV.fetch(0)))
    actual = summary.fetch("m26_completion_validation").keys.sort
    missing = expected - actual
    abort("missing M26 completion schema keys in #{ARGV.fetch(0)}: #{missing}") unless missing.empty?
  ' "$summary_json"
}

"$SCRIPT" --help > "$TMP_DIR/help.out"
grep -q "logcat, inventory, summary.json, and summary.md artifacts" "$TMP_DIR/help.out"
grep -q "m26_android_to_android_complete" "$TMP_DIR/help.out"
grep -q "m26_completion_blockers" "$TMP_DIR/help.out"
grep -q "m26_completion_provenance" "$TMP_DIR/help.out"
grep -q "preflight_adb_mdns_service_count" "$TMP_DIR/help.out"
grep -q "preflight_host_usb_android_candidate_count" "$TMP_DIR/help.out"
grep -q -- "--preflight-only" "$TMP_DIR/help.out"
grep -q -- "--wait-for-devices" "$TMP_DIR/help.out"
grep -q -- "--observer-ready-timeout" "$TMP_DIR/help.out"
grep -q -- "--sender-device-json" "$TMP_DIR/help.out"
grep -q -- "--observer-device-json" "$TMP_DIR/help.out"
grep -q "audit_android_ble_message_delivery_completion.sh" "$TMP_DIR/help.out"

"$AUDIT" --help > "$TMP_DIR/audit-help.out"
grep -q "m26_android_to_android_complete=true" "$TMP_DIR/audit-help.out"
grep -q "existing non-fixture sender/observer" "$TMP_DIR/audit-help.out"
grep -q "distinct from each other" "$TMP_DIR/audit-help.out"
grep -q "self-identifying" "$TMP_DIR/audit-help.out"
grep -q "existing summary_markdown ledger" "$TMP_DIR/audit-help.out"
grep -q "timestamp/pid/tid/tag" "$TMP_DIR/audit-help.out"
grep -q "revalidated with the" "$TMP_DIR/audit-help.out"
grep -q "two-device verifier" "$TMP_DIR/audit-help.out"
grep -q "model/API/BLE" "$TMP_DIR/audit-help.out"
grep -q "metadata for both Android devices" "$TMP_DIR/audit-help.out"
grep -q "parsed summary object" "$TMP_DIR/audit-help.out"
grep -q "audited" "$TMP_DIR/audit-help.out"
grep -q "summary path" "$TMP_DIR/audit-help.out"
grep -q "recorded summary_markdown path" "$TMP_DIR/audit-help.out"
grep -q "inventory log paths" "$TMP_DIR/audit-help.out"
grep -q "adb/mDNS/USB" "$TMP_DIR/audit-help.out"
grep -q "adb_devices_log" "$TMP_DIR/audit-help.out"
grep -q "adb_mdns_log" "$TMP_DIR/audit-help.out"
grep -q "host_usb_log" "$TMP_DIR/audit-help.out"
grep -q "adb_ready_device_count" "$TMP_DIR/audit-help.out"
grep -q "adb_nonready_device_count" "$TMP_DIR/audit-help.out"
grep -q "adb_mdns_service_count" "$TMP_DIR/audit-help.out"
grep -q "host_usb_android_candidate_count" "$TMP_DIR/audit-help.out"

if "$AUDIT" "$TMP_DIR/not-found-summary.json" > "$TMP_DIR/audit-not-found-summary.out"; then
  echo "expected missing summary completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-not-found-summary.out"
grep -q "summary not found: $TMP_DIR/not-found-summary.json" "$TMP_DIR/audit-not-found-summary.out"
grep -q "summary=$TMP_DIR/not-found-summary.json" "$TMP_DIR/audit-not-found-summary.out"

printf '%s\n' '{not-json' > "$TMP_DIR/invalid-summary.json"

if "$AUDIT" "$TMP_DIR/invalid-summary.json" > "$TMP_DIR/audit-invalid-summary.out"; then
  echo "expected invalid JSON summary completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-invalid-summary.out"
grep -q "summary is not valid JSON" "$TMP_DIR/audit-invalid-summary.out"
grep -q "summary=$TMP_DIR/invalid-summary.json" "$TMP_DIR/audit-invalid-summary.out"

printf '%s\n' '[]' > "$TMP_DIR/nonobject-summary.json"

if "$AUDIT" "$TMP_DIR/nonobject-summary.json" > "$TMP_DIR/audit-nonobject-summary.out"; then
  echo "expected non-object JSON summary completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-nonobject-summary.out"
grep -q "summary JSON root is not an object" "$TMP_DIR/audit-nonobject-summary.out"
grep -q "summary=$TMP_DIR/nonobject-summary.json" "$TMP_DIR/audit-nonobject-summary.out"

if "$SCRIPT" \
  --verify-only \
  --preflight-only \
  --sender-log "$FIXTURES/sender.log" \
  --observer-log "$FIXTURES/observer.log" \
  > "$TMP_DIR/mutually-exclusive.out" 2> "$TMP_DIR/mutually-exclusive.err"; then
  echo "expected --verify-only and --preflight-only to be mutually exclusive" >&2
  exit 1
fi

grep -q -- "--verify-only and --preflight-only are mutually exclusive" "$TMP_DIR/mutually-exclusive.err"

if "$SCRIPT" \
  --wait-for-devices soon \
  > "$TMP_DIR/bad-wait.out" 2> "$TMP_DIR/bad-wait.err"; then
  echo "expected nonnumeric --wait-for-devices to fail" >&2
  exit 1
fi

grep -q -- "--wait-for-devices must be a non-negative integer" "$TMP_DIR/bad-wait.err"

if "$SCRIPT" \
  --observer-ready-timeout soon \
  > "$TMP_DIR/bad-observer-ready.out" 2> "$TMP_DIR/bad-observer-ready.err"; then
  echo "expected nonnumeric --observer-ready-timeout to fail" >&2
  exit 1
fi

grep -q -- "--observer-ready-timeout must be a non-negative integer" "$TMP_DIR/bad-observer-ready.err"

cp "$FIXTURES/sender.log" "$TMP_DIR/captured-sender.log"
cp "$FIXTURES/observer.log" "$TMP_DIR/captured-observer.log"
captured_sender_serial="R52W90AW7EN"
captured_observer_serial="R99M26OBSERVER"
sender_device_json='{"serial":"R52W90AW7EN","model":"Sender","android_release":"14","android_sdk":"34","bluetooth_le_feature":"true"}'
observer_device_json='{"serial":"R99M26OBSERVER","model":"Observer","android_release":"13","android_sdk":"33","bluetooth_le_feature":"true"}'
ruby -rjson -e '
  path = ARGV.fetch(0)
  lines = File.readlines(path).map do |line|
    match = line.match(/\{.*\}/)
    next line unless match

    event = JSON.parse(match[0])
    event["outcome_at_ms"] += 1 if event["event"] == "attempt_outcome"
    line.sub(/\{.*\}/, JSON.generate(event))
  end
  File.write(path, lines.join)
' "$TMP_DIR/captured-sender.log"
ruby -rjson -e '
  path = ARGV.fetch(0)
  lines = File.readlines(path).map do |line|
    match = line.match(/\{.*\}/)
    next line unless match

    event = JSON.parse(match[0])
    if event["event"] == "received_message"
      event["received_at"] += 1
      event["received_device_id"] = "02:00:00:00:26:02"
      event["raw_transport_metadata"]["received_device_id"] = "02:00:00:00:26:02"
    end
    line.sub(/\{.*\}/, JSON.generate(event))
  end
  File.write(path, lines.join)
' "$TMP_DIR/captured-observer.log"

"$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender "$captured_sender_serial" \
  --observer "$captured_observer_serial" \
  --sender-log "$TMP_DIR/captured-sender.log" \
  --observer-log "$TMP_DIR/captured-observer.log" \
  --summary-json "$TMP_DIR/summary.json" \
  --sender-device-json "$sender_device_json" \
  --observer-device-json "$observer_device_json" \
  > "$TMP_DIR/pass.out"

grep -q "payload_match=true" "$TMP_DIR/pass.out"
grep -q "m26_android_to_android_complete=true" "$TMP_DIR/pass.out"
grep -q "m26_completion_blockers=$" "$TMP_DIR/pass.out"

"$AUDIT" "$TMP_DIR/summary.json" > "$TMP_DIR/audit-pass.out"
grep -q "m26_complete=true" "$TMP_DIR/audit-pass.out"
grep -q "mode=verify_only" "$TMP_DIR/audit-pass.out"
assert_m26_completion_schema "$TMP_DIR/summary.json"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["summary_json"] = ARGV.fetch(1)
  summary["m26_completion_blockers"] = ["synthetic blocker"]
  File.write(ARGV.fetch(1), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/summary.json" "$TMP_DIR/nonempty-blockers-summary.json"

if "$AUDIT" "$TMP_DIR/nonempty-blockers-summary.json" > "$TMP_DIR/audit-nonempty-blockers.out"; then
  echo "expected nonempty blockers completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-nonempty-blockers.out"
grep -q "m26_completion_blockers is not an empty array" "$TMP_DIR/audit-nonempty-blockers.out"
grep -q "blockers=synthetic blocker" "$TMP_DIR/audit-nonempty-blockers.out"
grep -q "summary=$TMP_DIR/nonempty-blockers-summary.json" "$TMP_DIR/audit-nonempty-blockers.out"

cp "$TMP_DIR/summary.json" "$TMP_DIR/copied-summary.json"

if "$AUDIT" "$TMP_DIR/copied-summary.json" > "$TMP_DIR/audit-copied-summary.out"; then
  echo "expected copied completion summary audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-copied-summary.out"
grep -q "summary_json does not match audited path" "$TMP_DIR/audit-copied-summary.out"
grep -q "summary=$TMP_DIR/copied-summary.json" "$TMP_DIR/audit-copied-summary.out"
grep -q "summary_markdown=$TMP_DIR/summary.md" "$TMP_DIR/audit-copied-summary.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary.delete("summary_json")
  File.write(ARGV.fetch(1), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/summary.json" "$TMP_DIR/missing-summary-json-summary.json"

if "$AUDIT" "$TMP_DIR/missing-summary-json-summary.json" > "$TMP_DIR/audit-missing-summary-json.out"; then
  echo "expected missing summary_json completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-missing-summary-json.out"
grep -q "summary_json is missing" "$TMP_DIR/audit-missing-summary-json.out"
grep -q "summary=$TMP_DIR/missing-summary-json-summary.json" "$TMP_DIR/audit-missing-summary-json.out"
grep -q "summary_markdown=$TMP_DIR/summary.md" "$TMP_DIR/audit-missing-summary-json.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["summary_json"] = ARGV.fetch(1)
  summary.delete("summary_markdown")
  File.write(ARGV.fetch(1), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/summary.json" "$TMP_DIR/missing-summary-markdown-summary.json"

if "$AUDIT" "$TMP_DIR/missing-summary-markdown-summary.json" > "$TMP_DIR/audit-missing-summary-markdown.out"; then
  echo "expected missing summary_markdown completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-missing-summary-markdown.out"
grep -q "summary_markdown is missing" "$TMP_DIR/audit-missing-summary-markdown.out"
grep -q "summary=$TMP_DIR/missing-summary-markdown-summary.json" "$TMP_DIR/audit-missing-summary-markdown.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["summary_json"] = ARGV.fetch(1)
  summary["summary_markdown"] = File.join(File.dirname(ARGV.fetch(1)), "missing-summary.md")
  File.write(ARGV.fetch(1), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/summary.json" "$TMP_DIR/nonexistent-summary-markdown-summary.json"

if "$AUDIT" "$TMP_DIR/nonexistent-summary-markdown-summary.json" > "$TMP_DIR/audit-nonexistent-summary-markdown.out"; then
  echo "expected nonexistent summary_markdown completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-nonexistent-summary-markdown.out"
grep -q "summary_markdown does not exist" "$TMP_DIR/audit-nonexistent-summary-markdown.out"
grep -q "summary=$TMP_DIR/nonexistent-summary-markdown-summary.json" "$TMP_DIR/audit-nonexistent-summary-markdown.out"
grep -q "summary_markdown=$TMP_DIR/missing-summary.md" "$TMP_DIR/audit-nonexistent-summary-markdown.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["summary_json"] = ARGV.fetch(1)
  summary["m26_completion_provenance"]["live_run"] = true
  File.write(ARGV.fetch(1), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/summary.json" "$TMP_DIR/bad-verify-live-run-summary.json"

if "$AUDIT" "$TMP_DIR/bad-verify-live-run-summary.json" > "$TMP_DIR/audit-bad-verify-live-run.out"; then
  echo "expected contradictory verify-only live_run completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-bad-verify-live-run.out"
grep -q "verify_only provenance live_run is not false" "$TMP_DIR/audit-bad-verify-live-run.out"
grep -q "summary=$TMP_DIR/bad-verify-live-run-summary.json" "$TMP_DIR/audit-bad-verify-live-run.out"
grep -q "summary_markdown=$TMP_DIR/summary.md" "$TMP_DIR/audit-bad-verify-live-run.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["summary_json"] = ARGV.fetch(1)
  summary["m26_completion_provenance"]["verify_only"] = false
  File.write(ARGV.fetch(1), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/summary.json" "$TMP_DIR/bad-verify-flag-summary.json"

if "$AUDIT" "$TMP_DIR/bad-verify-flag-summary.json" > "$TMP_DIR/audit-bad-verify-flag.out"; then
  echo "expected contradictory verify_only flag completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-bad-verify-flag.out"
grep -q "verify_only provenance verify_only is not true" "$TMP_DIR/audit-bad-verify-flag.out"
grep -q "summary=$TMP_DIR/bad-verify-flag-summary.json" "$TMP_DIR/audit-bad-verify-flag.out"
grep -q "summary_markdown=$TMP_DIR/summary.md" "$TMP_DIR/audit-bad-verify-flag.out"

ruby -e '
  File.write(ARGV.fetch(2), File.read(ARGV.fetch(0)) + File.read(ARGV.fetch(1)))
' "$TMP_DIR/captured-sender.log" "$TMP_DIR/captured-observer.log" "$TMP_DIR/combined-role.log"

"$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender "$captured_sender_serial" \
  --observer "$captured_observer_serial" \
  --sender-log "$TMP_DIR/combined-role.log" \
  --observer-log "$TMP_DIR/combined-role.log" \
  --summary-json "$TMP_DIR/same-log-summary.json" \
  --sender-device-json "$sender_device_json" \
  --observer-device-json "$observer_device_json" \
  > "$TMP_DIR/same-log.out"

grep -q "payload_match=true" "$TMP_DIR/same-log.out"
grep -q "m26_android_to_android_complete=false" "$TMP_DIR/same-log.out"
grep -q "m26_completion_blockers=.*sender_and_observer_logs_distinct" "$TMP_DIR/same-log.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  completion = summary.fetch("m26_completion_validation")
  abort("expected same-log distinct check false") unless completion.fetch("sender_and_observer_logs_distinct") == false
' "$TMP_DIR/same-log-summary.json"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["sender_log"] = ARGV.fetch(1)
  summary["observer_log"] = ARGV.fetch(1)
  summary["summary_json"] = ARGV.fetch(2)
  File.write(ARGV.fetch(2), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/summary.json" "$TMP_DIR/combined-role.log" "$TMP_DIR/forged-same-log-summary.json"

if "$AUDIT" "$TMP_DIR/forged-same-log-summary.json" > "$TMP_DIR/audit-forged-same-log.out"; then
  echo "expected forged same-log completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-forged-same-log.out"
grep -q "sender_log and observer_log must be different files" "$TMP_DIR/audit-forged-same-log.out"

ln -s "$TMP_DIR/combined-role.log" "$TMP_DIR/combined-role-link.log"

"$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender "$captured_sender_serial" \
  --observer "$captured_observer_serial" \
  --sender-log "$TMP_DIR/combined-role.log" \
  --observer-log "$TMP_DIR/combined-role-link.log" \
  --summary-json "$TMP_DIR/symlink-same-log-summary.json" \
  --sender-device-json "$sender_device_json" \
  --observer-device-json "$observer_device_json" \
  > "$TMP_DIR/symlink-same-log.out"

grep -q "payload_match=true" "$TMP_DIR/symlink-same-log.out"
grep -q "m26_android_to_android_complete=false" "$TMP_DIR/symlink-same-log.out"
grep -q "m26_completion_blockers=.*sender_and_observer_logs_distinct" "$TMP_DIR/symlink-same-log.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  completion = summary.fetch("m26_completion_validation")
  abort("expected symlink same-log distinct check false") unless completion.fetch("sender_and_observer_logs_distinct") == false
' "$TMP_DIR/symlink-same-log-summary.json"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["sender_log"] = ARGV.fetch(1)
  summary["observer_log"] = ARGV.fetch(2)
  summary["summary_json"] = ARGV.fetch(3)
  File.write(ARGV.fetch(3), JSON.pretty_generate(summary) + "\n")
' \
  "$TMP_DIR/summary.json" \
  "$TMP_DIR/combined-role.log" \
  "$TMP_DIR/combined-role-link.log" \
  "$TMP_DIR/forged-symlink-same-log-summary.json"

if "$AUDIT" "$TMP_DIR/forged-symlink-same-log-summary.json" > "$TMP_DIR/audit-forged-symlink-same-log.out"; then
  echo "expected forged symlink same-log completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-forged-symlink-same-log.out"
grep -q "sender_log and observer_log must be different files" "$TMP_DIR/audit-forged-symlink-same-log.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary.fetch("m26_completion_validation").delete("sender_logcat_captured")
  summary["summary_json"] = ARGV.fetch(1)
  File.write(ARGV.fetch(1), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/summary.json" "$TMP_DIR/missing-validation-check-summary.json"

if "$AUDIT" "$TMP_DIR/missing-validation-check-summary.json" > "$TMP_DIR/audit-missing-validation-check.out"; then
  echo "expected missing validation-check completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-missing-validation-check.out"
grep -q "m26_completion_validation is missing required checks: sender_logcat_captured" "$TMP_DIR/audit-missing-validation-check.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["sender_logcat_capture_failed"] = true
  summary["summary_json"] = ARGV.fetch(1)
  File.write(ARGV.fetch(1), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/summary.json" "$TMP_DIR/inconsistent-logcat-capture-summary.json"

if "$AUDIT" "$TMP_DIR/inconsistent-logcat-capture-summary.json" > "$TMP_DIR/audit-inconsistent-logcat-capture.out"; then
  echo "expected inconsistent logcat-capture completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-inconsistent-logcat-capture.out"
grep -q "sender_logcat_capture_failed is not false" "$TMP_DIR/audit-inconsistent-logcat-capture.out"

ruby -rjson -e '
  ARGV.each do |path|
    lines = File.readlines(path).filter_map do |line|
      match = line.match(/\{.*\}/)
      next unless match

      "MeshxMessageObserverCLI: #{JSON.generate(JSON.parse(match[0]))}\n"
    end
    File.write(path, lines.join)
  end
' "$TMP_DIR/captured-sender.log" "$TMP_DIR/captured-observer.log"

"$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender "$captured_sender_serial" \
  --observer "$captured_observer_serial" \
  --sender-log "$TMP_DIR/captured-sender.log" \
  --observer-log "$TMP_DIR/captured-observer.log" \
  --summary-json "$TMP_DIR/non-logcat-summary.json" \
  --sender-device-json "$sender_device_json" \
  --observer-device-json "$observer_device_json" \
  > "$TMP_DIR/non-logcat.out"

grep -q "payload_match=true" "$TMP_DIR/non-logcat.out"
grep -q "m26_android_to_android_complete=false" "$TMP_DIR/non-logcat.out"
grep -q "m26_completion_blockers=.*android_logcat_provenance" "$TMP_DIR/non-logcat.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected non-logcat proof incomplete") unless summary.fetch("m26_android_to_android_complete") == false
  blockers = summary.fetch("m26_completion_blockers")
  abort("expected android_logcat_provenance blocker") unless blockers.include?("android_logcat_provenance")
  m26_completion = summary.fetch("m26_completion_validation")
  abort("expected android_logcat_provenance false") unless m26_completion.fetch("android_logcat_provenance") == false
' "$TMP_DIR/non-logcat-summary.json"

if "$AUDIT" "$TMP_DIR/non-logcat-summary.json" > "$TMP_DIR/audit-non-logcat.out"; then
  echo "expected non-logcat completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-non-logcat.out"
grep -q "m26_android_to_android_complete is not true" "$TMP_DIR/audit-non-logcat.out"
grep -q "blockers=.*android_logcat_provenance" "$TMP_DIR/audit-non-logcat.out"

cp "$FIXTURES/sender.log" "$TMP_DIR/tag-only-sender.log"
cp "$FIXTURES/observer.log" "$TMP_DIR/tag-only-observer.log"
ruby -rjson -e '
  ARGV.each do |path|
    lines = File.readlines(path).filter_map do |line|
      match = line.match(/\{.*\}/)
      next unless match

      event = JSON.parse(match[0])
      tag =
        case event["event"]
        when "attempt_outcome", "advertising_set_started"
          "MeshxBleDispatch"
        when "scan_start_result"
          "MeshxBleControl"
        when "received_message"
          "MeshxBle"
        else
          "MeshxBle"
        end
      "I #{tag}: #{JSON.generate(event)}\n"
    end
    File.write(path, lines.join)
  end
' "$TMP_DIR/tag-only-sender.log" "$TMP_DIR/tag-only-observer.log"

"$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender "$captured_sender_serial" \
  --observer "$captured_observer_serial" \
  --sender-log "$TMP_DIR/tag-only-sender.log" \
  --observer-log "$TMP_DIR/tag-only-observer.log" \
  --summary-json "$TMP_DIR/tag-only-summary.json" \
  --sender-device-json "$sender_device_json" \
  --observer-device-json "$observer_device_json" \
  > "$TMP_DIR/tag-only.out"

grep -q "payload_match=true" "$TMP_DIR/tag-only.out"
grep -q "m26_android_to_android_complete=false" "$TMP_DIR/tag-only.out"
grep -q "m26_completion_blockers=.*android_logcat_provenance" "$TMP_DIR/tag-only.out"

cp "$FIXTURES/sender.log" "$TMP_DIR/captured-sender.log"
cp "$FIXTURES/observer.log" "$TMP_DIR/captured-observer.log"
ruby -rjson -e '
  path = ARGV.fetch(0)
  lines = File.readlines(path).map do |line|
    match = line.match(/\{.*\}/)
    next line unless match

    event = JSON.parse(match[0])
    event["outcome_at_ms"] += 1 if event["event"] == "attempt_outcome"
    line.sub(/\{.*\}/, JSON.generate(event))
  end
  File.write(path, lines.join)
' "$TMP_DIR/captured-sender.log"
ruby -rjson -e '
  path = ARGV.fetch(0)
  lines = File.readlines(path).map do |line|
    match = line.match(/\{.*\}/)
    next line unless match

    event = JSON.parse(match[0])
    if event["event"] == "received_message"
      event["received_at"] += 1
      event["received_device_id"] = "02:00:00:00:26:02"
      event["raw_transport_metadata"]["received_device_id"] = "02:00:00:00:26:02"
    end
    line.sub(/\{.*\}/, JSON.generate(event))
  end
  File.write(path, lines.join)
' "$TMP_DIR/captured-observer.log"

cp "$FIXTURES/sender.log" "$TMP_DIR/exact-fixture-copy-sender.log"
cp "$FIXTURES/observer.log" "$TMP_DIR/exact-fixture-copy-observer.log"

"$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender "$captured_sender_serial" \
  --observer "$captured_observer_serial" \
  --sender-log "$TMP_DIR/exact-fixture-copy-sender.log" \
  --observer-log "$TMP_DIR/exact-fixture-copy-observer.log" \
  --summary-json "$TMP_DIR/exact-fixture-copy-summary.json" \
  --sender-device-json "$sender_device_json" \
  --observer-device-json "$observer_device_json" \
  > "$TMP_DIR/exact-fixture-copy.out"

grep -q "payload_match=true" "$TMP_DIR/exact-fixture-copy.out"

if "$AUDIT" "$TMP_DIR/exact-fixture-copy-summary.json" > "$TMP_DIR/audit-exact-fixture-copy.out"; then
  echo "expected exact fixture-copy completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-exact-fixture-copy.out"
grep -q "content matches a checked-in verifier fixture" "$TMP_DIR/audit-exact-fixture-copy.out"

"$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender android-a \
  --observer android-b \
  --sender-log "$TMP_DIR/captured-sender.log" \
  --observer-log "$TMP_DIR/captured-observer.log" \
  --summary-json "$TMP_DIR/synthetic-serial-summary.json" \
  --sender-device-json '{"serial":"android-a","model":"Sender","android_release":"14","android_sdk":"34","bluetooth_le_feature":"true"}' \
  --observer-device-json '{"serial":"android-b","model":"Observer","android_release":"13","android_sdk":"33","bluetooth_le_feature":"true"}' \
  > "$TMP_DIR/synthetic-serial.out"

grep -q "payload_match=true" "$TMP_DIR/synthetic-serial.out"

if "$AUDIT" "$TMP_DIR/synthetic-serial-summary.json" > "$TMP_DIR/audit-synthetic-serial.out"; then
  echo "expected synthetic fixture-serial completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-synthetic-serial.out"
grep -q "sender_serial is a known verifier fixture serial" "$TMP_DIR/audit-synthetic-serial.out"

cp "$TMP_DIR/captured-sender.log" "$TMP_DIR/fixture-device-id-sender.log"
cp "$FIXTURES/observer.log" "$TMP_DIR/fixture-device-id-observer.log"
ruby -rjson -e '
  path = ARGV.fetch(0)
  lines = File.readlines(path).map do |line|
    match = line.match(/\{.*\}/)
    next line unless match

    event = JSON.parse(match[0])
    event["received_at"] += 1 if event["event"] == "received_message"
    line.sub(/\{.*\}/, JSON.generate(event))
  end
  File.write(path, lines.join)
' "$TMP_DIR/fixture-device-id-observer.log"

"$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender "$captured_sender_serial" \
  --observer "$captured_observer_serial" \
  --sender-log "$TMP_DIR/fixture-device-id-sender.log" \
  --observer-log "$TMP_DIR/fixture-device-id-observer.log" \
  --summary-json "$TMP_DIR/fixture-device-id-summary.json" \
  --sender-device-json "$sender_device_json" \
  --observer-device-json "$observer_device_json" \
  > "$TMP_DIR/fixture-device-id.out"

grep -q "payload_match=true" "$TMP_DIR/fixture-device-id.out"

if "$AUDIT" "$TMP_DIR/fixture-device-id-summary.json" > "$TMP_DIR/audit-fixture-device-id.out"; then
  echo "expected fixture received_device_id completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-fixture-device-id.out"
grep -q "observer_log uses known verifier fixture received_device_id" "$TMP_DIR/audit-fixture-device-id.out"

cp "$TMP_DIR/captured-sender.log" "$TMP_DIR/raw-fixture-device-id-sender.log"
cp "$FIXTURES/observer.log" "$TMP_DIR/raw-fixture-device-id-observer.log"
ruby -rjson -e '
  path = ARGV.fetch(0)
  lines = File.readlines(path).map do |line|
    match = line.match(/\{.*\}/)
    next line unless match

    event = JSON.parse(match[0])
    if event["event"] == "received_message"
      event["received_at"] += 2
      event["received_device_id"] = "02:00:00:00:26:03"
    end
    line.sub(/\{.*\}/, JSON.generate(event))
  end
  File.write(path, lines.join)
' "$TMP_DIR/raw-fixture-device-id-observer.log"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["sender_log"] = ARGV.fetch(1)
  summary["observer_log"] = ARGV.fetch(2)
  summary["summary_json"] = ARGV.fetch(3)
  File.write(ARGV.fetch(3), JSON.pretty_generate(summary) + "\n")
' \
  "$TMP_DIR/summary.json" \
  "$TMP_DIR/raw-fixture-device-id-sender.log" \
  "$TMP_DIR/raw-fixture-device-id-observer.log" \
  "$TMP_DIR/raw-fixture-device-id-summary.json"

if "$AUDIT" "$TMP_DIR/raw-fixture-device-id-summary.json" > "$TMP_DIR/audit-raw-fixture-device-id.out"; then
  echo "expected raw fixture received_device_id completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-raw-fixture-device-id.out"
grep -q "raw_transport_metadata.received_device_id" "$TMP_DIR/audit-raw-fixture-device-id.out"

if "$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender "$captured_sender_serial" \
  --observer "$captured_observer_serial" \
  --sender-log "$TMP_DIR/raw-fixture-device-id-sender.log" \
  --observer-log "$TMP_DIR/raw-fixture-device-id-observer.log" \
  --summary-json "$TMP_DIR/raw-device-id-mismatch-summary.json" \
  --sender-device-json "$sender_device_json" \
  --observer-device-json "$observer_device_json" \
  > "$TMP_DIR/raw-device-id-mismatch.out" 2> "$TMP_DIR/raw-device-id-mismatch.err"; then
  echo "expected raw received_device_id mismatch verification to fail" >&2
  exit 1
fi

grep -q "raw_transport_metadata.received_device_id does not match" "$TMP_DIR/raw-device-id-mismatch.err"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary.fetch("sender_device").delete("android_sdk")
  summary["summary_json"] = ARGV.fetch(1)
  File.write(ARGV.fetch(1), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/summary.json" "$TMP_DIR/missing-device-metadata-summary.json"

if "$AUDIT" "$TMP_DIR/missing-device-metadata-summary.json" > "$TMP_DIR/audit-missing-device-metadata.out"; then
  echo "expected missing device metadata completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-missing-device-metadata.out"
grep -q "sender_device.android_sdk is missing" "$TMP_DIR/audit-missing-device-metadata.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary.fetch("sender_device")["android_sdk"] = "n/a"
  summary["summary_json"] = ARGV.fetch(1)
  File.write(ARGV.fetch(1), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/summary.json" "$TMP_DIR/nonnumeric-device-metadata-summary.json"

if "$AUDIT" "$TMP_DIR/nonnumeric-device-metadata-summary.json" > "$TMP_DIR/audit-nonnumeric-device-metadata.out"; then
  echo "expected nonnumeric device metadata completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-nonnumeric-device-metadata.out"
grep -q "sender_device.android_sdk is not numeric" "$TMP_DIR/audit-nonnumeric-device-metadata.out"

"$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender "$captured_sender_serial" \
  --observer "$captured_observer_serial" \
  --sender-log "$TMP_DIR/captured-sender.log" \
  --observer-log "$TMP_DIR/captured-observer.log" \
  --summary-json "$TMP_DIR/no-device-metadata-summary.json" \
  > "$TMP_DIR/no-device-metadata.out"

grep -q "payload_match=true" "$TMP_DIR/no-device-metadata.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected M26 incomplete without metadata") unless summary.fetch("m26_android_to_android_complete") == false
  blockers = summary.fetch("m26_completion_blockers")
  abort("expected sender metadata blocker") unless blockers.include?("sender_device_metadata_complete")
  abort("expected observer metadata blocker") unless blockers.include?("observer_device_metadata_complete")
  completion = summary.fetch("m26_completion_validation")
  abort("expected sender metadata false") unless completion.fetch("sender_device_metadata_complete") == false
  abort("expected observer metadata false") unless completion.fetch("observer_device_metadata_complete") == false
' "$TMP_DIR/no-device-metadata-summary.json"

invalid_sender_device_json='{"serial":"R52W90AW7EN","model":"Sender","android_release":"14","android_sdk":"n/a","bluetooth_le_feature":"true"}'

"$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender "$captured_sender_serial" \
  --observer "$captured_observer_serial" \
  --sender-log "$TMP_DIR/captured-sender.log" \
  --observer-log "$TMP_DIR/captured-observer.log" \
  --summary-json "$TMP_DIR/invalid-api-metadata-summary.json" \
  --sender-device-json "$invalid_sender_device_json" \
  --observer-device-json "$observer_device_json" \
  > "$TMP_DIR/invalid-api-metadata.out"

grep -q "payload_match=true" "$TMP_DIR/invalid-api-metadata.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected M26 incomplete with nonnumeric API") unless summary.fetch("m26_android_to_android_complete") == false
  blockers = summary.fetch("m26_completion_blockers")
  abort("expected sender metadata blocker") unless blockers.include?("sender_device_metadata_complete")
  completion = summary.fetch("m26_completion_validation")
  abort("expected sender metadata false") unless completion.fetch("sender_device_metadata_complete") == false
  abort("expected observer metadata true") unless completion.fetch("observer_device_metadata_complete") == true
' "$TMP_DIR/invalid-api-metadata-summary.json"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["sender_log"] = ARGV.fetch(1)
  summary["summary_json"] = ARGV.fetch(2)
  File.write(ARGV.fetch(2), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/summary.json" "$FIXTURES/sender.log" "$TMP_DIR/forged-fixture-log-summary.json"

if "$AUDIT" "$TMP_DIR/forged-fixture-log-summary.json" > "$TMP_DIR/audit-forged-fixture-log.out"; then
  echo "expected forged fixture-log completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-forged-fixture-log.out"
grep -q "sender_log is a checked-in fixture" "$TMP_DIR/audit-forged-fixture-log.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary.delete("observer_log")
  summary["summary_json"] = ARGV.fetch(1)
  File.write(ARGV.fetch(1), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/summary.json" "$TMP_DIR/missing-observer-log-summary.json"

if "$AUDIT" "$TMP_DIR/missing-observer-log-summary.json" > "$TMP_DIR/audit-missing-observer-log.out"; then
  echo "expected missing observer-log completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-missing-observer-log.out"
grep -q "observer_log is missing" "$TMP_DIR/audit-missing-observer-log.out"

printf '%s\n' 'not a sender logcat proof' > "$TMP_DIR/bogus-sender.log"
printf '%s\n' 'not an observer logcat proof' > "$TMP_DIR/bogus-observer.log"
ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["sender_log"] = ARGV.fetch(1)
  summary["observer_log"] = ARGV.fetch(2)
  summary["summary_json"] = ARGV.fetch(3)
  File.write(ARGV.fetch(3), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/summary.json" "$TMP_DIR/bogus-sender.log" "$TMP_DIR/bogus-observer.log" "$TMP_DIR/forged-bogus-log-summary.json"

if "$AUDIT" "$TMP_DIR/forged-bogus-log-summary.json" > "$TMP_DIR/audit-forged-bogus-log.out"; then
  echo "expected forged bogus-log completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-forged-bogus-log.out"
grep -q "referenced logs failed verifier revalidation" "$TMP_DIR/audit-forged-bogus-log.out"
grep -q "summary=$TMP_DIR/forged-bogus-log-summary.json" "$TMP_DIR/audit-forged-bogus-log.out"
grep -q "summary_markdown=$TMP_DIR/summary.md" "$TMP_DIR/audit-forged-bogus-log.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected payload_match") unless summary.fetch("payload_match") == true
  abort("expected observer_scan_started") unless summary.fetch("observer_scan_started") == true
  abort("expected observer scan start event") unless summary.fetch("observer_scan_start_event").fetch("accepted") == true
  abort("expected require_scan_start") unless summary.fetch("require_scan_start") == true
  abort("expected sender_attempt_dispatched") unless summary.fetch("sender_attempt_dispatched") == true
  abort("expected sender_attempt_matches_advertising_set") unless summary.fetch("sender_attempt_matches_advertising_set") == true
  abort("expected sender_payload_size_matches") unless summary.fetch("sender_payload_size_matches") == true
  abort("expected observer_m14_consistent") unless summary.fetch("observer_m14_consistent") == true
  abort("expected observer_meshx_transport_metadata") unless summary.fetch("observer_meshx_transport_metadata") == true
  abort("expected matched payload") unless summary.fetch("matched_payload") == "TVgBAAABAgMEBQYHCAkKCwwNDg8AAAGLz+VoAAELbWVzaHgtYWxwaGEKbWVzaHgtYmV0YQJUWAAAAmhp"
  m14 = summary.fetch("m14_envelope")
  abort("expected m14 sender") unless m14.fetch("sender_peer_id") == "meshx-alpha"
  abort("expected m14 recipient") unless m14.fetch("recipient_peer_id") == "meshx-beta"
  abort("expected m14 ttl") unless m14.fetch("ttl") == 1
  abort("expected m14 payload type") unless m14.fetch("payload_type") == "TX"
  abort("expected m14 payload base64") unless m14.fetch("payload_base64") == "aGk="
  abort("expected sender_device serial") unless summary.fetch("sender_device").fetch("serial") == "R52W90AW7EN"
  abort("expected sender_device model") unless summary.fetch("sender_device").fetch("model") == "Sender"
  abort("expected sender_device API") unless summary.fetch("sender_device").fetch("android_sdk") == "34"
  abort("expected sender BLE") unless summary.fetch("sender_device").fetch("bluetooth_le_feature") == "true"
  abort("expected observer_device serial") unless summary.fetch("observer_device").fetch("serial") == "R99M26OBSERVER"
  abort("expected observer_device model") unless summary.fetch("observer_device").fetch("model") == "Observer"
  abort("expected observer_device API") unless summary.fetch("observer_device").fetch("android_sdk") == "33"
  abort("expected observer BLE") unless summary.fetch("observer_device").fetch("bluetooth_le_feature") == "true"
  abort("expected summary json path") unless summary.fetch("summary_json") == ARGV.fetch(0)
  abort("expected summary markdown path") unless summary.fetch("summary_markdown").end_with?("summary.md")
  abort("expected verify_only mode") unless summary.fetch("capture_context").fetch("mode") == "verify_only"
  abort("expected command capture") unless summary.fetch("capture_context").fetch("commands").first.include?("--verify-only")
  abort("expected require-scan-start command capture") unless summary.fetch("capture_context").fetch("commands").first.include?("--require-scan-start")
  abort("expected no adb devices log in verify-only") unless summary.fetch("adb_devices_log") == nil
  abort("expected no adb inventory in verify-only") unless summary.fetch("adb_inventory_device_count") == 0
  abort("expected no adb ready inventory in verify-only") unless summary.fetch("adb_ready_device_count") == 0
  abort("expected no adb nonready inventory in verify-only") unless summary.fetch("adb_nonready_device_count") == 0
  abort("expected empty adb inventory in verify-only") unless summary.fetch("adb_inventory") == []
  abort("expected no adb mdns log in verify-only") unless summary.fetch("adb_mdns_log") == nil
  abort("expected no adb mdns services in verify-only") unless summary.fetch("adb_mdns_service_count") == 0
  abort("expected no host usb log in verify-only") unless summary.fetch("host_usb_log") == nil
  abort("expected no host usb candidates in verify-only") unless summary.fetch("host_usb_android_candidate_count") == 0
  abort("expected M26 completion") unless summary.fetch("m26_android_to_android_complete") == true
  abort("expected no M26 blockers") unless summary.fetch("m26_completion_blockers").empty?
  m26_completion = summary.fetch("m26_completion_validation")
  abort("expected M26 distinct serials") unless m26_completion.fetch("sender_and_observer_distinct") == true
  abort("expected M26 distinct log files") unless m26_completion.fetch("sender_and_observer_logs_distinct") == true
  abort("expected M26 sender metadata") unless m26_completion.fetch("sender_device_metadata_complete") == true
  abort("expected M26 observer metadata") unless m26_completion.fetch("observer_device_metadata_complete") == true
  abort("expected M26 require_scan_start") unless m26_completion.fetch("require_scan_start") == true
  abort("expected M26 Android logcat provenance") unless m26_completion.fetch("android_logcat_provenance") == true
  abort("expected M26 non-fixture logs") unless m26_completion.fetch("not_repo_fixture_log_pair") == true
  m26_provenance = summary.fetch("m26_completion_provenance")
  abort("expected M26 verify-only provenance") unless m26_provenance.fetch("mode") == "verify_only"
  abort("expected M26 live_run false") unless m26_provenance.fetch("live_run") == false
  abort("expected M26 verify_only true") unless m26_provenance.fetch("verify_only") == true
  abort("expected M26 non-fixture provenance") unless m26_provenance.fetch("repo_fixture_log_pair") == false
  abort("expected M26 real logcat requirement") unless m26_provenance.fetch("real_two_android_logcat_required") == true
  payload_sizes = summary.fetch("payload_sizes")
  abort("expected sender payload size") unless payload_sizes.fetch("sender_advertising_payload") == 60
  abort("expected observer envelope size") unless payload_sizes.fetch("observer_received_message_envelope") == 60
  abort("expected observer manufacturer size") unless payload_sizes.fetch("observer_raw_transport_manufacturer_data") == 62
  validation = summary.fetch("validation")
  abort("expected validation advertising_set_started") unless validation.fetch("advertising_set_started") == true
  abort("expected validation sender_attempt_matches_advertising_set") unless validation.fetch("sender_attempt_matches_advertising_set") == true
  abort("expected validation sender_payload_size_matches") unless validation.fetch("sender_payload_size_matches") == true
  abort("expected validation received_message_logged") unless validation.fetch("received_message_logged") == true
  abort("expected validation observer_meshx_transport_metadata") unless validation.fetch("observer_meshx_transport_metadata") == true
' "$TMP_DIR/summary.json"

grep -q "MeshX Android BLE Message Delivery Verification" "$TMP_DIR/summary.md"
grep -q "## Commands" "$TMP_DIR/summary.md"
grep -q "sender_log.*$TMP_DIR/captured-sender.log" "$TMP_DIR/summary.md"
grep -q "observer_log.*$TMP_DIR/captured-observer.log" "$TMP_DIR/summary.md"
grep -q "adb_devices_log.*n/a" "$TMP_DIR/summary.md"
grep -q "ADB Inventory" "$TMP_DIR/summary.md"
grep -q "adb_inventory_device_count.*0" "$TMP_DIR/summary.md"
grep -q "adb_mdns_service_count.*0" "$TMP_DIR/summary.md"
grep -q "host_usb_android_candidate_count.*0" "$TMP_DIR/summary.md"
grep -q "ADB mDNS Services" "$TMP_DIR/summary.md"
grep -q "Host USB Android Candidates" "$TMP_DIR/summary.md"
grep -q "| Role | Serial | Model | Android | API | BLE LE |" "$TMP_DIR/summary.md"
grep -q "## Payload Sizes" "$TMP_DIR/summary.md"
grep -q "| sender advertising_set_started.payload | \`60\` |" "$TMP_DIR/summary.md"
grep -q "| observer raw_transport_metadata.manufacturer_data | \`62\` |" "$TMP_DIR/summary.md"
grep -q "Device A Attempt Outcome" "$TMP_DIR/summary.md"
grep -q "Device A Advertising Event" "$TMP_DIR/summary.md"
grep -q "Device B Scan Start Event" "$TMP_DIR/summary.md"
grep -q "Device B Received Event" "$TMP_DIR/summary.md"
grep -q "summary_markdown.*$TMP_DIR/summary.md" "$TMP_DIR/summary.md"
grep -q "m26_android_to_android_complete.*true" "$TMP_DIR/summary.md"
grep -q "M26 Completion Gate" "$TMP_DIR/summary.md"
grep -q "M26 Completion Provenance" "$TMP_DIR/summary.md"
grep -q "sender_device_metadata_complete.*true" "$TMP_DIR/summary.md"
grep -q "observer_device_metadata_complete.*true" "$TMP_DIR/summary.md"
grep -q "sender_and_observer_logs_distinct.*true" "$TMP_DIR/summary.md"
grep -q "android_logcat_provenance.*true" "$TMP_DIR/summary.md"
grep -q "repo_fixture_log_pair.*false" "$TMP_DIR/summary.md"

"$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender android-a \
  --observer android-b \
  --sender-log "$FIXTURES/sender.log" \
  --observer-log "$FIXTURES/observer.log" \
  --summary-json "$TMP_DIR/repo-fixture-summary.json" \
  > "$TMP_DIR/repo-fixture.out"

grep -q "payload_match=true" "$TMP_DIR/repo-fixture.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected repo fixture payload_match") unless summary.fetch("payload_match") == true
  abort("expected repo fixture M26 incomplete") unless summary.fetch("m26_android_to_android_complete") == false
  blockers = summary.fetch("m26_completion_blockers")
  abort("expected repo fixture blocker") unless blockers.include?("not_repo_fixture_log_pair")
  abort("expected repo fixture validation false") unless summary.fetch("m26_completion_validation").fetch("not_repo_fixture_log_pair") == false
  provenance = summary.fetch("m26_completion_provenance")
  abort("expected repo fixture provenance") unless provenance.fetch("repo_fixture_log_pair") == true
  abort("expected repo fixture verify-only mode") unless provenance.fetch("mode") == "verify_only"
 ' "$TMP_DIR/repo-fixture-summary.json"

if "$AUDIT" "$TMP_DIR/repo-fixture-summary.json" > "$TMP_DIR/audit-repo-fixture.out"; then
  echo "expected repo fixture completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-repo-fixture.out"

mkdir -p "$TMP_DIR/fake-bin"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'case "$*" in'
  printf '%s\n' '  "devices"|"devices -l")'
  printf '%s\n' '    printf "%s\n" "List of devices attached"'
  printf '%s\n' '    printf "%s\n" "R52W90AW7EN            device usb:1-1 product:gtactive3ue model:SM_T577U device:gtactive3 transport_id:1"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "mdns services")'
  printf '%s\n' '    printf "%s\n" "List of discovered mdns services"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.product.model")'
  printf '%s\n' '    printf "%s\n" "SM-T577U"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.build.version.release")'
  printf '%s\n' '    printf "%s\n" "13"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.build.version.sdk")'
  printf '%s\n' '    printf "%s\n" "33"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell pm has-feature android.hardware.bluetooth_le")'
  printf '%s\n' '    printf "%s\n" "true"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  *)'
  printf '%s\n' '    echo "unexpected fake adb call: $*" >&2'
  printf '%s\n' '    exit 99'
  printf '%s\n' '    ;;'
  printf '%s\n' 'esac'
} > "$TMP_DIR/fake-bin/adb"
chmod +x "$TMP_DIR/fake-bin/adb"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'printf "%s\n" "+-o SAMSUNG_Android@01100000  <class IOUSBHostDevice, id 0x1, registered, matched, active, busy 0, retain 37>"'
  printf '%s\n' 'printf "%s\n" "  \"kUSBSerialNumberString\" = \"R52W90AW7EN\""'
  printf '%s\n' 'printf "%s\n" "  \"USB Vendor Name\" = \"SAMSUNG\""'
  printf '%s\n' 'printf "%s\n" "  \"USB Product Name\" = \"SAMSUNG_Android\""'
  printf '%s\n' 'printf "%s\n" "+-o USB2.0 PC CAMERA@00130000  <class IOUSBHostDevice, id 0x2, registered, matched, active, busy 0, retain 32>"'
  printf '%s\n' 'printf "%s\n" "  \"USB Product Name\" = \"USB2.0 PC CAMERA\""'
} > "$TMP_DIR/fake-bin/ioreg"
chmod +x "$TMP_DIR/fake-bin/ioreg"

if PATH="$TMP_DIR/fake-bin:$PATH" "$SCRIPT" \
  --skip-install \
  --out-dir "$TMP_DIR/preflight" \
  > "$TMP_DIR/preflight.out" 2> "$TMP_DIR/preflight.err"; then
  echo "expected one-device preflight to fail" >&2
  exit 1
fi

grep -q "expected exactly two attached adb devices, found 1" "$TMP_DIR/preflight.err"
grep -q "preflight_summary=$TMP_DIR/preflight/summary.json" "$TMP_DIR/preflight.err"
grep -q "preflight_adb_mdns_service_count=0" "$TMP_DIR/preflight.err"
grep -q "preflight_host_usb_android_candidate_count=1" "$TMP_DIR/preflight.err"
assert_m26_completion_schema "$TMP_DIR/preflight/summary.json"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected preflight_failed mode") unless summary.fetch("capture_context").fetch("mode") == "preflight_failed"
  abort("expected default wait seconds") unless summary.fetch("capture_context").fetch("wait_for_devices_sec") == 0
  abort("expected summary_json path") unless summary.fetch("summary_json").end_with?("/preflight/summary.json")
  abort("expected one attached device") unless summary.fetch("attached_device_count") == 1
  abort("expected one adb inventory device") unless summary.fetch("adb_inventory_device_count") == 1
  abort("expected one adb ready device") unless summary.fetch("adb_ready_device_count") == 1
  abort("expected no adb nonready devices") unless summary.fetch("adb_nonready_device_count") == 0
  inventory = summary.fetch("adb_inventory")
  abort("expected inventory serial") unless inventory.first.fetch("serial") == "R52W90AW7EN"
  abort("expected inventory state") unless inventory.first.fetch("state") == "device"
  device = summary.fetch("attached_devices").first
  abort("expected attached serial") unless device.fetch("serial") == "R52W90AW7EN"
  abort("expected attached model") unless device.fetch("model") == "SM-T577U"
  abort("expected attached API") unless device.fetch("android_sdk") == "33"
  abort("expected attached BLE feature") unless device.fetch("bluetooth_le_feature") == "true"
  abort("expected no sender device row") unless summary.fetch("sender_device") == nil
  abort("expected no observer device row") unless summary.fetch("observer_device") == nil
  abort("expected no adb mdns services") unless summary.fetch("adb_mdns_service_count") == 0
  abort("expected empty adb mdns services") unless summary.fetch("adb_mdns_services") == []
  abort("expected host usb log") unless summary.fetch("host_usb_log").end_with?("/preflight/host-usb.txt")
  abort("expected host usb candidate count") unless summary.fetch("host_usb_android_candidate_count") == 1
  usb = summary.fetch("host_usb_android_candidates").first
  abort("expected host usb serial") unless usb.fetch("serial") == "R52W90AW7EN"
  abort("expected host usb product") unless usb.fetch("product") == "SAMSUNG_Android"
  abort("expected command capture") unless summary.fetch("capture_context").fetch("commands").first.include?("--out-dir")
  abort("expected host usb command capture") unless summary.fetch("capture_context").fetch("commands").include?("ioreg -p IOUSB -l -w0")
  abort("expected two_android_devices_attached false") unless summary.fetch("validation").fetch("two_android_devices_attached") == false
  abort("expected exactly_two_android_devices_attached false") unless summary.fetch("validation").fetch("exactly_two_android_devices_attached") == false
  abort("expected sender BLE support false without requested sender") unless summary.fetch("validation").fetch("sender_ble_le_supported") == false
  abort("expected observer BLE support false without requested observer") unless summary.fetch("validation").fetch("observer_ble_le_supported") == false
  abort("expected sender_attempt_matches_advertising_set false") unless summary.fetch("validation").fetch("sender_attempt_matches_advertising_set") == false
  abort("expected observer_meshx_transport_metadata false") unless summary.fetch("validation").fetch("observer_meshx_transport_metadata") == false
  abort("expected payload_match false") unless summary.fetch("validation").fetch("payload_match") == false
  abort("expected M26 incomplete") unless summary.fetch("m26_android_to_android_complete") == false
  abort("expected M26 blocker") unless summary.fetch("m26_completion_blockers").include?("expected exactly two attached adb devices, found 1")
  m26_completion = summary.fetch("m26_completion_validation")
  abort("expected unset sender/observer distinct false") unless m26_completion.fetch("sender_and_observer_distinct") == false
  abort("expected preflight failed log distinct false") unless m26_completion.fetch("sender_and_observer_logs_distinct") == false
  abort("expected sender metadata incomplete") unless m26_completion.fetch("sender_device_metadata_complete") == false
  abort("expected observer metadata incomplete") unless m26_completion.fetch("observer_device_metadata_complete") == false
  abort("expected non-fixture preflight") unless m26_completion.fetch("not_repo_fixture_log_pair") == true
  provenance = summary.fetch("m26_completion_provenance")
  abort("expected preflight provenance mode") unless provenance.fetch("mode") == "preflight_failed"
  abort("expected preflight real logcat requirement") unless provenance.fetch("real_two_android_logcat_required") == true
 ' "$TMP_DIR/preflight/summary.json"

grep -q "MeshX Android BLE Message Delivery Verification" "$TMP_DIR/preflight/summary.md"
grep -q "preflight_failed" "$TMP_DIR/preflight/summary.md"
grep -q "wait_for_devices_sec.*0" "$TMP_DIR/preflight/summary.md"
grep -q "summary_markdown.*$TMP_DIR/preflight/summary.md" "$TMP_DIR/preflight/summary.md"
grep -q "m26_android_to_android_complete.*false" "$TMP_DIR/preflight/summary.md"
grep -q "M26 Completion Gate" "$TMP_DIR/preflight/summary.md"
grep -q "M26 Completion Provenance" "$TMP_DIR/preflight/summary.md"
grep -q "Requested Role Devices" "$TMP_DIR/preflight/summary.md"
grep -q "ADB Inventory" "$TMP_DIR/preflight/summary.md"
grep -q "adb_inventory_device_count.*1" "$TMP_DIR/preflight/summary.md"
grep -q "| \`R52W90AW7EN\` | \`device\` | \`true\` |" "$TMP_DIR/preflight/summary.md"
grep -q "ADB mDNS Services" "$TMP_DIR/preflight/summary.md"
grep -q "adb_mdns_service_count.*0" "$TMP_DIR/preflight/summary.md"
grep -q "| Device A sender | \`unset\` | _not attached_ | _n/a_ | _n/a_ | _n/a_ | _n/a_ |" "$TMP_DIR/preflight/summary.md"
grep -q "| Device B observer | \`unset\` | _not attached_ | _n/a_ | _n/a_ | _n/a_ | _n/a_ |" "$TMP_DIR/preflight/summary.md"
grep -q "Host USB Android Candidates" "$TMP_DIR/preflight/summary.md"
grep -q "| \`R52W90AW7EN\` | \`SAMSUNG_Android\` | \`SAMSUNG\` | \`SAMSUNG_Android\` |" "$TMP_DIR/preflight/summary.md"
grep -q "expected exactly two attached adb devices, found 1" "$TMP_DIR/preflight/summary.md"
grep -q "| Serial | State | Model | Android | API | BLE LE | Details |" "$TMP_DIR/preflight/summary.md"
grep -q "| \`R52W90AW7EN\` | \`device\` | \`SM-T577U\` | \`13\` | \`33\` | \`true\` |" "$TMP_DIR/preflight/summary.md"

mkdir -p "$TMP_DIR/fake-bin-nonready"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'case "$*" in'
  printf '%s\n' '  "devices"|"devices -l")'
  printf '%s\n' '    printf "%s\n" "List of devices attached"'
  printf '%s\n' '    printf "%s\n" "R52W90AW7EN            device usb:1-1 product:gtactive3ue model:SM_T577U device:gtactive3 transport_id:1"'
  printf '%s\n' '    printf "%s\n" "R99M26OBSERVER        unauthorized usb:1-2 transport_id:2"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "mdns services")'
  printf '%s\n' '    printf "%s\n" "List of discovered mdns services"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.product.model") printf "%s\n" "SM-T577U" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.build.version.release") printf "%s\n" "13" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.build.version.sdk") printf "%s\n" "33" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell pm has-feature android.hardware.bluetooth_le") printf "%s\n" "true" ;;'
  printf '%s\n' '  *)'
  printf '%s\n' '    echo "unexpected fake adb call: $*" >&2'
  printf '%s\n' '    exit 99'
  printf '%s\n' '    ;;'
  printf '%s\n' 'esac'
} > "$TMP_DIR/fake-bin-nonready/adb"
chmod +x "$TMP_DIR/fake-bin-nonready/adb"
cp "$TMP_DIR/fake-bin/ioreg" "$TMP_DIR/fake-bin-nonready/ioreg"

if PATH="$TMP_DIR/fake-bin-nonready:$PATH" "$SCRIPT" \
  --skip-install \
  --out-dir "$TMP_DIR/preflight-nonready" \
  > "$TMP_DIR/preflight-nonready.out" 2> "$TMP_DIR/preflight-nonready.err"; then
  echo "expected nonready-device preflight to fail" >&2
  exit 1
fi

grep -q "expected exactly two ready adb devices, found 1 ready (2 total adb rows, 1 non-ready: R99M26OBSERVER:unauthorized)" "$TMP_DIR/preflight-nonready.err"
ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected one ready attached device") unless summary.fetch("attached_device_count") == 1
  abort("expected two adb inventory rows") unless summary.fetch("adb_inventory_device_count") == 2
  abort("expected one ready adb row") unless summary.fetch("adb_ready_device_count") == 1
  abort("expected one nonready adb row") unless summary.fetch("adb_nonready_device_count") == 1
  nonready = summary.fetch("adb_inventory").find { |device| device.fetch("serial") == "R99M26OBSERVER" }
  abort("expected nonready observer inventory row") unless nonready
  abort("expected unauthorized state") unless nonready.fetch("state") == "unauthorized"
  abort("expected nonready not ready") unless nonready.fetch("ready") == false
' "$TMP_DIR/preflight-nonready/summary.json"

grep -q "ADB Inventory" "$TMP_DIR/preflight-nonready/summary.md"
grep -q "adb_inventory_device_count.*2" "$TMP_DIR/preflight-nonready/summary.md"
grep -q "adb_nonready_device_count.*1" "$TMP_DIR/preflight-nonready/summary.md"
grep -q "| \`R99M26OBSERVER\` | \`unauthorized\` | \`false\` |" "$TMP_DIR/preflight-nonready/summary.md"

if PATH="$TMP_DIR/fake-bin-nonready:$PATH" "$SCRIPT" \
  --skip-install \
  --sender "$captured_sender_serial" \
  --observer "$captured_observer_serial" \
  --out-dir "$TMP_DIR/preflight-explicit-nonready" \
  > "$TMP_DIR/preflight-explicit-nonready.out" 2> "$TMP_DIR/preflight-explicit-nonready.err"; then
  echo "expected explicit nonready observer preflight to fail" >&2
  exit 1
fi

grep -q "requested adb device(s) not ready: R99M26OBSERVER:unauthorized" "$TMP_DIR/preflight-explicit-nonready.err"
ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected explicit nonready error") unless summary.fetch("error") == "requested adb device(s) not ready: R99M26OBSERVER:unauthorized"
  abort("expected requested sender") unless summary.fetch("requested_sender_serial") == "R52W90AW7EN"
  abort("expected requested observer") unless summary.fetch("requested_observer_serial") == "R99M26OBSERVER"
  abort("expected one ready attached device") unless summary.fetch("attached_device_count") == 1
  abort("expected two adb inventory rows") unless summary.fetch("adb_inventory_device_count") == 2
  abort("expected one nonready adb row") unless summary.fetch("adb_nonready_device_count") == 1
  abort("expected sender device metadata") unless summary.fetch("sender_device").fetch("serial") == "R52W90AW7EN"
  abort("expected observer not attached") unless summary.fetch("observer_device") == nil
' "$TMP_DIR/preflight-explicit-nonready/summary.json"

grep -q "requested adb device(s) not ready: R99M26OBSERVER:unauthorized" "$TMP_DIR/preflight-explicit-nonready/summary.md"
grep -q "| Device B observer | \`R99M26OBSERVER\` | _not attached_ | _n/a_ | _n/a_ | _n/a_ | _n/a_ |" "$TMP_DIR/preflight-explicit-nonready/summary.md"

if PATH="$TMP_DIR/fake-bin-nonready:$PATH" "$SCRIPT" \
  --skip-install \
  --sender R99M26OBSERVER \
  --observer missing-android \
  --out-dir "$TMP_DIR/preflight-explicit-mixed-missing-nonready" \
  > "$TMP_DIR/preflight-explicit-mixed-missing-nonready.out" 2> "$TMP_DIR/preflight-explicit-mixed-missing-nonready.err"; then
  echo "expected explicit mixed missing/nonready preflight to fail" >&2
  exit 1
fi

grep -q "requested adb device(s) not attached: missing-android; requested adb device(s) not ready: R99M26OBSERVER:unauthorized" "$TMP_DIR/preflight-explicit-mixed-missing-nonready.err"
ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  expected = "requested adb device(s) not attached: missing-android; requested adb device(s) not ready: R99M26OBSERVER:unauthorized"
  abort("expected mixed error") unless summary.fetch("error") == expected
  abort("expected requested sender") unless summary.fetch("requested_sender_serial") == "R99M26OBSERVER"
  abort("expected requested observer") unless summary.fetch("requested_observer_serial") == "missing-android"
  abort("expected one ready attached device") unless summary.fetch("attached_device_count") == 1
  abort("expected two adb inventory rows") unless summary.fetch("adb_inventory_device_count") == 2
  abort("expected one nonready adb row") unless summary.fetch("adb_nonready_device_count") == 1
  abort("expected sender not attached because nonready") unless summary.fetch("sender_device") == nil
  abort("expected observer not attached") unless summary.fetch("observer_device") == nil
' "$TMP_DIR/preflight-explicit-mixed-missing-nonready/summary.json"

grep -q "requested adb device(s) not attached: missing-android; requested adb device(s) not ready: R99M26OBSERVER:unauthorized" "$TMP_DIR/preflight-explicit-mixed-missing-nonready/summary.md"
grep -q "| Device A sender | \`R99M26OBSERVER\` | _not attached_ | _n/a_ | _n/a_ | _n/a_ | _n/a_ |" "$TMP_DIR/preflight-explicit-mixed-missing-nonready/summary.md"
grep -q "| Device B observer | \`missing-android\` | _not attached_ | _n/a_ | _n/a_ | _n/a_ | _n/a_ |" "$TMP_DIR/preflight-explicit-mixed-missing-nonready/summary.md"

if PATH="$TMP_DIR/fake-bin:$PATH" "$SCRIPT" \
  --preflight-only \
  --skip-install \
  --out-dir "$TMP_DIR/preflight-only-one-device" \
  > "$TMP_DIR/preflight-only-one-device.out" 2> "$TMP_DIR/preflight-only-one-device.err"; then
  echo "expected one-device --preflight-only to fail" >&2
  exit 1
fi

grep -q "expected exactly two attached adb devices, found 1" "$TMP_DIR/preflight-only-one-device.err"
grep -q "preflight_summary=$TMP_DIR/preflight-only-one-device/summary.json" "$TMP_DIR/preflight-only-one-device.err"
grep -q "preflight_adb_mdns_service_count=0" "$TMP_DIR/preflight-only-one-device.err"
grep -q "preflight_host_usb_android_candidate_count=1" "$TMP_DIR/preflight-only-one-device.err"

if "$AUDIT" "$TMP_DIR/preflight-only-one-device/summary.json" > "$TMP_DIR/audit-preflight-only-one-device.out"; then
  echo "expected one-device preflight completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-preflight-only-one-device.out"
grep -q "blockers=expected exactly two attached adb devices, found 1" "$TMP_DIR/audit-preflight-only-one-device.out"
grep -q "summary=$TMP_DIR/preflight-only-one-device/summary.json" "$TMP_DIR/audit-preflight-only-one-device.out"
grep -q "summary_markdown=$TMP_DIR/preflight-only-one-device/summary.md" "$TMP_DIR/audit-preflight-only-one-device.out"
grep -q "adb_devices_log=$TMP_DIR/preflight-only-one-device/adb-devices.txt" "$TMP_DIR/audit-preflight-only-one-device.out"
grep -q "adb_mdns_log=$TMP_DIR/preflight-only-one-device/adb-mdns-services.txt" "$TMP_DIR/audit-preflight-only-one-device.out"
grep -q "host_usb_log=$TMP_DIR/preflight-only-one-device/host-usb.txt" "$TMP_DIR/audit-preflight-only-one-device.out"
grep -q "adb_ready_device_count=1" "$TMP_DIR/audit-preflight-only-one-device.out"
grep -q "adb_nonready_device_count=0" "$TMP_DIR/audit-preflight-only-one-device.out"
grep -q "adb_mdns_service_count=0" "$TMP_DIR/audit-preflight-only-one-device.out"
grep -q "host_usb_android_candidate_count=1" "$TMP_DIR/audit-preflight-only-one-device.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected preflight_failed mode") unless summary.fetch("capture_context").fetch("mode") == "preflight_failed"
  abort("expected preflight-only command capture") unless summary.fetch("capture_context").fetch("commands").first.include?("--preflight-only")
  abort("expected one-device M26 incomplete") unless summary.fetch("m26_android_to_android_complete") == false
  abort("expected one-device blocker") unless summary.fetch("m26_completion_blockers").include?("expected exactly two attached adb devices, found 1")
  abort("expected one host usb candidate") unless summary.fetch("host_usb_android_candidate_count") == 1
' "$TMP_DIR/preflight-only-one-device/summary.json"

if PATH="$TMP_DIR/fake-bin:$PATH" "$SCRIPT" \
  --preflight-only \
  --wait-for-devices 1 \
  --skip-install \
  --out-dir "$TMP_DIR/preflight-wait-timeout" \
  > "$TMP_DIR/preflight-wait-timeout.out" 2> "$TMP_DIR/preflight-wait-timeout.err"; then
  echo "expected one-device --wait-for-devices preflight to fail" >&2
  exit 1
fi

grep -q "expected exactly two attached adb devices, found 1" "$TMP_DIR/preflight-wait-timeout.err"
grep -q "preflight_summary=$TMP_DIR/preflight-wait-timeout/summary.json" "$TMP_DIR/preflight-wait-timeout.err"
grep -q "preflight_adb_mdns_service_count=0" "$TMP_DIR/preflight-wait-timeout.err"
grep -q "preflight_host_usb_android_candidate_count=1" "$TMP_DIR/preflight-wait-timeout.err"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected wait timeout preflight_failed mode") unless summary.fetch("capture_context").fetch("mode") == "preflight_failed"
  abort("expected wait timeout seconds") unless summary.fetch("capture_context").fetch("wait_for_devices_sec") == 1
  command = summary.fetch("capture_context").fetch("commands").first
  abort("expected wait timeout command capture") unless command.include?("--wait-for-devices 1")
  abort("expected wait timeout one-device count") unless summary.fetch("attached_device_count") == 1
  abort("expected wait timeout M26 incomplete") unless summary.fetch("m26_android_to_android_complete") == false
  abort("expected wait timeout blocker") unless summary.fetch("m26_completion_blockers").include?("expected exactly two attached adb devices, found 1")
' "$TMP_DIR/preflight-wait-timeout/summary.json"

if PATH="$TMP_DIR/fake-bin:$PATH" "$SCRIPT" \
  --skip-install \
  > "$TMP_DIR/preflight-default.out" 2> "$TMP_DIR/preflight-default.err"; then
  echo "expected default-output one-device preflight to fail" >&2
  exit 1
fi

grep -q "expected exactly two attached adb devices, found 1" "$TMP_DIR/preflight-default.err"
grep -q "preflight_adb_mdns_service_count=0" "$TMP_DIR/preflight-default.err"
grep -q "preflight_host_usb_android_candidate_count=1" "$TMP_DIR/preflight-default.err"
default_preflight_summary="$(sed -n 's/^preflight_summary=//p' "$TMP_DIR/preflight-default.err")"
default_preflight_markdown="$(sed -n 's/^preflight_summary_markdown=//p' "$TMP_DIR/preflight-default.err")"
case "$default_preflight_summary" in
  /tmp/meshx-android-m26-*/summary.json) ;;
  *)
    echo "unexpected default preflight summary path: $default_preflight_summary" >&2
    exit 1
    ;;
esac
case "$default_preflight_markdown" in
  /tmp/meshx-android-m26-*/summary.md) ;;
  *)
    echo "unexpected default preflight markdown path: $default_preflight_markdown" >&2
    exit 1
    ;;
esac
EXTRA_CLEANUP_DIRS+=("$(dirname "$default_preflight_summary")")

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected preflight_failed mode") unless summary.fetch("capture_context").fetch("mode") == "preflight_failed"
  abort("expected default summary_json path") unless summary.fetch("summary_json") == ARGV.fetch(0)
  abort("expected default summary_markdown path") unless summary.fetch("summary_markdown") == ARGV.fetch(1)
  abort("expected one attached device") unless summary.fetch("attached_device_count") == 1
  command = summary.fetch("capture_context").fetch("commands").first
  abort("expected command capture") unless command.include?("--skip-install")
  abort("expected no explicit out-dir in command capture") if command.include?("--out-dir")
  abort("expected sender_attempt_matches_advertising_set false") unless summary.fetch("validation").fetch("sender_attempt_matches_advertising_set") == false
  abort("expected observer_meshx_transport_metadata false") unless summary.fetch("validation").fetch("observer_meshx_transport_metadata") == false
  abort("expected default M26 incomplete") unless summary.fetch("m26_android_to_android_complete") == false
  abort("expected default M26 blocker") unless summary.fetch("m26_completion_blockers").include?("expected exactly two attached adb devices, found 1")
  abort("expected default host usb log") unless summary.fetch("host_usb_log").end_with?("/host-usb.txt")
  abort("expected default host usb candidate") unless summary.fetch("host_usb_android_candidates").first.fetch("serial") == "R52W90AW7EN"
  provenance = summary.fetch("m26_completion_provenance")
  abort("expected default preflight provenance mode") unless provenance.fetch("mode") == "preflight_failed"
  abort("expected default real logcat requirement") unless provenance.fetch("real_two_android_logcat_required") == true
 ' "$default_preflight_summary" "$default_preflight_markdown"

grep -q "MeshX Android BLE Message Delivery Verification" "$default_preflight_markdown"
grep -q "summary_json.*$default_preflight_summary" "$default_preflight_markdown"
grep -q "summary_markdown.*$default_preflight_markdown" "$default_preflight_markdown"
grep -q "M26 Completion Gate" "$default_preflight_markdown"
grep -q "M26 Completion Provenance" "$default_preflight_markdown"
grep -q "Host USB Android Candidates" "$default_preflight_markdown"
grep -q "expected exactly two attached adb devices, found 1" "$default_preflight_markdown"

if PATH="$TMP_DIR/fake-bin:$PATH" "$SCRIPT" \
  --skip-install \
  --sender R52W90AW7EN \
  --observer missing-android \
  --out-dir "$TMP_DIR/preflight-missing-explicit" \
  > "$TMP_DIR/preflight-missing-explicit.out" 2> "$TMP_DIR/preflight-missing-explicit.err"; then
  echo "expected missing explicit observer preflight to fail" >&2
  exit 1
fi

grep -q "requested adb device(s) not attached: missing-android" "$TMP_DIR/preflight-missing-explicit.err"
grep -q "preflight_summary=$TMP_DIR/preflight-missing-explicit/summary.json" "$TMP_DIR/preflight-missing-explicit.err"
grep -q "preflight_adb_mdns_service_count=0" "$TMP_DIR/preflight-missing-explicit.err"
grep -q "preflight_host_usb_android_candidate_count=1" "$TMP_DIR/preflight-missing-explicit.err"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected preflight_failed mode") unless summary.fetch("capture_context").fetch("mode") == "preflight_failed"
  abort("expected summary_json path") unless summary.fetch("summary_json").end_with?("/preflight-missing-explicit/summary.json")
  abort("expected missing observer error") unless summary.fetch("error") == "requested adb device(s) not attached: missing-android"
  abort("expected requested sender") unless summary.fetch("requested_sender_serial") == "R52W90AW7EN"
  abort("expected requested observer") unless summary.fetch("requested_observer_serial") == "missing-android"
  abort("expected one attached device") unless summary.fetch("attached_device_count") == 1
  abort("expected attached serial") unless summary.fetch("attached_devices").first.fetch("serial") == "R52W90AW7EN"
  abort("expected sender device row") unless summary.fetch("sender_device").fetch("serial") == "R52W90AW7EN"
  abort("expected missing observer device row") unless summary.fetch("observer_device") == nil
  command = summary.fetch("capture_context").fetch("commands").first
  abort("expected sender command capture") unless command.include?("--sender R52W90AW7EN")
  abort("expected observer command capture") unless command.include?("--observer missing-android")
' "$TMP_DIR/preflight-missing-explicit/summary.json"

grep -q "requested_observer_serial.*missing-android" "$TMP_DIR/preflight-missing-explicit/summary.md"
grep -q "summary_markdown.*$TMP_DIR/preflight-missing-explicit/summary.md" "$TMP_DIR/preflight-missing-explicit/summary.md"
grep -q "M26 Completion Gate" "$TMP_DIR/preflight-missing-explicit/summary.md"
grep -q "Requested Role Devices" "$TMP_DIR/preflight-missing-explicit/summary.md"
grep -q "| Device A sender | \`R52W90AW7EN\` | \`R52W90AW7EN\` | \`SM-T577U\` | \`13\` | \`33\` | \`true\` |" "$TMP_DIR/preflight-missing-explicit/summary.md"
grep -q "| Device B observer | \`missing-android\` | _not attached_ | _n/a_ | _n/a_ | _n/a_ | _n/a_ |" "$TMP_DIR/preflight-missing-explicit/summary.md"
grep -q "requested adb device(s) not attached: missing-android" "$TMP_DIR/preflight-missing-explicit/summary.md"

if PATH="$TMP_DIR/fake-bin:$PATH" "$SCRIPT" \
  --skip-install \
  --sender R52W90AW7EN \
  --observer R52W90AW7EN \
  --out-dir "$TMP_DIR/preflight-same-device" \
  > "$TMP_DIR/same-device.out" 2> "$TMP_DIR/same-device.err"; then
  echo "expected same-device sender/observer preflight to fail" >&2
  exit 1
fi

grep -q -- "--sender and --observer must be different adb devices" "$TMP_DIR/same-device.err"
grep -q "preflight_summary=$TMP_DIR/preflight-same-device/summary.json" "$TMP_DIR/same-device.err"
grep -q "preflight_summary_markdown=$TMP_DIR/preflight-same-device/summary.md" "$TMP_DIR/same-device.err"
grep -q "preflight_adb_mdns_service_count=0" "$TMP_DIR/same-device.err"
grep -q "preflight_host_usb_android_candidate_count=1" "$TMP_DIR/same-device.err"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected preflight_failed mode") unless summary.fetch("capture_context").fetch("mode") == "preflight_failed"
  abort("expected same-device summary_json path") unless summary.fetch("summary_json").end_with?("/preflight-same-device/summary.json")
  abort("expected same-device summary_markdown path") unless summary.fetch("summary_markdown").end_with?("/preflight-same-device/summary.md")
  abort("expected same-device error") unless summary.fetch("error") == "--sender and --observer must be different adb devices"
  abort("expected requested sender") unless summary.fetch("requested_sender_serial") == "R52W90AW7EN"
  abort("expected requested observer") unless summary.fetch("requested_observer_serial") == "R52W90AW7EN"
  abort("expected one attached device") unless summary.fetch("attached_device_count") == 1
  abort("expected attached serial") unless summary.fetch("attached_devices").first.fetch("serial") == "R52W90AW7EN"
  abort("expected sender device row") unless summary.fetch("sender_device").fetch("serial") == "R52W90AW7EN"
  abort("expected observer device row") unless summary.fetch("observer_device").fetch("serial") == "R52W90AW7EN"
  command = summary.fetch("capture_context").fetch("commands").first
  abort("expected same sender command capture") unless command.include?("--sender R52W90AW7EN")
  abort("expected same observer command capture") unless command.include?("--observer R52W90AW7EN")
  abort("expected M26 incomplete") unless summary.fetch("m26_android_to_android_complete") == false
  abort("expected same-device blocker") unless summary.fetch("m26_completion_blockers").include?("--sender and --observer must be different adb devices")
  abort("expected same-device M26 distinct false") unless summary.fetch("m26_completion_validation").fetch("sender_and_observer_distinct") == false
  provenance = summary.fetch("m26_completion_provenance")
  abort("expected same-device preflight provenance mode") unless provenance.fetch("mode") == "preflight_failed"
  abort("expected same-device real logcat requirement") unless provenance.fetch("real_two_android_logcat_required") == true
 ' "$TMP_DIR/preflight-same-device/summary.json"

grep -q "summary_json.*$TMP_DIR/preflight-same-device/summary.json" "$TMP_DIR/preflight-same-device/summary.md"
grep -q "summary_markdown.*$TMP_DIR/preflight-same-device/summary.md" "$TMP_DIR/preflight-same-device/summary.md"
grep -q "M26 Completion Gate" "$TMP_DIR/preflight-same-device/summary.md"
grep -q "M26 Completion Provenance" "$TMP_DIR/preflight-same-device/summary.md"
grep -q "Requested Role Devices" "$TMP_DIR/preflight-same-device/summary.md"
grep -q "| Device A sender | \`R52W90AW7EN\` | \`R52W90AW7EN\` | \`SM-T577U\` | \`13\` | \`33\` | \`true\` |" "$TMP_DIR/preflight-same-device/summary.md"
grep -q "| Device B observer | \`R52W90AW7EN\` | \`R52W90AW7EN\` | \`SM-T577U\` | \`13\` | \`33\` | \`true\` |" "$TMP_DIR/preflight-same-device/summary.md"
grep -q -- "--sender and --observer must be different adb devices" "$TMP_DIR/preflight-same-device/summary.md"

mkdir -p "$TMP_DIR/fake-bin-two"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'case "$*" in'
  printf '%s\n' '  "devices"|"devices -l")'
  printf '%s\n' '    printf "%s\n" "List of devices attached"'
  printf '%s\n' '    printf "%s\n" "android-a            device usb:1-1 product:a model:Sender device:a transport_id:1"'
  printf '%s\n' '    printf "%s\n" "android-b            device usb:1-2 product:b model:Observer device:b transport_id:2"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "mdns services")'
  printf '%s\n' '    printf "%s\n" "List of discovered mdns services"'
  printf '%s\n' '    printf "%s\n" "meshx-observer _adb-tls-connect._tcp. 192.0.2.10:37099"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.product.model") printf "%s\n" "Sender" ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.build.version.release") printf "%s\n" "13" ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.build.version.sdk") printf "%s\n" "33" ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.product.manufacturer") printf "%s\n" "Acme" ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.product.name") printf "%s\n" "sender" ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.product.device") printf "%s\n" "sender" ;;'
  printf '%s\n' '  "-s android-a shell pm has-feature android.hardware.bluetooth_le") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s android-a shell pm has-feature android.hardware.bluetooth") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.product.model") printf "%s\n" "Observer" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.build.version.release") printf "%s\n" "12" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.build.version.sdk") printf "%s\n" "31" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.product.manufacturer") printf "%s\n" "Acme" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.product.name") printf "%s\n" "observer" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.product.device") printf "%s\n" "observer" ;;'
  printf '%s\n' '  "-s android-b shell pm has-feature android.hardware.bluetooth_le") printf "%s\n" "false" ;;'
  printf '%s\n' '  "-s android-b shell pm has-feature android.hardware.bluetooth") printf "%s\n" "true" ;;'
  printf '%s\n' '  *)'
  printf '%s\n' '    echo "unexpected fake adb call: $*" >&2'
  printf '%s\n' '    exit 99'
  printf '%s\n' '    ;;'
  printf '%s\n' 'esac'
} > "$TMP_DIR/fake-bin-two/adb"
chmod +x "$TMP_DIR/fake-bin-two/adb"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'printf "%s\n" "+-o Android_Sender@01100000  <class IOUSBHostDevice, id 0x1, registered, matched, active, busy 0, retain 37>"'
  printf '%s\n' 'printf "%s\n" "  \"kUSBSerialNumberString\" = \"android-a\""'
  printf '%s\n' 'printf "%s\n" "  \"USB Vendor Name\" = \"Acme\""'
  printf '%s\n' 'printf "%s\n" "  \"USB Product Name\" = \"Android Sender\""'
  printf '%s\n' 'printf "%s\n" "+-o Android_Observer@01200000  <class IOUSBHostDevice, id 0x2, registered, matched, active, busy 0, retain 37>"'
  printf '%s\n' 'printf "%s\n" "  \"kUSBSerialNumberString\" = \"android-b\""'
  printf '%s\n' 'printf "%s\n" "  \"USB Vendor Name\" = \"Acme\""'
  printf '%s\n' 'printf "%s\n" "  \"USB Product Name\" = \"Android Observer\""'
} > "$TMP_DIR/fake-bin-two/ioreg"
chmod +x "$TMP_DIR/fake-bin-two/ioreg"

mkdir -p "$TMP_DIR/fake-bin-ready"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'case "$*" in'
  printf '%s\n' '  "devices"|"devices -l")'
  printf '%s\n' '    printf "%s\n" "List of devices attached"'
  printf '%s\n' '    printf "%s\n" "android-a            device usb:1-1 product:a model:Sender device:a transport_id:1"'
  printf '%s\n' '    printf "%s\n" "android-b            device usb:1-2 product:b model:Observer device:b transport_id:2"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "mdns services")'
  printf '%s\n' '    printf "%s\n" "List of discovered mdns services"'
  printf '%s\n' '    printf "%s\n" "meshx-observer _adb-tls-connect._tcp. 192.0.2.10:37099"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.product.model") printf "%s\n" "Sender" ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.build.version.release") printf "%s\n" "14" ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.build.version.sdk") printf "%s\n" "34" ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.product.manufacturer") printf "%s\n" "Acme" ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.product.name") printf "%s\n" "sender" ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.product.device") printf "%s\n" "sender" ;;'
  printf '%s\n' '  "-s android-a shell pm has-feature android.hardware.bluetooth_le") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s android-a shell pm has-feature android.hardware.bluetooth") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.product.model") printf "%s\n" "Observer" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.build.version.release") printf "%s\n" "13" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.build.version.sdk") printf "%s\n" "33" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.product.manufacturer") printf "%s\n" "Acme" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.product.name") printf "%s\n" "observer" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.product.device") printf "%s\n" "observer" ;;'
  printf '%s\n' '  "-s android-b shell pm has-feature android.hardware.bluetooth_le") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s android-b shell pm has-feature android.hardware.bluetooth") printf "%s\n" "true" ;;'
  printf '%s\n' '  *)'
  printf '%s\n' '    echo "unexpected fake adb call: $*" >&2'
  printf '%s\n' '    exit 99'
  printf '%s\n' '    ;;'
  printf '%s\n' 'esac'
} > "$TMP_DIR/fake-bin-ready/adb"
chmod +x "$TMP_DIR/fake-bin-ready/adb"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'printf "%s\n" "+-o Android_Sender@01100000  <class IOUSBHostDevice, id 0x1, registered, matched, active, busy 0, retain 37>"'
  printf '%s\n' 'printf "%s\n" "  \"kUSBSerialNumberString\" = \"android-a\""'
  printf '%s\n' 'printf "%s\n" "  \"USB Vendor Name\" = \"Acme\""'
  printf '%s\n' 'printf "%s\n" "  \"USB Product Name\" = \"Android Sender\""'
  printf '%s\n' 'printf "%s\n" "+-o Android_Observer@01200000  <class IOUSBHostDevice, id 0x2, registered, matched, active, busy 0, retain 37>"'
  printf '%s\n' 'printf "%s\n" "  \"kUSBSerialNumberString\" = \"android-b\""'
  printf '%s\n' 'printf "%s\n" "  \"USB Vendor Name\" = \"Acme\""'
  printf '%s\n' 'printf "%s\n" "  \"USB Product Name\" = \"Android Observer\""'
} > "$TMP_DIR/fake-bin-ready/ioreg"
chmod +x "$TMP_DIR/fake-bin-ready/ioreg"

PATH="$TMP_DIR/fake-bin-ready:$PATH" "$SCRIPT" \
  --preflight-only \
  --skip-install \
  --sender android-a \
  --observer android-b \
  --out-dir "$TMP_DIR/preflight-ready" \
  > "$TMP_DIR/preflight-ready.out"

grep -q "preflight_ready=true" "$TMP_DIR/preflight-ready.out"
grep -q "preflight_summary=$TMP_DIR/preflight-ready/summary.json" "$TMP_DIR/preflight-ready.out"
test ! -e "$TMP_DIR/preflight-ready/sender.log"
test ! -e "$TMP_DIR/preflight-ready/observer.log"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected preflight_only mode") unless summary.fetch("capture_context").fetch("mode") == "preflight_only"
  abort("expected default preflight wait seconds") unless summary.fetch("capture_context").fetch("wait_for_devices_sec") == 0
  abort("expected sender serial") unless summary.fetch("sender_serial") == "android-a"
  abort("expected observer serial") unless summary.fetch("observer_serial") == "android-b"
  abort("expected adb mdns service count") unless summary.fetch("adb_mdns_service_count") == 1
  abort("expected adb mdns service raw line") unless summary.fetch("adb_mdns_services").first.fetch("raw").include?("_adb-tls-connect._tcp.")
  abort("expected M26 incomplete") unless summary.fetch("m26_android_to_android_complete") == false
  validation = summary.fetch("validation")
  abort("expected two attached devices") unless validation.fetch("two_android_devices_attached") == true
  abort("expected exactly two attached devices") unless validation.fetch("exactly_two_android_devices_attached") == true
  abort("expected sender BLE") unless validation.fetch("sender_ble_le_supported") == true
  abort("expected observer BLE") unless validation.fetch("observer_ble_le_supported") == true
  abort("expected no sender dispatch") unless validation.fetch("sender_attempt_dispatched") == false
  completion = summary.fetch("m26_completion_validation")
  abort("expected preflight-only log distinct false") unless completion.fetch("sender_and_observer_logs_distinct") == false
  abort("expected sender metadata complete") unless completion.fetch("sender_device_metadata_complete") == true
  abort("expected observer metadata complete") unless completion.fetch("observer_device_metadata_complete") == true
  blockers = summary.fetch("m26_completion_blockers")
  expected_blockers = [
    "sender_attempt_dispatched",
    "advertising_set_started",
    "sender_attempt_matches_advertising_set",
    "sender_payload_size_matches",
    "sender_logcat_captured",
    "observer_logcat_captured",
    "observer_scan_started",
    "received_message_logged",
    "observer_m14_consistent",
    "observer_meshx_transport_metadata",
    "payload_match",
    "sender_and_observer_logs_distinct",
    "android_logcat_provenance"
  ]
  abort("expected readiness-only blockers") unless blockers == expected_blockers
  provenance = summary.fetch("m26_completion_provenance")
  abort("expected preflight-only provenance") unless provenance.fetch("mode") == "preflight_only"
  abort("expected real logcat requirement") unless provenance.fetch("real_two_android_logcat_required") == true
  abort("expected host usb candidates") unless summary.fetch("host_usb_android_candidate_count") == 2
  abort("expected android-a host candidate") unless summary.fetch("host_usb_android_candidates").any? { |device| device.fetch("serial") == "android-a" }
' "$TMP_DIR/preflight-ready/summary.json"
assert_m26_completion_schema "$TMP_DIR/preflight-ready/summary.json"

grep -q "MeshX Android BLE Message Delivery Preflight" "$TMP_DIR/preflight-ready/summary.md"
grep -q "preflight_only" "$TMP_DIR/preflight-ready/summary.md"
grep -q "ADB mDNS Services" "$TMP_DIR/preflight-ready/summary.md"
grep -q "meshx-observer _adb-tls-connect._tcp. 192.0.2.10:37099" "$TMP_DIR/preflight-ready/summary.md"
grep -q "Host USB Android Candidates" "$TMP_DIR/preflight-ready/summary.md"
grep -q "sender_device_metadata_complete.*true" "$TMP_DIR/preflight-ready/summary.md"
grep -q "observer_device_metadata_complete.*true" "$TMP_DIR/preflight-ready/summary.md"
grep -q "android_logcat_provenance.*false" "$TMP_DIR/preflight-ready/summary.md"
grep -q "sender_attempt_dispatched" "$TMP_DIR/preflight-ready/summary.md"

PATH="$TMP_DIR/fake-bin-ready:$PATH" "$SCRIPT" \
  --preflight-only \
  --skip-install \
  --out-dir "$TMP_DIR/preflight-ready-auto" \
  > "$TMP_DIR/preflight-ready-auto.out"

grep -q "preflight_ready=true" "$TMP_DIR/preflight-ready-auto.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected auto preflight_only mode") unless summary.fetch("capture_context").fetch("mode") == "preflight_only"
  abort("expected auto sender") unless summary.fetch("sender_serial") == "android-a"
  abort("expected auto observer") unless summary.fetch("observer_serial") == "android-b"
  abort("expected auto command without sender") if summary.fetch("capture_context").fetch("commands").first.include?("--sender")
  abort("expected auto command without observer") if summary.fetch("capture_context").fetch("commands").first.include?("--observer")
  abort("expected auto two devices") unless summary.fetch("validation").fetch("exactly_two_android_devices_attached") == true
  abort("expected auto M26 incomplete") unless summary.fetch("m26_android_to_android_complete") == false
  abort("expected auto radio blockers") unless summary.fetch("m26_completion_blockers").include?("received_message_logged")
' "$TMP_DIR/preflight-ready-auto/summary.json"

mkdir -p "$TMP_DIR/fake-bin-live"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf 'sender_log_fixture=%q\n' "$TMP_DIR/captured-sender.log"
  printf 'observer_log_fixture=%q\n' "$TMP_DIR/captured-observer.log"
  printf '%s\n' 'case "$*" in'
  printf '%s\n' '  "devices"|"devices -l")'
  printf '%s\n' '    printf "%s\n" "List of devices attached"'
  printf '%s\n' '    printf "%s\n" "R52W90AW7EN            device usb:1-1 product:a model:Sender device:a transport_id:1"'
  printf '%s\n' '    printf "%s\n" "R99M26OBSERVER        device usb:1-2 product:b model:Observer device:b transport_id:2"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "mdns services")'
  printf '%s\n' '    printf "%s\n" "List of discovered mdns services"'
  printf '%s\n' '    printf "%s\n" "meshx-observer _adb-tls-connect._tcp. 192.0.2.10:37099"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.product.model") printf "%s\n" "Sender" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.build.version.release") printf "%s\n" "14" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.build.version.sdk") printf "%s\n" "34" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.product.manufacturer") printf "%s\n" "Acme" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.product.name") printf "%s\n" "sender" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.product.device") printf "%s\n" "sender" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell pm has-feature android.hardware.bluetooth_le") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell pm has-feature android.hardware.bluetooth") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell getprop ro.product.model") printf "%s\n" "Observer" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell getprop ro.build.version.release") printf "%s\n" "13" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell getprop ro.build.version.sdk") printf "%s\n" "33" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell getprop ro.product.manufacturer") printf "%s\n" "Acme" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell getprop ro.product.name") printf "%s\n" "observer" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell getprop ro.product.device") printf "%s\n" "observer" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell pm has-feature android.hardware.bluetooth_le") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell pm has-feature android.hardware.bluetooth") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s R52W90AW7EN logcat -c"|"-s R99M26OBSERVER logcat -c") ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell force-stop"*|"-s R99M26OBSERVER shell force-stop"*) ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell am force-stop"*|"-s R99M26OBSERVER shell am force-stop"*) ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell pm grant "*|"-s R99M26OBSERVER shell pm grant "*) ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell am start "*|"-s R99M26OBSERVER shell am start "*) ;;'
  printf '%s\n' "  \"-s R52W90AW7EN logcat -d -s \"*) cat \"\$sender_log_fixture\" ;;"
  printf '%s\n' "  \"-s R99M26OBSERVER logcat -d -s \"*) cat \"\$observer_log_fixture\" ;;"
  printf '%s\n' '  *)'
  printf '%s\n' '    echo "unexpected fake adb call: $*" >&2'
  printf '%s\n' '    exit 99'
  printf '%s\n' '    ;;'
  printf '%s\n' 'esac'
} > "$TMP_DIR/fake-bin-live/adb"
chmod +x "$TMP_DIR/fake-bin-live/adb"
cp "$TMP_DIR/fake-bin-ready/ioreg" "$TMP_DIR/fake-bin-live/ioreg"

PATH="$TMP_DIR/fake-bin-live:$PATH" "$SCRIPT" \
  --skip-install \
  --window 0 \
  --wait-for-devices 2 \
  --observer-ready-timeout 3 \
  --sender "$captured_sender_serial" \
  --observer "$captured_observer_serial" \
  --out-dir "$TMP_DIR/live-summary" \
  > "$TMP_DIR/live-summary.out"

grep -q "observer_scan_ready=true" "$TMP_DIR/live-summary.out"
grep -q "payload_match=true" "$TMP_DIR/live-summary.out"
grep -q "m26_android_to_android_complete=true" "$TMP_DIR/live-summary.out"

"$AUDIT" "$TMP_DIR/live-summary/summary.json" > "$TMP_DIR/audit-live-summary.out"
grep -q "m26_complete=true" "$TMP_DIR/audit-live-summary.out"
grep -q "mode=live" "$TMP_DIR/audit-live-summary.out"
assert_m26_completion_schema "$TMP_DIR/live-summary/summary.json"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["adb_inventory"] = []
  summary["adb_inventory_device_count"] = 0
  summary["adb_ready_device_count"] = 0
  summary["summary_json"] = ARGV.fetch(1)
  File.write(ARGV.fetch(1), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/live-summary/summary.json" "$TMP_DIR/live-missing-adb-inventory-summary.json"

if "$AUDIT" "$TMP_DIR/live-missing-adb-inventory-summary.json" > "$TMP_DIR/audit-live-missing-adb-inventory.out"; then
  echo "expected live missing adb inventory completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-live-missing-adb-inventory.out"
grep -q "live summary adb_inventory missing ready sender R52W90AW7EN" "$TMP_DIR/audit-live-missing-adb-inventory.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["summary_json"] = ARGV.fetch(1)
  summary["m26_completion_provenance"]["live_run"] = false
  File.write(ARGV.fetch(1), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/live-summary/summary.json" "$TMP_DIR/bad-live-run-summary.json"

if "$AUDIT" "$TMP_DIR/bad-live-run-summary.json" > "$TMP_DIR/audit-bad-live-run.out"; then
  echo "expected contradictory live_run completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-bad-live-run.out"
grep -q "live provenance live_run is not true" "$TMP_DIR/audit-bad-live-run.out"
grep -q "summary=$TMP_DIR/bad-live-run-summary.json" "$TMP_DIR/audit-bad-live-run.out"
grep -q "summary_markdown=$TMP_DIR/live-summary/summary.md" "$TMP_DIR/audit-bad-live-run.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["summary_json"] = ARGV.fetch(1)
  summary["m26_completion_provenance"]["verify_only"] = true
  File.write(ARGV.fetch(1), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/live-summary/summary.json" "$TMP_DIR/bad-live-verify-flag-summary.json"

if "$AUDIT" "$TMP_DIR/bad-live-verify-flag-summary.json" > "$TMP_DIR/audit-bad-live-verify-flag.out"; then
  echo "expected contradictory live verify_only completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-bad-live-verify-flag.out"
grep -q "live provenance verify_only is not false" "$TMP_DIR/audit-bad-live-verify-flag.out"
grep -q "summary=$TMP_DIR/bad-live-verify-flag-summary.json" "$TMP_DIR/audit-bad-live-verify-flag.out"
grep -q "summary_markdown=$TMP_DIR/live-summary/summary.md" "$TMP_DIR/audit-bad-live-verify-flag.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["adb_devices_log"] = File.join(File.dirname(summary.fetch("adb_devices_log")), "missing-adb-devices.txt")
  summary["summary_json"] = ARGV.fetch(1)
  File.write(ARGV.fetch(1), JSON.pretty_generate(summary) + "\n")
' "$TMP_DIR/live-summary/summary.json" "$TMP_DIR/live-missing-adb-devices-log-summary.json"

if "$AUDIT" "$TMP_DIR/live-missing-adb-devices-log-summary.json" > "$TMP_DIR/audit-live-missing-adb-devices-log.out"; then
  echo "expected live missing adb devices log completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-live-missing-adb-devices-log.out"
grep -q "live summary adb_devices_log does not exist" "$TMP_DIR/audit-live-missing-adb-devices-log.out"

{
  printf '%s\n' "List of devices attached"
  printf '%s\n' "R52W90AW7EN            device usb:1-1 product:a model:Sender device:a transport_id:1"
} > "$TMP_DIR/live-summary/adb-devices-missing-observer.txt"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  summary["adb_devices_log"] = ARGV.fetch(1)
  summary["summary_json"] = ARGV.fetch(2)
  File.write(ARGV.fetch(2), JSON.pretty_generate(summary) + "\n")
' \
  "$TMP_DIR/live-summary/summary.json" \
  "$TMP_DIR/live-summary/adb-devices-missing-observer.txt" \
  "$TMP_DIR/live-adb-devices-log-missing-observer-summary.json"

if "$AUDIT" "$TMP_DIR/live-adb-devices-log-missing-observer-summary.json" > "$TMP_DIR/audit-live-adb-devices-log-missing-observer.out"; then
  echo "expected live adb devices log missing observer completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-live-adb-devices-log-missing-observer.out"
grep -q "live adb_devices_log missing ready observer R99M26OBSERVER" "$TMP_DIR/audit-live-adb-devices-log-missing-observer.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected live mode") unless summary.fetch("capture_context").fetch("mode") == "live"
  abort("expected live wait seconds") unless summary.fetch("capture_context").fetch("wait_for_devices_sec") == 2
  abort("expected live observer timeout") unless summary.fetch("capture_context").fetch("observer_ready_timeout_sec") == 3
  abort("expected live command capture") unless summary.fetch("capture_context").fetch("commands").first.include?("--wait-for-devices 2")
  abort("expected observer ready command") unless summary.fetch("capture_context").fetch("commands").any? { |command| command.include?("wait up to 3s for Device B scan_start_result accepted=true") }
  abort("expected live adb devices log") unless summary.fetch("adb_devices_log").end_with?("/live-summary/adb-devices.txt")
  abort("expected live adb inventory count") unless summary.fetch("adb_inventory_device_count") == 2
  abort("expected live adb ready count") unless summary.fetch("adb_ready_device_count") == 2
  abort("expected no live adb nonready count") unless summary.fetch("adb_nonready_device_count") == 0
  abort("expected live sender inventory") unless summary.fetch("adb_inventory").any? { |device| device.fetch("serial") == "R52W90AW7EN" && device.fetch("ready") == true }
  abort("expected live observer inventory") unless summary.fetch("adb_inventory").any? { |device| device.fetch("serial") == "R99M26OBSERVER" && device.fetch("ready") == true }
  abort("expected live adb mdns log") unless summary.fetch("adb_mdns_log").end_with?("/live-summary/adb-mdns-services.txt")
  abort("expected live adb mdns service") unless summary.fetch("adb_mdns_service_count") == 1
  abort("expected live host usb log") unless summary.fetch("host_usb_log").end_with?("/live-summary/host-usb.txt")
  abort("expected live host usb candidates") unless summary.fetch("host_usb_android_candidate_count") == 2
  abort("expected live summary json path") unless summary.fetch("summary_json").end_with?("/live-summary/summary.json")
  abort("expected live summary markdown path") unless summary.fetch("summary_markdown").end_with?("/live-summary/summary.md")
  abort("expected sender logcat captured") unless summary.fetch("sender_logcat_capture_failed") == false
  abort("expected observer logcat captured") unless summary.fetch("observer_logcat_capture_failed") == false
  abort("expected live completion") unless summary.fetch("m26_android_to_android_complete") == true
' "$TMP_DIR/live-summary/summary.json"

grep -q "ADB mDNS Services" "$TMP_DIR/live-summary/summary.md"
grep -q "ADB Inventory" "$TMP_DIR/live-summary/summary.md"
grep -q "Host USB Android Candidates" "$TMP_DIR/live-summary/summary.md"
grep -q "observer_ready_timeout_sec.*3" "$TMP_DIR/live-summary/summary.md"
grep -q "adb_inventory_device_count.*2" "$TMP_DIR/live-summary/summary.md"
grep -q "adb_mdns_service_count.*1" "$TMP_DIR/live-summary/summary.md"
grep -q "host_usb_android_candidate_count.*2" "$TMP_DIR/live-summary/summary.md"
grep -q "meshx-observer _adb-tls-connect._tcp. 192.0.2.10:37099" "$TMP_DIR/live-summary/summary.md"

mkdir -p "$TMP_DIR/fake-bin-logcat-fail"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'case "$*" in'
  printf '%s\n' '  "devices"|"devices -l")'
  printf '%s\n' '    printf "%s\n" "List of devices attached"'
  printf '%s\n' '    printf "%s\n" "R52W90AW7EN            device usb:1-1 product:a model:Sender device:a transport_id:1"'
  printf '%s\n' '    printf "%s\n" "R99M26OBSERVER        device usb:1-2 product:b model:Observer device:b transport_id:2"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "mdns services")'
  printf '%s\n' '    printf "%s\n" "List of discovered mdns services"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.product.model") printf "%s\n" "Sender" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.build.version.release") printf "%s\n" "14" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.build.version.sdk") printf "%s\n" "34" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.product.manufacturer") printf "%s\n" "Acme" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.product.name") printf "%s\n" "sender" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell getprop ro.product.device") printf "%s\n" "sender" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell pm has-feature android.hardware.bluetooth_le") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell pm has-feature android.hardware.bluetooth") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell getprop ro.product.model") printf "%s\n" "Observer" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell getprop ro.build.version.release") printf "%s\n" "13" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell getprop ro.build.version.sdk") printf "%s\n" "33" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell getprop ro.product.manufacturer") printf "%s\n" "Acme" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell getprop ro.product.name") printf "%s\n" "observer" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell getprop ro.product.device") printf "%s\n" "observer" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell pm has-feature android.hardware.bluetooth_le") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s R99M26OBSERVER shell pm has-feature android.hardware.bluetooth") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s R52W90AW7EN logcat -c"|"-s R99M26OBSERVER logcat -c") ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell am force-stop"*|"-s R99M26OBSERVER shell am force-stop"*) ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell pm grant "*|"-s R99M26OBSERVER shell pm grant "*) ;;'
  printf '%s\n' '  "-s R52W90AW7EN shell am start "*|"-s R99M26OBSERVER shell am start "*) ;;'
  printf '%s\n' '  "-s R52W90AW7EN logcat -d -s "*|"-s R99M26OBSERVER logcat -d -s "*)'
  printf '%s\n' '    echo "adb: device offline while dumping logcat" >&2'
  printf '%s\n' '    exit 42'
  printf '%s\n' '    ;;'
  printf '%s\n' '  *)'
  printf '%s\n' '    echo "unexpected fake adb call: $*" >&2'
  printf '%s\n' '    exit 99'
  printf '%s\n' '    ;;'
  printf '%s\n' 'esac'
} > "$TMP_DIR/fake-bin-logcat-fail/adb"
chmod +x "$TMP_DIR/fake-bin-logcat-fail/adb"
cp "$TMP_DIR/fake-bin-ready/ioreg" "$TMP_DIR/fake-bin-logcat-fail/ioreg"

set +e
PATH="$TMP_DIR/fake-bin-logcat-fail:$PATH" "$SCRIPT" \
  --skip-install \
  --window 0 \
  --observer-ready-timeout 0 \
  --sender "$captured_sender_serial" \
  --observer "$captured_observer_serial" \
  --out-dir "$TMP_DIR/live-logcat-fail" \
  > "$TMP_DIR/live-logcat-fail.out" 2> "$TMP_DIR/live-logcat-fail.err"
logcat_fail_status=$?
set -e

if [[ "$logcat_fail_status" -eq 0 ]]; then
  echo "expected live logcat capture failure to fail verification" >&2
  exit 1
fi

test -f "$TMP_DIR/live-logcat-fail/summary.json"
grep -q "logcat_capture_failed=true" "$TMP_DIR/live-logcat-fail/sender.log"
grep -q "logcat_capture_failed=true" "$TMP_DIR/live-logcat-fail/observer.log"
grep -q "missing advertising_set_started" "$TMP_DIR/live-logcat-fail.err"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected live mode for failed logcat") unless summary.fetch("capture_context").fetch("mode") == "live"
  abort("expected incomplete failed logcat") unless summary.fetch("m26_android_to_android_complete") == false
  abort("expected sender logcat failure") unless summary.fetch("sender_logcat_capture_failed") == true
  abort("expected observer logcat failure") unless summary.fetch("observer_logcat_capture_failed") == true
  blockers = summary.fetch("m26_completion_blockers")
  abort("expected sender capture blocker") unless blockers.include?("sender_logcat_captured")
  abort("expected observer capture blocker") unless blockers.include?("observer_logcat_captured")
  abort("expected sender attempt blocker") unless blockers.include?("sender_attempt_dispatched")
  abort("expected advertising blocker") unless blockers.include?("advertising_set_started")
  abort("expected received blocker") unless blockers.include?("received_message_logged")
  abort("expected logcat command capture") unless summary.fetch("capture_context").fetch("commands").any? { |command| command.include?("2>&1 || true") }
' "$TMP_DIR/live-logcat-fail/summary.json"

mkdir -p "$TMP_DIR/fake-bin-wait"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf 'count_file=%q\n' "$TMP_DIR/fake-bin-wait/devices.count"
  printf '%s\n' 'case "$*" in'
  printf '%s\n' '  "devices"|"devices -l")'
  printf '%s\n' '    count=0'
  printf '%s\n' "    if [[ -f \"\$count_file\" ]]; then count=\"\$(cat \"\$count_file\")\"; fi"
  printf '%s\n' "    count=\$((count + 1))"
  printf '%s\n' "    printf \"%s\" \"\$count\" > \"\$count_file\""
  printf '%s\n' '    printf "%s\n" "List of devices attached"'
  printf '%s\n' '    printf "%s\n" "android-a            device usb:1-1 product:a model:Sender device:a transport_id:1"'
  printf '%s\n' "    if [[ \"\$count\" -gt 1 ]]; then"
  printf '%s\n' '      printf "%s\n" "android-b            device usb:1-2 product:b model:Observer device:b transport_id:2"'
  printf '%s\n' '    fi'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "mdns services")'
  printf '%s\n' '    printf "%s\n" "List of discovered mdns services"'
  printf '%s\n' '    printf "%s\n" "meshx-observer _adb-tls-connect._tcp. 192.0.2.10:37099"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.product.model") printf "%s\n" "Sender" ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.build.version.release") printf "%s\n" "14" ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.build.version.sdk") printf "%s\n" "34" ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.product.manufacturer") printf "%s\n" "Acme" ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.product.name") printf "%s\n" "sender" ;;'
  printf '%s\n' '  "-s android-a shell getprop ro.product.device") printf "%s\n" "sender" ;;'
  printf '%s\n' '  "-s android-a shell pm has-feature android.hardware.bluetooth_le") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s android-a shell pm has-feature android.hardware.bluetooth") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.product.model") printf "%s\n" "Observer" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.build.version.release") printf "%s\n" "13" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.build.version.sdk") printf "%s\n" "33" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.product.manufacturer") printf "%s\n" "Acme" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.product.name") printf "%s\n" "observer" ;;'
  printf '%s\n' '  "-s android-b shell getprop ro.product.device") printf "%s\n" "observer" ;;'
  printf '%s\n' '  "-s android-b shell pm has-feature android.hardware.bluetooth_le") printf "%s\n" "true" ;;'
  printf '%s\n' '  "-s android-b shell pm has-feature android.hardware.bluetooth") printf "%s\n" "true" ;;'
  printf '%s\n' '  *)'
  printf '%s\n' '    echo "unexpected fake adb call: $*" >&2'
  printf '%s\n' '    exit 99'
  printf '%s\n' '    ;;'
  printf '%s\n' 'esac'
} > "$TMP_DIR/fake-bin-wait/adb"
chmod +x "$TMP_DIR/fake-bin-wait/adb"
cp "$TMP_DIR/fake-bin-ready/ioreg" "$TMP_DIR/fake-bin-wait/ioreg"

PATH="$TMP_DIR/fake-bin-wait:$PATH" "$SCRIPT" \
  --preflight-only \
  --skip-install \
  --wait-for-devices 2 \
  --out-dir "$TMP_DIR/preflight-wait-ready" \
  > "$TMP_DIR/preflight-wait-ready.out"

grep -q "preflight_ready=true" "$TMP_DIR/preflight-wait-ready.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected wait preflight_only mode") unless summary.fetch("capture_context").fetch("mode") == "preflight_only"
  abort("expected wait seconds") unless summary.fetch("capture_context").fetch("wait_for_devices_sec") == 2
  abort("expected wait command capture") unless summary.fetch("capture_context").fetch("commands").first.include?("--wait-for-devices 2")
  abort("expected waited adb mdns service") unless summary.fetch("adb_mdns_service_count") == 1
  abort("expected waited auto sender") unless summary.fetch("sender_serial") == "android-a"
  abort("expected waited auto observer") unless summary.fetch("observer_serial") == "android-b"
  abort("expected waited two devices") unless summary.fetch("validation").fetch("exactly_two_android_devices_attached") == true
  abort("expected waited M26 incomplete") unless summary.fetch("m26_android_to_android_complete") == false
' "$TMP_DIR/preflight-wait-ready/summary.json"

if PATH="$TMP_DIR/fake-bin-two:$PATH" "$SCRIPT" \
  --skip-install \
  --sender android-a \
  --observer android-b \
  --out-dir "$TMP_DIR/preflight-ble-missing" \
  > "$TMP_DIR/preflight-ble-missing.out" 2> "$TMP_DIR/preflight-ble-missing.err"; then
  echo "expected missing BLE LE preflight to fail" >&2
  exit 1
fi

grep -q "required BLE LE feature missing" "$TMP_DIR/preflight-ble-missing.err"
grep -q "Device B observer android-b bluetooth_le_feature=\"false\"" "$TMP_DIR/preflight-ble-missing.err"
grep -q "preflight_adb_mdns_service_count=1" "$TMP_DIR/preflight-ble-missing.err"
grep -q "preflight_host_usb_android_candidate_count=2" "$TMP_DIR/preflight-ble-missing.err"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected preflight_failed mode") unless summary.fetch("capture_context").fetch("mode") == "preflight_failed"
  abort("expected BLE failure") unless summary.fetch("error").include?("required BLE LE feature missing")
  abort("expected two devices attached") unless summary.fetch("validation").fetch("two_android_devices_attached") == true
  abort("expected exactly two devices attached") unless summary.fetch("validation").fetch("exactly_two_android_devices_attached") == true
  abort("expected sender BLE supported") unless summary.fetch("validation").fetch("sender_ble_le_supported") == true
  abort("expected observer BLE unsupported") unless summary.fetch("validation").fetch("observer_ble_le_supported") == false
  observer = summary.fetch("attached_devices").find { |device| device.fetch("serial") == "android-b" }
  abort("expected observer device") unless observer
  abort("expected observer BLE false") unless observer.fetch("bluetooth_le_feature") == "false"
  abort("expected two host usb candidates") unless summary.fetch("host_usb_android_candidate_count") == 2
  abort("expected android-b host usb candidate") unless summary.fetch("host_usb_android_candidates").any? { |device| device.fetch("serial") == "android-b" }
' "$TMP_DIR/preflight-ble-missing/summary.json"

if "$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender android-a \
  --observer android-b \
  --sender-log "$FIXTURES/sender_missing_attempt_outcome.log" \
  --observer-log "$FIXTURES/observer.log" \
  --summary-json "$TMP_DIR/missing-attempt-summary.json" \
  > "$TMP_DIR/missing-attempt.out" 2> "$TMP_DIR/missing-attempt.err"; then
  echo "expected missing attempt_outcome verification to fail" >&2
  exit 1
fi

grep -q "missing dispatched attempt_outcome" "$TMP_DIR/missing-attempt.err"

if "$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender android-a \
  --observer android-b \
  --sender-log "$FIXTURES/sender_mismatched_attempt_id.log" \
  --observer-log "$FIXTURES/observer.log" \
  --summary-json "$TMP_DIR/mismatched-attempt-summary.json" \
  > "$TMP_DIR/mismatched-attempt.out" 2> "$TMP_DIR/mismatched-attempt.err"; then
  echo "expected mismatched sender attempt_id verification to fail" >&2
  exit 1
fi

grep -q "attempt_id .* does not match advertising_set_started attempt_id" "$TMP_DIR/mismatched-attempt.err"

ruby -rjson -e '
  path = ARGV.fetch(0)
  lines = File.readlines(path).map do |line|
    match = line.match(/\{.*\}/)
    next line unless match

    event = JSON.parse(match[0])
    if event["event"] == "attempt_outcome"
      event["message_id"] = "AAAAAAAAAAAAAAAAAAAAAA=="
    end
    line.sub(/\{.*\}/, JSON.generate(event))
  end
  File.write(ARGV.fetch(1), lines.join)
' "$FIXTURES/sender.log" "$TMP_DIR/sender-mismatched-attempt-message-id.log"

if "$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender android-a \
  --observer android-b \
  --sender-log "$TMP_DIR/sender-mismatched-attempt-message-id.log" \
  --observer-log "$FIXTURES/observer.log" \
  --summary-json "$TMP_DIR/mismatched-attempt-message-id-summary.json" \
  > "$TMP_DIR/mismatched-attempt-message-id.out" 2> "$TMP_DIR/mismatched-attempt-message-id.err"; then
  echo "expected mismatched sender attempt_outcome message_id verification to fail" >&2
  exit 1
fi

grep -q "attempt_outcome message_id does not match advertising_set_started payload" "$TMP_DIR/mismatched-attempt-message-id.err"

ruby -rjson -e '
  path = ARGV.fetch(0)
  lines = File.readlines(path).map do |line|
    match = line.match(/\{.*\}/)
    next line unless match

    event = JSON.parse(match[0])
    event["target_peer_id"] = "meshx-wrong" if event["event"] == "attempt_outcome"
    line.sub(/\{.*\}/, JSON.generate(event))
  end
  File.write(ARGV.fetch(1), lines.join)
' "$FIXTURES/sender.log" "$TMP_DIR/sender-mismatched-attempt-target-peer.log"

if "$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender android-a \
  --observer android-b \
  --sender-log "$TMP_DIR/sender-mismatched-attempt-target-peer.log" \
  --observer-log "$FIXTURES/observer.log" \
  --summary-json "$TMP_DIR/mismatched-attempt-target-peer-summary.json" \
  > "$TMP_DIR/mismatched-attempt-target-peer.out" 2> "$TMP_DIR/mismatched-attempt-target-peer.err"; then
  echo "expected mismatched sender attempt_outcome target_peer_id verification to fail" >&2
  exit 1
fi

grep -q "attempt_outcome target_peer_id does not match advertising_set_started payload recipient" "$TMP_DIR/mismatched-attempt-target-peer.err"

ruby -rjson -e '
  path = ARGV.fetch(0)
  lines = File.readlines(path).map do |line|
    match = line.match(/\{.*\}/)
    next line unless match

    event = JSON.parse(match[0])
    event.delete("message_id") if event["event"] == "attempt_outcome"
    line.sub(/\{.*\}/, JSON.generate(event))
  end
  File.write(ARGV.fetch(1), lines.join)
' "$FIXTURES/sender.log" "$TMP_DIR/sender-missing-attempt-message-id.log"

if "$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender android-a \
  --observer android-b \
  --sender-log "$TMP_DIR/sender-missing-attempt-message-id.log" \
  --observer-log "$FIXTURES/observer.log" \
  --summary-json "$TMP_DIR/missing-attempt-message-id-summary.json" \
  > "$TMP_DIR/missing-attempt-message-id.out" 2> "$TMP_DIR/missing-attempt-message-id.err"; then
  echo "expected missing sender attempt_outcome message_id verification to fail" >&2
  exit 1
fi

grep -q "attempt_outcome message_id is missing" "$TMP_DIR/missing-attempt-message-id.err"

ruby -rjson -e '
  path = ARGV.fetch(0)
  lines = File.readlines(path).map do |line|
    match = line.match(/\{.*\}/)
    next line unless match

    event = JSON.parse(match[0])
    event.delete("target_device_ids") if event["event"] == "attempt_outcome"
    line.sub(/\{.*\}/, JSON.generate(event))
  end
  File.write(ARGV.fetch(1), lines.join)
' "$FIXTURES/sender.log" "$TMP_DIR/sender-missing-attempt-target-devices.log"

if "$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender android-a \
  --observer android-b \
  --sender-log "$TMP_DIR/sender-missing-attempt-target-devices.log" \
  --observer-log "$FIXTURES/observer.log" \
  --summary-json "$TMP_DIR/missing-attempt-target-devices-summary.json" \
  > "$TMP_DIR/missing-attempt-target-devices.out" 2> "$TMP_DIR/missing-attempt-target-devices.err"; then
  echo "expected missing sender attempt_outcome target_device_ids verification to fail" >&2
  exit 1
fi

grep -q "attempt_outcome target_device_ids is missing or invalid" "$TMP_DIR/missing-attempt-target-devices.err"

if "$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender android-a \
  --observer android-b \
  --sender-log "$FIXTURES/sender_bad_payload_size.log" \
  --observer-log "$FIXTURES/observer.log" \
  --summary-json "$TMP_DIR/bad-payload-size-summary.json" \
  > "$TMP_DIR/bad-payload-size.out" 2> "$TMP_DIR/bad-payload-size.err"; then
  echo "expected bad payload_size verification to fail" >&2
  exit 1
fi

grep -q "payload_size 59 does not match decoded payload bytes 60" "$TMP_DIR/bad-payload-size.err"

if "$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender android-a \
  --observer android-b \
  --sender-log "$FIXTURES/sender.log" \
  --observer-log "$FIXTURES/observer_missing_scan_start.log" \
  --summary-json "$TMP_DIR/missing-scan-summary.json" \
  > "$TMP_DIR/fail.out" 2> "$TMP_DIR/fail.err"; then
  echo "expected missing scan-start verification to fail" >&2
  exit 1
fi

grep -q "missing Device B scan_start_result accepted=true" "$TMP_DIR/fail.err"

grep -v "scan_start_result" "$FIXTURES/observer.log" > "$TMP_DIR/observer-without-scan-start.log"

"$SCRIPT" \
  --verify-only \
  --sender android-a \
  --observer android-b \
  --sender-log "$FIXTURES/sender.log" \
  --observer-log "$TMP_DIR/observer-without-scan-start.log" \
  --summary-json "$TMP_DIR/supporting-proof-summary.json" \
  > "$TMP_DIR/supporting-proof.out"

grep -q "payload_match=true" "$TMP_DIR/supporting-proof.out"
grep -q "m26_android_to_android_complete=false" "$TMP_DIR/supporting-proof.out"
grep -q "m26_completion_blockers=.*observer_scan_started" "$TMP_DIR/supporting-proof.out"

ruby -rjson -e '
  summary = JSON.parse(File.read(ARGV.fetch(0)))
  abort("expected payload_match") unless summary.fetch("payload_match") == true
  abort("expected missing scan start") unless summary.fetch("observer_scan_started") == false
  abort("expected M26 incomplete") unless summary.fetch("m26_android_to_android_complete") == false
  blockers = summary.fetch("m26_completion_blockers")
  abort("expected observer_scan_started blocker") unless blockers.include?("observer_scan_started")
  abort("expected require_scan_start blocker") unless blockers.include?("require_scan_start")
' "$TMP_DIR/supporting-proof-summary.json"

if "$AUDIT" "$TMP_DIR/supporting-proof-summary.json" > "$TMP_DIR/audit-supporting-proof.out"; then
  echo "expected supporting proof completion audit to fail" >&2
  exit 1
fi

grep -q "m26_complete=false" "$TMP_DIR/audit-supporting-proof.out"

if "$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender android-a \
  --observer android-b \
  --sender-log "$FIXTURES/sender.log" \
  --observer-log "$FIXTURES/observer_mismatched_envelope.log" \
  --summary-json "$TMP_DIR/mismatch-summary.json" \
  > "$TMP_DIR/mismatch.out" 2> "$TMP_DIR/mismatch.err"; then
  echo "expected payload mismatch verification to fail" >&2
  exit 1
fi

grep -q "payload mismatch" "$TMP_DIR/mismatch.err"

if "$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender android-a \
  --observer android-b \
  --sender-log "$FIXTURES/sender.log" \
  --observer-log "$FIXTURES/observer_wrong_company_identifier.log" \
  --summary-json "$TMP_DIR/wrong-company-summary.json" \
  > "$TMP_DIR/wrong-company.out" 2> "$TMP_DIR/wrong-company.err"; then
  echo "expected wrong company_identifier verification to fail" >&2
  exit 1
fi

grep -q "company_identifier is not 65535" "$TMP_DIR/wrong-company.err"

if "$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender android-a \
  --observer android-b \
  --sender-log "$FIXTURES/sender.log" \
  --observer-log "$FIXTURES/observer_detached_manufacturer_data.log" \
  --summary-json "$TMP_DIR/detached-manufacturer-summary.json" \
  > "$TMP_DIR/detached-manufacturer.out" 2> "$TMP_DIR/detached-manufacturer.err"; then
  echo "expected detached manufacturer_data verification to fail" >&2
  exit 1
fi

grep -q "advertisement does not contain manufacturer_data" "$TMP_DIR/detached-manufacturer.err"

if "$SCRIPT" \
  --verify-only \
  --require-scan-start \
  --sender android-a \
  --observer android-b \
  --sender-log "$FIXTURES/sender.log" \
  --observer-log "$FIXTURES/observer_inconsistent_event.log" \
  --summary-json "$TMP_DIR/inconsistent-summary.json" \
  > "$TMP_DIR/inconsistent.out" 2> "$TMP_DIR/inconsistent.err"; then
  echo "expected inconsistent received_message verification to fail" >&2
  exit 1
fi

grep -q "message_id does not match envelope" "$TMP_DIR/inconsistent.err"

echo "android_ble_message_delivery_two_device verifier tests passed"
