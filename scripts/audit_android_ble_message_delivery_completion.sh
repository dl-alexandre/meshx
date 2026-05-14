#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/audit_android_ble_message_delivery_completion.sh <summary.json>

Exits 0 only when the supplied two-Android verifier summary satisfies the
M26 completion gate: m26_android_to_android_complete=true, no blockers,
all required m26_completion_validation checks true, self-identifying
summary_json provenance, non-fixture provenance, distinct sender/observer
serials, and existing non-fixture sender/observer log files that are
distinct from each other and have full Android
`adb logcat -d` timestamp/pid/tid/tag provenance, plus model/API/BLE
metadata for both Android devices and an existing summary_markdown ledger. The
referenced logs must have been captured successfully and revalidated with the
two-device verifier before the audit passes.

When rejecting a parsed summary object, failure output includes the audited
summary path, the recorded summary_markdown path when present, captured
adb/mDNS/USB inventory log paths (adb_devices_log, adb_mdns_log, host_usb_log),
and any captured adb_ready_device_count, adb_nonready_device_count,
adb_mdns_service_count, and host_usb_android_candidate_count values so blockers
can be read without opening summary.json.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$#" -ne 1 ]]; then
  usage >&2
  exit 2
fi

summary_json="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFIER="$ROOT/scripts/android_ble_message_delivery_two_device.sh"

if [[ ! -f "$summary_json" ]]; then
  echo "m26_complete=false"
  echo "reason=summary not found: $summary_json"
  echo "summary=$summary_json"
  exit 2
fi

ruby -rdigest -rjson -rtmpdir - "$summary_json" "$VERIFIER" <<'RUBY'
summary_path = ARGV.fetch(0)
verifier = ARGV.fetch(1)
fixture_dir = File.expand_path("fixtures/android_ble_message_delivery", File.dirname(verifier))
$audited_summary_path = summary_path
$audited_summary = nil

def fail_gate(reason)
  puts "m26_complete=false"
  puts "reason=#{reason}"
  blockers = $audited_summary && $audited_summary["m26_completion_blockers"]
  puts "blockers=#{blockers.join(",")}" if blockers.is_a?(Array) && !blockers.empty?
  if $audited_summary
    print_failure_diagnostics($audited_summary, $audited_summary_path)
  else
    puts "summary=#{$audited_summary_path}" if $audited_summary_path
  end
  exit 1
end

def print_failure_diagnostics(summary, summary_path)
  puts "summary=#{summary_path}"
  summary_markdown = summary["summary_markdown"].to_s
  puts "summary_markdown=#{summary_markdown}" unless summary_markdown.empty?

  [
    "adb_devices_log",
    "adb_mdns_log",
    "host_usb_log"
  ].each do |key|
    next unless summary.key?(key)

    value = summary[key]
    puts "#{key}=#{value}" unless value.nil? || value.to_s.empty?
  end

  [
    "adb_ready_device_count",
    "adb_nonready_device_count",
    "adb_mdns_service_count",
    "host_usb_android_candidate_count"
  ].each do |key|
    next unless summary.key?(key)

    value = summary[key]
    puts "#{key}=#{value}" unless value.nil?
  end
end

def ready_adb_serials_from_log(path)
  File.readlines(path).filter_map do |line|
    columns = line.split
    next if columns.empty? || columns[0] == "List"

    columns[0] if columns[1] == "device"
  end
end

def same_file?(left, right)
  return true if File.expand_path(left) == File.expand_path(right)
  return File.identical?(left, right) if File.file?(left) && File.file?(right)

  false
rescue
  false
end

summary =
  begin
    JSON.parse(File.read(summary_path))
  rescue JSON::ParserError => e
    fail_gate("summary is not valid JSON: #{e.message}")
  end

fail_gate("summary JSON root is not an object") unless summary.is_a?(Hash)
$audited_summary = summary

unless summary["m26_android_to_android_complete"] == true
  if summary["legacy_beacon_delivery_complete"] == true
    legacy_validation = summary["legacy_beacon_completion_validation"]
    unless legacy_validation.is_a?(Hash) && legacy_validation.values.all? { |value| value == true }
      fail_gate("legacy_beacon_completion_validation has non-true checks")
    end
    legacy_blockers = summary["legacy_beacon_completion_blockers"]
    unless legacy_blockers.is_a?(Array) && legacy_blockers.empty?
      fail_gate("legacy_beacon_completion_blockers is not empty")
    end

    puts "m26_complete=false"
    puts "full_envelope_delivery_complete=#{summary["full_envelope_delivery_complete"] == true}"
    puts "legacy_beacon_delivery_complete=true"
    blockers = summary["full_envelope_completion_blockers"]
    puts "full_envelope_blockers=#{blockers.join(",")}" if blockers.is_a?(Array)
    print_failure_diagnostics(summary, summary_path)
    exit 0
  end

  puts "m26_complete=false"
  puts "reason=m26_android_to_android_complete is not true"
  blockers = summary["m26_completion_blockers"]
  puts "blockers=#{blockers.join(",")}" if blockers.is_a?(Array)
  print_failure_diagnostics(summary, summary_path)
  exit 1
end

recorded_summary_json = summary["summary_json"].to_s
fail_gate("summary_json is missing") if recorded_summary_json.empty?

unless File.expand_path(recorded_summary_json) == File.expand_path(summary_path)
  fail_gate("summary_json does not match audited path: #{recorded_summary_json}")
end

summary_markdown = summary["summary_markdown"].to_s
fail_gate("summary_markdown is missing") if summary_markdown.empty?

unless File.file?(summary_markdown)
  fail_gate("summary_markdown does not exist: #{summary_markdown}")
end

blockers = summary["m26_completion_blockers"]
fail_gate("m26_completion_blockers is not an empty array") unless blockers.is_a?(Array) && blockers.empty?

validation = summary["m26_completion_validation"]
fail_gate("m26_completion_validation is missing") unless validation.is_a?(Hash)

required_validation_checks = [
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
  "sender_and_observer_distinct",
  "sender_and_observer_logs_distinct",
  "sender_device_metadata_complete",
  "observer_device_metadata_complete",
  "require_scan_start",
  "android_logcat_provenance",
  "not_repo_fixture_log_pair"
]
missing_checks = required_validation_checks - validation.keys
unless missing_checks.empty?
  fail_gate("m26_completion_validation is missing required checks: #{missing_checks.join(",")}")
end

failed_checks = validation.select { |_name, value| value != true }.keys
fail_gate("m26_completion_validation has non-true checks: #{failed_checks.join(",")}") unless failed_checks.empty?

unless summary["sender_logcat_capture_failed"] == false
  fail_gate("sender_logcat_capture_failed is not false")
end

unless summary["observer_logcat_capture_failed"] == false
  fail_gate("observer_logcat_capture_failed is not false")
end

provenance = summary["m26_completion_provenance"]
fail_gate("m26_completion_provenance is missing") unless provenance.is_a?(Hash)
fail_gate("repo_fixture_log_pair is true") unless provenance["repo_fixture_log_pair"] == false
fail_gate("real_two_android_logcat_required is not true") unless provenance["real_two_android_logcat_required"] == true

mode = provenance["mode"]
fail_gate("mode is not live or verify_only: #{mode.inspect}") unless ["live", "verify_only"].include?(mode)

case mode
when "live"
  fail_gate("live provenance live_run is not true") unless provenance["live_run"] == true
  fail_gate("live provenance verify_only is not false") unless provenance["verify_only"] == false
when "verify_only"
  fail_gate("verify_only provenance live_run is not false") unless provenance["live_run"] == false
  fail_gate("verify_only provenance verify_only is not true") unless provenance["verify_only"] == true
end

sender_serial = summary["sender_serial"]
observer_serial = summary["observer_serial"]
fail_gate("sender_serial is missing") if sender_serial.to_s.empty?
fail_gate("observer_serial is missing") if observer_serial.to_s.empty?
fail_gate("sender_serial and observer_serial are not distinct") if sender_serial == observer_serial

if mode == "live"
  inventory = summary["adb_inventory"]
  fail_gate("live summary adb_inventory is missing") unless inventory.is_a?(Array)

  ready_serials = inventory.filter_map do |device|
    next unless device.is_a?(Hash)
    next unless device["state"] == "device" && device["ready"] == true

    device["serial"]
  end

  unless ready_serials.include?(sender_serial)
    fail_gate("live summary adb_inventory missing ready sender #{sender_serial}")
  end

  unless ready_serials.include?(observer_serial)
    fail_gate("live summary adb_inventory missing ready observer #{observer_serial}")
  end

  adb_devices_log = summary["adb_devices_log"].to_s
  fail_gate("live summary adb_devices_log is missing") if adb_devices_log.empty?

  unless File.file?(adb_devices_log)
    fail_gate("live summary adb_devices_log does not exist: #{adb_devices_log}")
  end

  ready_log_serials = ready_adb_serials_from_log(adb_devices_log)

  unless ready_log_serials.include?(sender_serial)
    fail_gate("live adb_devices_log missing ready sender #{sender_serial}")
  end

  unless ready_log_serials.include?(observer_serial)
    fail_gate("live adb_devices_log missing ready observer #{observer_serial}")
  end
end

fixture_serials = ["android-a", "android-b"]
fail_gate("sender_serial is a known verifier fixture serial") if fixture_serials.include?(sender_serial)
fail_gate("observer_serial is a known verifier fixture serial") if fixture_serials.include?(observer_serial)

def require_device_metadata(summary, key, expected_serial)
  device = summary[key]
  fail_gate("#{key} is missing") unless device.is_a?(Hash)
  fail_gate("#{key}.serial does not match #{expected_serial}") unless device["serial"] == expected_serial

  ["model", "android_release", "android_sdk"].each do |field|
    fail_gate("#{key}.#{field} is missing") if device[field].to_s.empty?
  end

  unless device["android_sdk"].to_s.match?(/\A\d+\z/)
    fail_gate("#{key}.android_sdk is not numeric")
  end

  unless device["bluetooth_le_feature"] == "true"
    fail_gate("#{key}.bluetooth_le_feature is not true")
  end

  device
end

sender_device = require_device_metadata(summary, "sender_device", sender_serial)
observer_device = require_device_metadata(summary, "observer_device", observer_serial)

fixture_models = ["Fixture Sender", "Fixture Observer"]
if fixture_models.include?(sender_device["model"])
  fail_gate("sender_device.model is a known verifier fixture model")
end
if fixture_models.include?(observer_device["model"])
  fail_gate("observer_device.model is a known verifier fixture model")
end

sender_log = summary["sender_log"]
observer_log = summary["observer_log"]
fail_gate("sender_log is missing") if sender_log.to_s.empty?
fail_gate("observer_log is missing") if observer_log.to_s.empty?

def repo_fixture_log?(path)
  File.expand_path(path).include?("#{File::SEPARATOR}scripts#{File::SEPARATOR}fixtures#{File::SEPARATOR}")
end

def json_from(line)
  match = line.match(/\{.*\}/)
  return nil unless match

  JSON.parse(match[0])
rescue JSON::ParserError
  nil
end

def log_event_fingerprint(path)
  events =
    File.readlines(path).filter_map do |line|
      event = json_from(line)
      JSON.generate(event) if event
    end

  Digest::SHA256.hexdigest(events.join("\n"))
end

def fixture_content_match?(path, fixture_dir)
  return false unless File.directory?(fixture_dir)

  digest = log_event_fingerprint(path)
  Dir.glob(File.join(fixture_dir, "*.log")).any? do |fixture_path|
    log_event_fingerprint(fixture_path) == digest
  end
end

def first_event(path, event_name)
  File.readlines(path).each do |line|
    event = json_from(line)
    return event if event && event["event"] == event_name
  end

  nil
end

fail_gate("sender_log is a checked-in fixture: #{sender_log}") if repo_fixture_log?(sender_log)
fail_gate("observer_log is a checked-in fixture: #{observer_log}") if repo_fixture_log?(observer_log)

unless File.file?(sender_log)
  fail_gate("sender_log does not exist: #{sender_log}")
end

unless File.file?(observer_log)
  fail_gate("observer_log does not exist: #{observer_log}")
end

if same_file?(sender_log, observer_log)
  fail_gate("sender_log and observer_log must be different files")
end

if fixture_content_match?(sender_log, fixture_dir)
  fail_gate("sender_log content matches a checked-in verifier fixture: #{sender_log}")
end

if fixture_content_match?(observer_log, fixture_dir)
  fail_gate("observer_log content matches a checked-in verifier fixture: #{observer_log}")
end

observer_received_message = first_event(observer_log, "received_message")
if observer_received_message && observer_received_message["received_device_id"] == "AA:BB:CC:DD:EE:02"
  fail_gate("observer_log uses known verifier fixture received_device_id")
end
observer_raw_metadata =
  observer_received_message && observer_received_message["raw_transport_metadata"]
if observer_raw_metadata.is_a?(Hash) &&
   observer_raw_metadata["received_device_id"] == "AA:BB:CC:DD:EE:02"
  fail_gate("observer_log uses known verifier fixture raw_transport_metadata.received_device_id")
end

Dir.mktmpdir("meshx-m26-audit-") do |dir|
  revalidation_summary = File.join(dir, "summary.json")
  verified =
    system(
      verifier,
      "--verify-only",
      "--require-scan-start",
      "--sender", sender_serial,
      "--observer", observer_serial,
      "--sender-log", sender_log,
      "--observer-log", observer_log,
      "--summary-json", revalidation_summary,
      "--sender-device-json", JSON.generate(sender_device),
      "--observer-device-json", JSON.generate(observer_device),
      out: File::NULL,
      err: File::NULL
    )

  unless verified
    puts "m26_complete=false"
    puts "reason=referenced logs failed verifier revalidation"
    print_failure_diagnostics(summary, summary_path)
    exit 1
  end

  revalidated =
    begin
      JSON.parse(File.read(revalidation_summary))
    rescue JSON::ParserError, Errno::ENOENT => e
      fail_gate("log revalidation summary is unavailable: #{e.message}")
    end

  unless revalidated["m26_android_to_android_complete"] == true
    revalidation_blockers = revalidated["m26_completion_blockers"]
    puts "m26_complete=false"
    puts "reason=log revalidation did not satisfy M26 completion"
    puts "blockers=#{revalidation_blockers.join(",")}" if revalidation_blockers.is_a?(Array)
    print_failure_diagnostics(summary, summary_path)
    exit 1
  end
end

puts "m26_complete=true"
puts "summary=#{summary_path}"
puts "mode=#{mode}"
puts "sender_serial=#{sender_serial}"
puts "observer_serial=#{observer_serial}"
RUBY
