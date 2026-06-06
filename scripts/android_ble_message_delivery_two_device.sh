#!/usr/bin/env bash
set -euo pipefail

APP_ID="dev.mob.mob"
MAIN_ACTIVITY="dev.mob.mob/.MainActivity"
SCAN_WINDOW_SEC=8
OBSERVER_READY_TIMEOUT_SEC=10
OBSERVER_SETTLE_SEC=2
INSTALL=1
SENDER_SERIAL=""
OBSERVER_SERIAL=""
OUT_DIR=""
VERIFY_ONLY=0
PREFLIGHT_ONLY=0
REQUIRE_SCAN_START=0
LEGACY_BEACON=0
WAIT_FOR_DEVICES_SEC=0
SENDER_LOG=""
OBSERVER_LOG=""
SUMMARY_JSON=""
SENDER_DEVICE_JSON=""
OBSERVER_DEVICE_JSON=""
ADB_DEVICES_LOG=""
ADB_MDNS_LOG=""
HOST_USB_LOG=""
COMMANDS_JSON="[]"
ORIGINAL_ARGS=("$@")

usage() {
  cat <<'EOF'
Usage:
  scripts/android_ble_message_delivery_two_device.sh [--sender <adb-serial> --observer <adb-serial>] [options]

Options:
  --sender <serial>       Android Device A. Dispatches the fixed M14 test envelope.
  --observer <serial>     Android Device B. Starts the MeshX BLE scan path.
  --window <seconds>      Seconds to wait after dispatch before dumping logcat. Default: 8.
  --observer-ready-timeout <seconds>
                          Seconds to wait for Device B scan_start_result accepted=true before dispatch. Default: 10; 0 skips.
  --observer-settle <seconds>
                          Seconds to wait after scan readiness before dispatch. Default: 2.
  --out-dir <path>        Directory for logcat, inventory, summary.json, and summary.md artifacts.
  --skip-install          Do not build/install the debug APK before validation.
  --preflight-only        Record two-device readiness artifacts, then exit before radio work.
  --wait-for-devices <s>  Wait up to this many seconds for required adb devices before preflight fails.
  --verify-only           Only verify existing log files; do not touch adb/radio.
  --require-scan-start    Require Device B scan_start_result accepted=true.
  --legacy-beacon         Dispatch compact legacy message beacon instead of full M14 envelope.
  --sender-log <path>     Existing Device A logcat file for --verify-only.
  --observer-log <path>   Existing Device B logcat file for --verify-only.
  --summary-json <path>   Summary JSON path for --verify-only.
  --sender-device-json <json>
                          Device A metadata JSON for --verify-only summaries.
  --observer-device-json <json>
                          Device B metadata JSON for --verify-only summaries.
  -h, --help              Show this help.

If exactly two adb devices are attached, --sender/--observer may be omitted
and the script will use the first as sender and the second as observer.
summary.json includes m26_android_to_android_complete,
m26_completion_blockers, and m26_completion_provenance; only
m26_android_to_android_complete=true with no blockers passes the verifier
gate. Final M26 completion still requires real two-Android logcat
provenance. Preflight failures also print preflight_adb_mdns_service_count
and preflight_host_usb_android_candidate_count beside the generated summary
paths for immediate adb/USB discovery context. Run
scripts/audit_android_ble_message_delivery_completion.sh <summary.json>
for a machine-checkable completion gate.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sender)
      SENDER_SERIAL="${2:?missing sender serial}"
      shift 2
      ;;
    --observer)
      OBSERVER_SERIAL="${2:?missing observer serial}"
      shift 2
      ;;
    --window)
      SCAN_WINDOW_SEC="${2:?missing scan window}"
      shift 2
      ;;
    --observer-ready-timeout)
      OBSERVER_READY_TIMEOUT_SEC="${2:?missing observer ready timeout}"
      shift 2
      ;;
    --observer-settle)
      OBSERVER_SETTLE_SEC="${2:?missing observer settle seconds}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:?missing output directory}"
      shift 2
      ;;
    --skip-install)
      INSTALL=0
      shift
      ;;
    --verify-only)
      VERIFY_ONLY=1
      shift
      ;;
    --preflight-only)
      PREFLIGHT_ONLY=1
      shift
      ;;
    --wait-for-devices)
      WAIT_FOR_DEVICES_SEC="${2:?missing wait seconds}"
      shift 2
      ;;
    --require-scan-start)
      REQUIRE_SCAN_START=1
      shift
      ;;
    --legacy-beacon)
      LEGACY_BEACON=1
      shift
      ;;
    --sender-log)
      SENDER_LOG="${2:?missing sender log path}"
      shift 2
      ;;
    --observer-log)
      OBSERVER_LOG="${2:?missing observer log path}"
      shift 2
      ;;
    --summary-json)
      SUMMARY_JSON="${2:?missing summary JSON path}"
      shift 2
      ;;
    --sender-device-json)
      SENDER_DEVICE_JSON="${2:?missing sender device JSON}"
      shift 2
      ;;
    --observer-device-json)
      OBSERVER_DEVICE_JSON="${2:?missing observer device JSON}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$VERIFY_ONLY" -eq 1 && "$PREFLIGHT_ONLY" -eq 1 ]]; then
  echo "--verify-only and --preflight-only are mutually exclusive" >&2
  exit 2
fi

if [[ ! "$WAIT_FOR_DEVICES_SEC" =~ ^[0-9]+$ ]]; then
  echo "--wait-for-devices must be a non-negative integer number of seconds" >&2
  exit 2
fi

if [[ ! "$OBSERVER_READY_TIMEOUT_SEC" =~ ^[0-9]+$ ]]; then
  echo "--observer-ready-timeout must be a non-negative integer number of seconds" >&2
  exit 2
fi

if [[ ! "$OBSERVER_SETTLE_SEC" =~ ^[0-9]+$ ]]; then
  echo "--observer-settle must be a non-negative integer number of seconds" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="$ROOT/apps/mob_node/android"
APK="$ANDROID_DIR/app/build/outputs/apk/debug/app-debug.apk"
SCRIPT_INVOCATION="$(
  ruby -rshellwords -e 'puts (["scripts/android_ble_message_delivery_two_device.sh"] + ARGV).shelljoin' \
    -- \
    "${ORIGINAL_ARGS[@]}"
)"

resolve_debug_apk() {
  local candidates=(
    "$ANDROID_DIR/app/build/outputs/apk/debug/app-debug.apk"
    "$ANDROID_DIR/build/outputs/apk/debug/Mob.Node-debug.apk"
  )
  local candidate

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      APK="$candidate"
      return 0
    fi
  done

  candidate="$(
    find "$ANDROID_DIR" -path '*/build/outputs/apk/debug/*.apk' -type f ! -name '*androidTest*' \
      | sort \
      | head -n 1
  )"
  if [[ -n "$candidate" ]]; then
    APK="$candidate"
    return 0
  fi

  echo "debug APK not found under $ANDROID_DIR" >&2
  return 1
}

ensure_out_dir() {
  if [[ -z "$OUT_DIR" ]]; then
    OUT_DIR="/tmp/mob-android-m26-$(date +%Y%m%d-%H%M%S)"
  fi
}

write_host_usb_log() {
  local host_usb_log="$1"
  if command -v ioreg >/dev/null 2>&1; then
    ioreg -p IOUSB -l -w0 > "$host_usb_log" 2>&1 || true
  else
    printf 'ioreg unavailable on this host\n' > "$host_usb_log"
  fi
}

write_preflight_failure_summary() {
  local reason="$1"
  local attached_count="$2"

  ensure_out_dir
  mkdir -p "$OUT_DIR"
  local adb_devices_log="$OUT_DIR/adb-devices.txt"
  local adb_mdns_log="$OUT_DIR/adb-mdns-services.txt"
  local host_usb_log="$OUT_DIR/host-usb.txt"
  local summary_json="$OUT_DIR/summary.json"
  local summary_markdown="$OUT_DIR/summary.md"

  adb devices -l > "$adb_devices_log" 2>&1 || true
  adb mdns services > "$adb_mdns_log" 2>&1 || true
  write_host_usb_log "$host_usb_log"

  # shellcheck disable=SC2016 # Embedded Ruby source is intentionally single-quoted.
  ruby -rjson -e '
    reason, attached_count, adb_devices_log, adb_mdns_log, host_usb_log, summary_json, summary_markdown, sender_serial, observer_serial, wait_for_devices_sec, script_invocation = ARGV
    def adb_value(serial, *args)
      output = IO.popen(["adb", "-s", serial, *args], &:read)
      output.to_s.delete("\r").strip
    rescue
      nil
    end

    def android_usb_candidate?(candidate)
      [
        candidate[:name],
        candidate[:product],
        candidate[:vendor]
      ].compact.any? { |value| value.downcase.include?("android") }
    end

    def parse_adb_mdns_services(path)
      File.read(path).lines.map(&:strip).reject do |line|
        line.empty? || line == "List of discovered mdns services"
      end.map { |line| { raw: line } }
    rescue
      []
    end

    def parse_host_usb_android_candidates(path)
      candidates = []
      current = nil

      File.read(path).lines.each do |line|
        if (match = line.match(/\+-o\s+(.+?)(?:@\h+)?\s+<class IOUSBHostDevice/))
          candidates << current if current && android_usb_candidate?(current)
          current = {
            name: match[1].strip,
            product: nil,
            vendor: nil,
            serial: nil
          }
        elsif current
          current[:serial] ||= Regexp.last_match(1) if line =~ /"kUSBSerialNumberString"\s*=\s*"([^"]+)"/
          current[:serial] ||= Regexp.last_match(1) if line =~ /"USB Serial Number"\s*=\s*"([^"]+)"/
          current[:vendor] ||= Regexp.last_match(1) if line =~ /"USB Vendor Name"\s*=\s*"([^"]+)"/
          current[:vendor] ||= Regexp.last_match(1) if line =~ /"kUSBVendorString"\s*=\s*"([^"]+)"/
          current[:product] ||= Regexp.last_match(1) if line =~ /"USB Product Name"\s*=\s*"([^"]+)"/
          current[:product] ||= Regexp.last_match(1) if line =~ /"kUSBProductString"\s*=\s*"([^"]+)"/
        end
      end

      candidates << current if current && android_usb_candidate?(current)
      candidates
    rescue
      []
    end

    def parse_adb_inventory(path)
      File.read(path).lines.filter_map do |line|
        columns = line.split
        next if columns.empty? || columns[0] == "List"

        {
          serial: columns[0],
          state: columns[1],
          ready: columns[1] == "device",
          details: (columns[2..-1] || []).join(" ")
        }
      end
    rescue
      []
    end

    adb_inventory = parse_adb_inventory(adb_devices_log)
    devices = []
    File.read(adb_devices_log).lines.each do |line|
      columns = line.split
      next if columns.empty? || columns[0] == "List"
      next unless columns[1] == "device"

      serial = columns[0]
      devices << {
        serial: serial,
        state: columns[1],
        details: (columns[2..-1] || []).join(" "),
        model: adb_value(serial, "shell", "getprop", "ro.product.model"),
        android_release: adb_value(serial, "shell", "getprop", "ro.build.version.release"),
        android_sdk: adb_value(serial, "shell", "getprop", "ro.build.version.sdk"),
        bluetooth_le_feature: adb_value(serial, "shell", "pm", "has-feature", "android.hardware.bluetooth_le")
      }
    end
    host_usb_android_candidates = parse_host_usb_android_candidates(host_usb_log)
    adb_mdns_services = parse_adb_mdns_services(adb_mdns_log)
    def device_metadata_complete?(device, expected_serial)
      return false if expected_serial.empty?
      return false unless device.is_a?(Hash)
      return false unless device[:serial] == expected_serial
      return false unless [:model, :android_release, :android_sdk].all? { |field| !device[field].to_s.empty? }
      return false unless device[:android_sdk].to_s.match?(/\A\d+\z/)

      device[:bluetooth_le_feature] == "true"
    end

    sender_device = devices.find { |device| device[:serial] == sender_serial }
    observer_device = devices.find { |device| device[:serial] == observer_serial }
    validation = {
      two_android_devices_attached: devices.length >= 2,
      exactly_two_android_devices_attached: devices.length == 2,
      sender_ble_le_supported: sender_device ? sender_device[:bluetooth_le_feature] == "true" : false,
      observer_ble_le_supported: observer_device ? observer_device[:bluetooth_le_feature] == "true" : false,
      sender_attempt_dispatched: false,
      advertising_set_started: false,
      sender_attempt_matches_advertising_set: false,
      sender_payload_size_matches: false,
      sender_logcat_captured: false,
      observer_logcat_captured: false,
      observer_scan_started: false,
      received_message_logged: false,
      observer_m14_consistent: false,
      observer_mob_routing_metadata: false,
      payload_match: false
    }
    m26_completion_validation =
      validation.merge(
        sender_and_observer_distinct:
          !sender_serial.empty? && !observer_serial.empty? && sender_serial != observer_serial,
        sender_and_observer_logs_distinct: false,
        sender_device_metadata_complete: device_metadata_complete?(sender_device, sender_serial),
        observer_device_metadata_complete: device_metadata_complete?(observer_device, observer_serial),
        require_scan_start: true,
        android_logcat_provenance: false,
        not_repo_fixture_log_pair: true
      )
    m26_completion_provenance = {
      mode: "preflight_failed",
      live_run: false,
      verify_only: false,
      repo_fixture_log_pair: false,
      real_two_android_logcat_required: true
    }
    summary = {
      capture_context: {
        verifier: "scripts/android_ble_message_delivery_two_device.sh",
        mode: "preflight_failed",
        wait_for_devices_sec: wait_for_devices_sec.to_i,
        commands: [
          script_invocation,
          "adb devices -l",
          "adb mdns services",
          "ioreg -p IOUSB -l -w0"
        ]
      },
      error: reason,
      requested_sender_serial: sender_serial.empty? ? nil : sender_serial,
      requested_observer_serial: observer_serial.empty? ? nil : observer_serial,
      sender_device: sender_device,
      observer_device: observer_device,
      attached_device_count: attached_count.to_i,
      attached_devices: devices,
      adb_inventory_device_count: adb_inventory.length,
      adb_ready_device_count: devices.length,
      adb_nonready_device_count: adb_inventory.count { |device| device[:state] != "device" },
      adb_inventory: adb_inventory,
      adb_devices_log: adb_devices_log,
      adb_mdns_log: adb_mdns_log,
      adb_mdns_service_count: adb_mdns_services.length,
      adb_mdns_services: adb_mdns_services,
      host_usb_log: host_usb_log,
      host_usb_android_candidate_count: host_usb_android_candidates.length,
      host_usb_android_candidates: host_usb_android_candidates,
      summary_json: summary_json,
      summary_markdown: summary_markdown,
      validation: validation,
      m26_android_to_android_complete: false,
      m26_completion_blockers: [reason],
      m26_completion_validation: m26_completion_validation,
      m26_completion_provenance: m26_completion_provenance
    }

    File.write(summary_json, JSON.pretty_generate(summary) + "\n")

    rows = summary[:validation].map { |name, value| "| `#{name}` | `#{value}` |" }.join("\n")
    m26_rows = summary[:m26_completion_validation].map { |name, value| "| `#{name}` | `#{value}` |" }.join("\n")
    m26_provenance_rows = summary[:m26_completion_provenance].map { |name, value| "| `#{name}` | `#{value}` |" }.join("\n")
    blocker_rows = summary[:m26_completion_blockers].map { |blocker| "- `#{blocker}`" }.join("\n")
    device_rows = devices.map do |device|
      "| `#{device[:serial]}` | `#{device[:state]}` | `#{device[:model]}` | `#{device[:android_release]}` | `#{device[:android_sdk]}` | `#{device[:bluetooth_le_feature]}` | `#{device[:details]}` |"
    end.join("\n")
    device_rows = "| _none_ |  |  |  |  |  | |" if device_rows.empty?
    adb_inventory_rows = summary[:adb_inventory].map do |device|
      "| `#{device[:serial]}` | `#{device[:state] || "unknown"}` | `#{device[:ready]}` | `#{device[:details]}` |"
    end.join("\n")
    adb_inventory_rows = "| _none_ |  |  | |" if adb_inventory_rows.empty?
    role_device_rows = [
      ["Device A sender", sender_serial, sender_device],
      ["Device B observer", observer_serial, observer_device]
    ].map do |role, requested, device|
      if device
        "| #{role} | `#{requested.empty? ? "unset" : requested}` | `#{device[:serial]}` | `#{device[:model]}` | `#{device[:android_release]}` | `#{device[:android_sdk]}` | `#{device[:bluetooth_le_feature]}` |"
      else
        "| #{role} | `#{requested.empty? ? "unset" : requested}` | _not attached_ | _n/a_ | _n/a_ | _n/a_ | _n/a_ |"
      end
    end.join("\n")
    usb_rows = summary[:host_usb_android_candidates].map do |device|
      "| `#{device[:serial] || "unknown"}` | `#{device[:product] || "unknown"}` | `#{device[:vendor] || "unknown"}` | `#{device[:name] || "unknown"}` |"
    end.join("\n")
    usb_rows = "| _none_ |  |  | |" if usb_rows.empty?
    mdns_rows = summary[:adb_mdns_services].map do |service|
      "| `#{service[:raw]}` |"
    end.join("\n")
    mdns_rows = "| _none_ |" if mdns_rows.empty?

    File.write(summary_markdown, <<~MARKDOWN)
      # MeshX Android BLE Message Delivery Verification

      | Field | Value |
      | --- | --- |
      | mode | `preflight_failed` |
      | wait_for_devices_sec | `#{wait_for_devices_sec.to_i}` |
      | error | `#{reason}` |
      | requested_sender_serial | `#{sender_serial.empty? ? "unset" : sender_serial}` |
      | requested_observer_serial | `#{observer_serial.empty? ? "unset" : observer_serial}` |
      | attached_device_count | `#{attached_count}` |
      | adb_inventory_device_count | `#{summary[:adb_inventory_device_count]}` |
      | adb_ready_device_count | `#{summary[:adb_ready_device_count]}` |
      | adb_nonready_device_count | `#{summary[:adb_nonready_device_count]}` |
      | adb_devices_log | `#{adb_devices_log}` |
      | adb_mdns_log | `#{adb_mdns_log}` |
      | adb_mdns_service_count | `#{summary[:adb_mdns_service_count]}` |
      | host_usb_log | `#{host_usb_log}` |
      | host_usb_android_candidate_count | `#{summary[:host_usb_android_candidate_count]}` |
      | summary_json | `#{summary_json}` |
      | summary_markdown | `#{summary_markdown}` |
      | m26_android_to_android_complete | `false` |

      ## Commands

      ```bash
      #{script_invocation}
      adb devices -l
      adb mdns services
      ioreg -p IOUSB -l -w0
      ```

      ## ADB Inventory

      | Serial | State | Ready | Details |
      | --- | --- | --- | --- |
      #{adb_inventory_rows}

      ## Attached Devices

      | Serial | State | Model | Android | API | BLE LE | Details |
      | --- | --- | --- | --- | --- | --- | --- |
      #{device_rows}

      ## Requested Role Devices

      | Role | Requested Serial | Matched ADB Serial | Model | Android | API | BLE LE |
      | --- | --- | --- | --- | --- | --- | --- |
      #{role_device_rows}

      ## ADB mDNS Services

      | Raw Service |
      | --- |
      #{mdns_rows}

      ## Host USB Android Candidates

      | Serial | Product | Vendor | Registry Name |
      | --- | --- | --- | --- |
      #{usb_rows}

      ## Validation

      | Check | Result |
      | --- | --- |
      #{rows}

      ## M26 Completion Gate

      | Check | Result |
      | --- | --- |
      #{m26_rows}

      ## M26 Completion Provenance

      | Provenance | Value |
      | --- | --- |
      #{m26_provenance_rows}

      Blockers:

      #{blocker_rows}
    MARKDOWN
  ' -- "$reason" "$attached_count" "$adb_devices_log" "$adb_mdns_log" "$host_usb_log" "$summary_json" "$summary_markdown" "$SENDER_SERIAL" "$OBSERVER_SERIAL" "$WAIT_FOR_DEVICES_SEC" "$SCRIPT_INVOCATION"
}

print_preflight_failure_summary_paths() {
  echo "preflight_summary=$OUT_DIR/summary.json" >&2
  echo "preflight_summary_markdown=$OUT_DIR/summary.md" >&2

  if [[ -f "$OUT_DIR/summary.json" ]]; then
    ruby -rjson -e '
      summary = JSON.parse(File.read(ARGV.fetch(0)))
      puts "preflight_adb_mdns_service_count=#{summary.fetch("adb_mdns_service_count", "unknown")}"
      puts "preflight_host_usb_android_candidate_count=#{summary.fetch("host_usb_android_candidate_count", "unknown")}"
    ' "$OUT_DIR/summary.json" >&2 || true
  fi
}

write_preflight_only_summary() {
  ensure_out_dir
  mkdir -p "$OUT_DIR"
  local adb_devices_log="$OUT_DIR/adb-devices.txt"
  local adb_mdns_log="$OUT_DIR/adb-mdns-services.txt"
  local host_usb_log="$OUT_DIR/host-usb.txt"
  local summary_json="$OUT_DIR/summary.json"
  local summary_markdown="$OUT_DIR/summary.md"

  adb devices -l > "$adb_devices_log" 2>&1 || true
  adb mdns services > "$adb_mdns_log" 2>&1 || true
  write_host_usb_log "$host_usb_log"

  # shellcheck disable=SC2016 # Embedded Ruby source is intentionally single-quoted.
  ruby -rjson -e '
    sender_serial, observer_serial, attached_count, sender_device_raw, observer_device_raw, adb_devices_log, adb_mdns_log, host_usb_log, summary_json, summary_markdown, wait_for_devices_sec, script_invocation = ARGV

    def android_usb_candidate?(candidate)
      [
        candidate[:name],
        candidate[:product],
        candidate[:vendor]
      ].compact.any? { |value| value.downcase.include?("android") }
    end

    def parse_adb_mdns_services(path)
      File.read(path).lines.map(&:strip).reject do |line|
        line.empty? || line == "List of discovered mdns services"
      end.map { |line| { raw: line } }
    rescue
      []
    end

    def parse_host_usb_android_candidates(path)
      candidates = []
      current = nil

      File.read(path).lines.each do |line|
        if (match = line.match(/\+-o\s+(.+?)(?:@\h+)?\s+<class IOUSBHostDevice/))
          candidates << current if current && android_usb_candidate?(current)
          current = {
            name: match[1].strip,
            product: nil,
            vendor: nil,
            serial: nil
          }
        elsif current
          current[:serial] ||= Regexp.last_match(1) if line =~ /"kUSBSerialNumberString"\s*=\s*"([^"]+)"/
          current[:serial] ||= Regexp.last_match(1) if line =~ /"USB Serial Number"\s*=\s*"([^"]+)"/
          current[:vendor] ||= Regexp.last_match(1) if line =~ /"USB Vendor Name"\s*=\s*"([^"]+)"/
          current[:vendor] ||= Regexp.last_match(1) if line =~ /"kUSBVendorString"\s*=\s*"([^"]+)"/
          current[:product] ||= Regexp.last_match(1) if line =~ /"USB Product Name"\s*=\s*"([^"]+)"/
          current[:product] ||= Regexp.last_match(1) if line =~ /"kUSBProductString"\s*=\s*"([^"]+)"/
        end
      end

      candidates << current if current && android_usb_candidate?(current)
      candidates
    rescue
      []
    end

    def parse_adb_inventory(path)
      File.read(path).lines.filter_map do |line|
        columns = line.split
        next if columns.empty? || columns[0] == "List"

        {
          serial: columns[0],
          state: columns[1],
          ready: columns[1] == "device",
          details: (columns[2..-1] || []).join(" ")
        }
      end
    rescue
      []
    end

    sender_device = JSON.parse(sender_device_raw)
    observer_device = JSON.parse(observer_device_raw)
    adb_inventory = parse_adb_inventory(adb_devices_log)
    host_usb_android_candidates = parse_host_usb_android_candidates(host_usb_log)
    adb_mdns_services = parse_adb_mdns_services(adb_mdns_log)
    def device_metadata_complete?(device, expected_serial)
      return false unless device.is_a?(Hash)
      return false unless device["serial"] == expected_serial
      return false unless ["model", "android_release", "android_sdk"].all? { |field| !device[field].to_s.empty? }
      return false unless device["android_sdk"].to_s.match?(/\A\d+\z/)

      device["bluetooth_le_feature"] == "true"
    end

    validation = {
      two_android_devices_attached: attached_count.to_i >= 2,
      exactly_two_android_devices_attached: attached_count.to_i == 2,
      sender_ble_le_supported: sender_device["bluetooth_le_feature"] == "true",
      observer_ble_le_supported: observer_device["bluetooth_le_feature"] == "true",
      sender_attempt_dispatched: false,
      advertising_set_started: false,
      sender_attempt_matches_advertising_set: false,
      sender_payload_size_matches: false,
      sender_logcat_captured: false,
      observer_logcat_captured: false,
      observer_scan_started: false,
      received_message_logged: false,
      observer_m14_consistent: false,
      observer_mob_routing_metadata: false,
      payload_match: false
    }
    m26_completion_validation =
      validation.merge(
        sender_and_observer_distinct: sender_serial != observer_serial,
        sender_and_observer_logs_distinct: false,
        sender_device_metadata_complete: device_metadata_complete?(sender_device, sender_serial),
        observer_device_metadata_complete: device_metadata_complete?(observer_device, observer_serial),
        require_scan_start: true,
        android_logcat_provenance: false,
        not_repo_fixture_log_pair: true
      )
    m26_completion_blockers =
      m26_completion_validation.each_with_object([]) do |(name, value), blockers|
        blockers << name.to_s unless value == true
      end
    m26_completion_provenance = {
      mode: "preflight_only",
      live_run: false,
      verify_only: false,
      repo_fixture_log_pair: false,
      real_two_android_logcat_required: true
    }
    summary = {
      capture_context: {
        verifier: "scripts/android_ble_message_delivery_two_device.sh",
        mode: "preflight_only",
        wait_for_devices_sec: wait_for_devices_sec.to_i,
        commands: [
          script_invocation,
          "adb devices -l",
          "adb mdns services",
          "ioreg -p IOUSB -l -w0"
        ]
      },
      sender_serial: sender_serial,
      observer_serial: observer_serial,
      sender_device: sender_device,
      observer_device: observer_device,
      attached_device_count: attached_count.to_i,
      adb_inventory_device_count: adb_inventory.length,
      adb_ready_device_count: adb_inventory.count { |device| device[:state] == "device" },
      adb_nonready_device_count: adb_inventory.count { |device| device[:state] != "device" },
      adb_inventory: adb_inventory,
      adb_devices_log: adb_devices_log,
      adb_mdns_log: adb_mdns_log,
      adb_mdns_service_count: adb_mdns_services.length,
      adb_mdns_services: adb_mdns_services,
      host_usb_log: host_usb_log,
      host_usb_android_candidate_count: host_usb_android_candidates.length,
      host_usb_android_candidates: host_usb_android_candidates,
      summary_json: summary_json,
      summary_markdown: summary_markdown,
      validation: validation,
      m26_android_to_android_complete: false,
      m26_completion_blockers: m26_completion_blockers,
      m26_completion_validation: m26_completion_validation,
      m26_completion_provenance: m26_completion_provenance
    }

    File.write(summary_json, JSON.pretty_generate(summary) + "\n")

    validation_rows = summary[:validation].map { |name, value| "| `#{name}` | `#{value}` |" }.join("\n")
    m26_rows = summary[:m26_completion_validation].map { |name, value| "| `#{name}` | `#{value}` |" }.join("\n")
    m26_provenance_rows = summary[:m26_completion_provenance].map { |name, value| "| `#{name}` | `#{value}` |" }.join("\n")
    m26_blocker_rows = summary[:m26_completion_blockers].map { |blocker| "- `#{blocker}`" }.join("\n")
    usb_rows = summary[:host_usb_android_candidates].map do |device|
      "| `#{device[:serial] || "unknown"}` | `#{device[:product] || "unknown"}` | `#{device[:vendor] || "unknown"}` | `#{device[:name] || "unknown"}` |"
    end.join("\n")
    usb_rows = "| _none_ |  |  | |" if usb_rows.empty?
    mdns_rows = summary[:adb_mdns_services].map do |service|
      "| `#{service[:raw]}` |"
    end.join("\n")
    mdns_rows = "| _none_ |" if mdns_rows.empty?
    adb_inventory_rows = summary[:adb_inventory].map do |device|
      "| `#{device[:serial]}` | `#{device[:state] || "unknown"}` | `#{device[:ready]}` | `#{device[:details]}` |"
    end.join("\n")
    adb_inventory_rows = "| _none_ |  |  | |" if adb_inventory_rows.empty?

    File.write(summary_markdown, <<~MARKDOWN)
      # MeshX Android BLE Message Delivery Preflight

      | Field | Value |
      | --- | --- |
      | mode | `preflight_only` |
      | wait_for_devices_sec | `#{wait_for_devices_sec.to_i}` |
      | sender_serial | `#{sender_serial}` |
      | observer_serial | `#{observer_serial}` |
      | attached_device_count | `#{attached_count}` |
      | adb_inventory_device_count | `#{summary[:adb_inventory_device_count]}` |
      | adb_ready_device_count | `#{summary[:adb_ready_device_count]}` |
      | adb_nonready_device_count | `#{summary[:adb_nonready_device_count]}` |
      | adb_devices_log | `#{adb_devices_log}` |
      | adb_mdns_log | `#{adb_mdns_log}` |
      | adb_mdns_service_count | `#{summary[:adb_mdns_service_count]}` |
      | host_usb_log | `#{host_usb_log}` |
      | host_usb_android_candidate_count | `#{summary[:host_usb_android_candidate_count]}` |
      | summary_json | `#{summary_json}` |
      | summary_markdown | `#{summary_markdown}` |
      | m26_android_to_android_complete | `false` |

      ## Commands

      ```bash
      #{script_invocation}
      adb devices -l
      adb mdns services
      ioreg -p IOUSB -l -w0
      ```

      ## ADB Inventory

      | Serial | State | Ready | Details |
      | --- | --- | --- | --- |
      #{adb_inventory_rows}

      ## Devices

      | Role | Serial | Model | Android | API | BLE LE |
      | --- | --- | --- | --- | --- | --- |
      | Device A sender | `#{sender_device["serial"]}` | `#{sender_device["model"]}` | `#{sender_device["android_release"]}` | `#{sender_device["android_sdk"]}` | `#{sender_device["bluetooth_le_feature"]}` |
      | Device B observer | `#{observer_device["serial"]}` | `#{observer_device["model"]}` | `#{observer_device["android_release"]}` | `#{observer_device["android_sdk"]}` | `#{observer_device["bluetooth_le_feature"]}` |

      ## ADB mDNS Services

      | Raw Service |
      | --- |
      #{mdns_rows}

      ## Host USB Android Candidates

      | Serial | Product | Vendor | Registry Name |
      | --- | --- | --- | --- |
      #{usb_rows}

      ## Validation

      | Check | Result |
      | --- | --- |
      #{validation_rows}

      ## M26 Completion Gate

      | Check | Result |
      | --- | --- |
      #{m26_rows}

      ## M26 Completion Provenance

      | Provenance | Value |
      | --- | --- |
      #{m26_provenance_rows}

      Blockers:

      #{m26_blocker_rows}
    MARKDOWN
  ' -- "$SENDER_SERIAL" "$OBSERVER_SERIAL" "${#attached_devices[@]}" "$SENDER_DEVICE_JSON" "$OBSERVER_DEVICE_JSON" "$adb_devices_log" "$adb_mdns_log" "$host_usb_log" "$summary_json" "$summary_markdown" "$WAIT_FOR_DEVICES_SEC" "$SCRIPT_INVOCATION"
}

verify_logs() {
  ruby -rjson -rbase64 - "$SENDER_SERIAL" "$OBSERVER_SERIAL" "$SENDER_LOG" "$OBSERVER_LOG" "$SUMMARY_JSON" "$REQUIRE_SCAN_START" "$LEGACY_BEACON" "$SENDER_DEVICE_JSON" "$OBSERVER_DEVICE_JSON" "$VERIFY_ONLY" "$SCAN_WINDOW_SEC" "$WAIT_FOR_DEVICES_SEC" "$OBSERVER_READY_TIMEOUT_SEC" "$COMMANDS_JSON" "$ADB_DEVICES_LOG" "$ADB_MDNS_LOG" "$HOST_USB_LOG" <<'RUBY'
sender_serial, observer_serial, sender_log, observer_log, summary_json, require_scan_start_raw, legacy_beacon_raw, sender_device_raw, observer_device_raw, verify_only_raw, scan_window_sec_raw, wait_for_devices_sec_raw, observer_ready_timeout_sec_raw, commands_raw, adb_devices_log, adb_mdns_log, host_usb_log = ARGV
require_scan_start = require_scan_start_raw == "1"
legacy_beacon_requested = legacy_beacon_raw == "1"
verify_only = verify_only_raw == "1"

def json_from(line)
  match = line.match(/\{.*\}/)
  return nil unless match

  JSON.parse(match[0])
rescue JSON::ParserError
  nil
end

def json_arg(value, fallback)
  parsed = JSON.parse(value || "")
  parsed.is_a?(Hash) ? parsed : fallback
rescue JSON::ParserError
  fallback
end

def json_array_arg(value)
  parsed = JSON.parse(value || "")
  parsed.is_a?(Array) ? parsed : []
rescue JSON::ParserError
  []
end

def present_file?(path)
  path && !path.empty? && File.file?(path)
end

def distinct_files?(left, right)
  return false if File.expand_path(left) == File.expand_path(right)
  return !File.identical?(left, right) if present_file?(left) && present_file?(right)

  true
rescue
  false
end

def logcat_capture_failed?(path)
  present_file?(path) && File.read(path).include?("logcat_capture_failed=true")
rescue
  false
end

def android_usb_candidate?(candidate)
  [
    candidate[:name],
    candidate[:product],
    candidate[:vendor]
  ].compact.any? { |value| value.downcase.include?("android") }
end

def parse_adb_mdns_services(path)
  return [] unless present_file?(path)

  File.read(path).lines.map(&:strip).reject do |line|
    line.empty? || line == "List of discovered mdns services"
  end.map { |line| { raw: line } }
rescue
  []
end

def parse_adb_inventory(path)
  return [] unless present_file?(path)

  File.read(path).lines.filter_map do |line|
    columns = line.split
    next if columns.empty? || columns[0] == "List"

    {
      serial: columns[0],
      state: columns[1],
      ready: columns[1] == "device",
      details: (columns[2..-1] || []).join(" ")
    }
  end
rescue
  []
end

def parse_host_usb_android_candidates(path)
  return [] unless present_file?(path)

  candidates = []
  current = nil

  File.read(path).lines.each do |line|
    if (match = line.match(/\+-o\s+(.+?)(?:@\h+)?\s+<class IOUSBHostDevice/))
      candidates << current if current && android_usb_candidate?(current)
      current = {
        name: match[1].strip,
        product: nil,
        vendor: nil,
        serial: nil
      }
    elsif current
      current[:serial] ||= Regexp.last_match(1) if line =~ /"kUSBSerialNumberString"\s*=\s*"([^"]+)"/
      current[:serial] ||= Regexp.last_match(1) if line =~ /"USB Serial Number"\s*=\s*"([^"]+)"/
      current[:vendor] ||= Regexp.last_match(1) if line =~ /"USB Vendor Name"\s*=\s*"([^"]+)"/
      current[:vendor] ||= Regexp.last_match(1) if line =~ /"kUSBVendorString"\s*=\s*"([^"]+)"/
      current[:product] ||= Regexp.last_match(1) if line =~ /"USB Product Name"\s*=\s*"([^"]+)"/
      current[:product] ||= Regexp.last_match(1) if line =~ /"kUSBProductString"\s*=\s*"([^"]+)"/
    end
  end

  candidates << current if current && android_usb_candidate?(current)
  candidates
rescue
  []
end

def decode64(value)
  return nil unless value.is_a?(String)

  Base64.strict_decode64(value)
rescue ArgumentError
  nil
end

def read_length_prefixed(bytes, offset)
  return nil if offset >= bytes.bytesize

  length = bytes.getbyte(offset)
  start = offset + 1
  finish = start + length
  return nil if finish > bytes.bytesize

  [bytes.byteslice(start, length), finish]
end

def parse_m14_summary(envelope)
  return nil unless envelope
  return nil unless envelope.bytesize >= 29
  return nil unless envelope.byteslice(0, 2) == "MX"

  offset = 4
  message_id = envelope.byteslice(offset, 16)
  offset += 16
  created_at_ms = envelope.byteslice(offset, 8).unpack1("Q>")
  offset += 8
  ttl = envelope.getbyte(offset)
  offset += 1
  sender, offset = read_length_prefixed(envelope, offset)
  return nil unless sender
  recipient, offset = read_length_prefixed(envelope, offset)
  return nil unless recipient
  payload_type, offset = read_length_prefixed(envelope, offset)
  return nil unless payload_type
  return nil if offset >= envelope.bytesize
  capability_requirements = envelope.getbyte(offset)
  offset += 1
  return nil if offset + 2 > envelope.bytesize
  payload_length = (envelope.getbyte(offset) << 8) | envelope.getbyte(offset + 1)
  offset += 2
  return nil if offset + payload_length > envelope.bytesize
  payload = envelope.byteslice(offset, payload_length)

  {
    "message_id" => Base64.strict_encode64(message_id),
    "sender_peer_id" => sender.force_encoding(Encoding::UTF_8),
    "recipient_peer_id" => recipient.empty? ? nil : recipient.force_encoding(Encoding::UTF_8),
    "created_at_ms" => created_at_ms,
    "ttl" => ttl,
    "payload_type" => payload_type.force_encoding(Encoding::UTF_8),
    "capability_requirements" => capability_requirements,
    "payload_size" => payload.bytesize,
    "payload_base64" => Base64.strict_encode64(payload)
  }
end

def m14_consistency_error(event)
  envelope_b64 = event["envelope"]
  envelope = decode64(envelope_b64)
  return "received_message envelope is not valid base64" unless envelope
  return "received_message envelope missing MX magic" unless envelope.byteslice(0, 2) == "MX"
  return "received_message envelope is truncated" if envelope.bytesize < 29
  return "received_message envelope version is not 1" unless envelope.getbyte(2) == 1
  return "received_message envelope flags are not zero" unless envelope.getbyte(3) == 0

  message_id = envelope.byteslice(4, 16)
  if event["message_id"] != Base64.strict_encode64(message_id)
    return "received_message message_id does not match envelope"
  end

  offset = 29
  sender, offset = read_length_prefixed(envelope, offset)
  return "received_message envelope has invalid sender_peer_id" unless sender
  if event["sender_peer_id"] != sender.force_encoding(Encoding::UTF_8)
    return "received_message sender_peer_id does not match envelope"
  end

  recipient, offset = read_length_prefixed(envelope, offset)
  return "received_message envelope has invalid recipient_peer_id" unless recipient
  recipient_value = recipient.empty? ? nil : recipient.force_encoding(Encoding::UTF_8)
  if event["recipient_peer_id"] != recipient_value
    return "received_message recipient_peer_id does not match envelope"
  end

  payload_type, offset = read_length_prefixed(envelope, offset)
  return "received_message envelope has invalid payload_type" unless payload_type
  return "received_message envelope is truncated before capability_requirements" if offset >= envelope.bytesize

  offset += 1
  return "received_message envelope is truncated before payload length" if offset + 2 > envelope.bytesize

  payload_length = (envelope.getbyte(offset) << 8) | envelope.getbyte(offset + 1)
  offset += 2
  return "received_message envelope payload is truncated" if offset + payload_length > envelope.bytesize

  metadata = event["raw_transport_metadata"] || {}
  message_payload = metadata["message_payload"]
  if message_payload && message_payload != envelope_b64
    return "received_message raw_transport_metadata.message_payload does not match envelope"
  end

  nil
end

def mob_routing_metadata_error(event)
  envelope_b64 = event["envelope"]
  envelope = decode64(envelope_b64)
  return "received_message envelope is not valid base64" unless envelope

  metadata = event["raw_transport_metadata"]
  return "received_message raw_transport_metadata is missing" unless metadata.is_a?(Hash)

  if metadata["transport"] != "ble_advertisement"
    return "received_message raw_transport_metadata.transport is not ble_advertisement"
  end

  if metadata["received_device_id"] != event["received_device_id"]
    return "received_message raw_transport_metadata.received_device_id does not match received_device_id"
  end

  if metadata["company_identifier"] != 65_535
    return "received_message raw_transport_metadata.company_identifier is not 65535"
  end

  if metadata["ad_type"] != 255
    return "received_message raw_transport_metadata.ad_type is not 255"
  end

  if metadata["message_payload"] != envelope_b64
    return "received_message raw_transport_metadata.message_payload does not match envelope"
  end

  manufacturer_data = decode64(metadata["manufacturer_data"])
  return "received_message raw_transport_metadata.manufacturer_data is not valid base64" unless manufacturer_data

  advertisement = decode64(metadata["advertisement"])
  return "received_message raw_transport_metadata.advertisement is not valid base64" unless advertisement

  unless advertisement.include?(manufacturer_data)
    return "received_message raw_transport_metadata.advertisement does not contain manufacturer_data"
  end

  unless manufacturer_data.bytesize >= 2 &&
         manufacturer_data.getbyte(0) == 0xFF &&
         manufacturer_data.getbyte(1) == 0xFF
    return "received_message raw_transport_metadata.manufacturer_data missing 0xFFFF company identifier"
  end

  if manufacturer_data.byteslice(2, envelope.bytesize) != envelope
    return "received_message raw_transport_metadata.manufacturer_data payload does not match envelope"
  end

  nil
end

def sender_payload_size_error(event)
  return "missing advertising_set_started" unless event

  payload = decode64(event["payload"])
  return "sender advertising_set_started payload is not valid base64" unless payload

  logged_size = event["payload_size"]
  unless logged_size.is_a?(Integer)
    return "sender advertising_set_started payload_size is not an integer"
  end

  if logged_size != payload.bytesize
    return "sender advertising_set_started payload_size #{logged_size} does not match decoded payload bytes #{payload.bytesize}"
  end

  nil
end

def sender_attempt_match_error(sender_event, sender_attempt_event)
  return "missing advertising_set_started" unless sender_event
  return "missing dispatched attempt_outcome" unless sender_attempt_event

  if sender_event["attempt_id"] != sender_attempt_event["attempt_id"]
    return "sender dispatched attempt_outcome attempt_id #{sender_attempt_event["attempt_id"].inspect} does not match advertising_set_started attempt_id #{sender_event["attempt_id"].inspect}"
  end

  payload = decode64(sender_event["payload"])
  m14 = parse_m14_summary(payload)
  return "sender advertising_set_started payload is not a parseable M14 envelope" unless m14

  unless sender_attempt_event["message_id"].is_a?(String)
    return "sender dispatched attempt_outcome message_id is missing"
  end

  if sender_attempt_event["message_id"] != m14["message_id"]
    return "sender dispatched attempt_outcome message_id does not match advertising_set_started payload"
  end

  if sender_attempt_event["target_peer_id"] != m14["recipient_peer_id"]
    return "sender dispatched attempt_outcome target_peer_id does not match advertising_set_started payload recipient"
  end

  target_device_ids = sender_attempt_event["target_device_ids"]
  unless target_device_ids.is_a?(Array) &&
         !target_device_ids.empty? &&
         target_device_ids.all? { |id| id.is_a?(String) && !id.empty? }
    return "sender dispatched attempt_outcome target_device_ids is missing or invalid"
  end

  nil
end

def android_logcat_tagged?(line, tag)
  !!(
    line &&
      line.match?(
        /\A\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{3}\s+\d+\s+\d+\s+[VDIWEF]\s+#{Regexp.escape(tag)}\s*:/
      )
  )
end

sender_event = nil
sender_event_line = nil
File.readlines(sender_log).each do |line|
  event = json_from(line)
  next unless event && event["event"] == "advertising_set_started"

  sender_event = event
  sender_event_line = line
  break
end

sender_legacy_beacon_event = nil
sender_legacy_beacon_event_line = nil
File.readlines(sender_log).each do |line|
  event = json_from(line)
  next unless event && event["event"] == "legacy_beacon_advertising_started"

  sender_legacy_beacon_event = event
  sender_legacy_beacon_event_line = line
  break
end

sender_capabilities_event = nil
File.readlines(sender_log).each do |line|
  event = json_from(line)
  next unless event && event["event"] == "ble_capabilities"

  sender_capabilities_event = event
  break
end

sender_attempt_event = nil
sender_attempt_event_line = nil
File.readlines(sender_log).each do |line|
  event = json_from(line)
  next unless event && event["event"] == "attempt_outcome"
  next unless event["kind"] == "dispatched"

  sender_attempt_event = event
  sender_attempt_event_line = line
  break
end
sender_attempt_dispatched = !sender_attempt_event.nil?

observer_event = nil
observer_event_line = nil
File.readlines(observer_log).each do |line|
  event = json_from(line)
  next unless event && event["event"] == "received_message"

  observer_event = event
  observer_event_line = line
  break
end

observer_beacon_event = nil
observer_beacon_event_line = nil
File.readlines(observer_log).each do |line|
  event = json_from(line)
  next unless event && event["event"] == "received_message_beacon"

  observer_beacon_event = event
  observer_beacon_event_line = line
  break
end

observer_scan_start_event = nil
observer_scan_start_event_line = nil
File.readlines(observer_log).each do |line|
  event = json_from(line)
  next unless event && event["event"] == "scan_start_result"

  if event["accepted"] == true
    observer_scan_start_event = event
    observer_scan_start_event_line = line
    break
  end
end
observer_scan_started = !observer_scan_start_event.nil?

sender_attempt_matches_advertising_set =
  sender_event && sender_attempt_event ? sender_attempt_match_error(sender_event, sender_attempt_event).nil? : false
sender_payload_size_matches = sender_event ? sender_payload_size_error(sender_event).nil? : false
observer_m14_consistent = observer_event ? m14_consistency_error(observer_event).nil? : false
observer_mob_routing_metadata = observer_event ? mob_routing_metadata_error(observer_event).nil? : false
sender_logcat_capture_failed = logcat_capture_failed?(sender_log)
observer_logcat_capture_failed = logcat_capture_failed?(observer_log)
payload_match = sender_event && observer_event && sender_event["payload"] == observer_event["envelope"]
legacy_beacon_size_matches =
  if sender_legacy_beacon_event
    beacon = decode64(sender_legacy_beacon_event["beacon"])
    beacon && sender_legacy_beacon_event["beacon_size"] == beacon.bytesize && beacon.bytesize <= 24
  else
    false
  end
legacy_beacon_payload_match =
  sender_legacy_beacon_event &&
    observer_beacon_event &&
    sender_legacy_beacon_event["beacon"] == observer_beacon_event.dig("raw_transport_metadata", "beacon_payload")
observer_beacon_transport_metadata =
  if observer_beacon_event
    metadata = observer_beacon_event["raw_transport_metadata"] || {}
    beacon = decode64(observer_beacon_event["raw_transport_metadata"] && metadata["beacon_payload"])
    manufacturer_data = decode64(metadata["manufacturer_data"])
    advertisement = decode64(metadata["advertisement"])
    metadata["transport"] == "ble_advertisement" &&
      metadata["company_identifier"] == 65535 &&
      metadata["ad_type"] == 255 &&
      beacon &&
      manufacturer_data &&
      advertisement &&
      manufacturer_data.bytesize >= 2 &&
      manufacturer_data.getbyte(0) == 0xFF &&
      manufacturer_data.getbyte(1) == 0xFF &&
      manufacturer_data.byteslice(2, beacon.bytesize) == beacon &&
      advertisement.include?(manufacturer_data)
  else
    false
  end
android_logcat_provenance =
  android_logcat_tagged?(sender_attempt_event_line, "MobBleDispatch") &&
  android_logcat_tagged?(sender_event_line, "MobBleDispatch") &&
  (!require_scan_start || android_logcat_tagged?(observer_scan_start_event_line, "MobBleControl")) &&
  android_logcat_tagged?(observer_event_line, "MobBle")
legacy_android_logcat_provenance =
  android_logcat_tagged?(sender_attempt_event_line, "MobBleDispatch") &&
  android_logcat_tagged?(sender_legacy_beacon_event_line, "MobBleDispatch") &&
  (!require_scan_start || android_logcat_tagged?(observer_scan_start_event_line, "MobBleControl")) &&
  android_logcat_tagged?(observer_beacon_event_line, "MobBle")
matched_payload = payload_match ? sender_event["payload"] : nil
metadata = observer_event ? observer_event["raw_transport_metadata"] || {} : {}
beacon_metadata = observer_beacon_event ? observer_beacon_event["raw_transport_metadata"] || {} : {}
sender_payload = sender_event ? decode64(sender_event["payload"]) : nil
sender_legacy_beacon = sender_legacy_beacon_event ? decode64(sender_legacy_beacon_event["beacon"]) : nil
observer_envelope = observer_event ? decode64(observer_event["envelope"]) : nil
observer_beacon_payload = decode64(beacon_metadata["beacon_payload"])
observer_message_payload = decode64(metadata["message_payload"])
observer_manufacturer_data = decode64(metadata["manufacturer_data"])
observer_advertisement = decode64(metadata["advertisement"])
payload_sizes = {
  sender_advertising_payload: sender_payload&.bytesize,
  observer_received_message_envelope: observer_envelope&.bytesize,
  observer_raw_transport_message_payload: observer_message_payload&.bytesize,
  observer_raw_transport_manufacturer_data: observer_manufacturer_data&.bytesize,
  observer_raw_transport_advertisement: observer_advertisement&.bytesize,
  sender_legacy_beacon_payload: sender_legacy_beacon&.bytesize,
  observer_received_message_beacon_payload: observer_beacon_payload&.bytesize
}
m14_envelope = parse_m14_summary(sender_payload || observer_envelope)
sender_device = json_arg(sender_device_raw, { "serial" => sender_serial })
observer_device = json_arg(observer_device_raw, { "serial" => observer_serial })
adb_inventory = parse_adb_inventory(adb_devices_log)
adb_mdns_services = parse_adb_mdns_services(adb_mdns_log)
host_usb_android_candidates = parse_host_usb_android_candidates(host_usb_log)
repo_fixture_log_pair =
  [sender_log, observer_log].any? do |log_path|
    File.expand_path(log_path).include?("#{File::SEPARATOR}scripts#{File::SEPARATOR}fixtures#{File::SEPARATOR}")
  end

def device_metadata_complete?(device, expected_serial)
  return false unless device.is_a?(Hash)
  return false unless device["serial"] == expected_serial
  return false unless ["model", "android_release", "android_sdk"].all? { |field| !device[field].to_s.empty? }
  return false unless device["android_sdk"].to_s.match?(/\A\d+\z/)

  device["bluetooth_le_feature"] == "true"
end

validation = {
  sender_attempt_dispatched: sender_attempt_dispatched,
  advertising_set_started: !sender_event.nil?,
  sender_attempt_matches_advertising_set: sender_attempt_matches_advertising_set,
  sender_payload_size_matches: sender_payload_size_matches,
  sender_logcat_captured: !sender_logcat_capture_failed,
  observer_logcat_captured: !observer_logcat_capture_failed,
  observer_scan_started: observer_scan_started,
  received_message_logged: !observer_event.nil?,
  observer_m14_consistent: observer_m14_consistent,
  observer_mob_routing_metadata: observer_mob_routing_metadata,
  payload_match: payload_match,
  legacy_beacon_requested: legacy_beacon_requested,
  legacy_beacon_advertising_started: !sender_legacy_beacon_event.nil?,
  sender_legacy_beacon_size_matches: legacy_beacon_size_matches,
  received_message_beacon_logged: !observer_beacon_event.nil?,
  observer_beacon_transport_metadata: observer_beacon_transport_metadata,
  legacy_beacon_payload_match: legacy_beacon_payload_match
}

shared_completion_validation = {
  sender_and_observer_distinct: sender_serial != observer_serial,
  sender_and_observer_logs_distinct: distinct_files?(sender_log, observer_log),
  sender_device_metadata_complete: device_metadata_complete?(sender_device, sender_serial),
  observer_device_metadata_complete: device_metadata_complete?(observer_device, observer_serial),
  require_scan_start: require_scan_start,
  not_repo_fixture_log_pair: !repo_fixture_log_pair
}

full_core_validation = {
  sender_attempt_dispatched: sender_attempt_dispatched,
  advertising_set_started: !sender_event.nil?,
  sender_attempt_matches_advertising_set: sender_attempt_matches_advertising_set,
  sender_payload_size_matches: sender_payload_size_matches,
  sender_logcat_captured: !sender_logcat_capture_failed,
  observer_logcat_captured: !observer_logcat_capture_failed,
  observer_scan_started: observer_scan_started,
  received_message_logged: !observer_event.nil?,
  observer_m14_consistent: observer_m14_consistent,
  observer_mob_routing_metadata: observer_mob_routing_metadata,
  payload_match: payload_match
}

full_envelope_completion_validation =
  full_core_validation.merge(
    shared_completion_validation
  ).merge(
    android_logcat_provenance: android_logcat_provenance
  )

full_envelope_completion_blockers =
  full_envelope_completion_validation.each_with_object([]) do |(name, value), blockers|
    blockers << name.to_s unless value == true
  end
full_envelope_delivery_complete = full_envelope_completion_blockers.empty?

legacy_beacon_completion_validation =
  {
    sender_attempt_dispatched: sender_attempt_dispatched,
    legacy_beacon_advertising_started: !sender_legacy_beacon_event.nil?,
    sender_legacy_beacon_size_matches: legacy_beacon_size_matches,
    sender_logcat_captured: !sender_logcat_capture_failed,
    observer_logcat_captured: !observer_logcat_capture_failed,
    observer_scan_started: observer_scan_started,
    received_message_beacon_logged: !observer_beacon_event.nil?,
    observer_beacon_transport_metadata: observer_beacon_transport_metadata,
    legacy_beacon_payload_match: legacy_beacon_payload_match,
    android_logcat_provenance: legacy_android_logcat_provenance
  }.merge(shared_completion_validation)

legacy_beacon_completion_blockers =
  legacy_beacon_completion_validation.each_with_object([]) do |(name, value), blockers|
    blockers << name.to_s unless value == true
  end
legacy_beacon_delivery_complete = legacy_beacon_completion_blockers.empty?

m26_completion_validation = full_envelope_completion_validation
m26_completion_blockers = full_envelope_completion_blockers
m26_android_to_android_complete = full_envelope_delivery_complete
m26_completion_provenance = {
  mode: verify_only ? "verify_only" : "live",
  live_run: !verify_only,
  verify_only: verify_only,
  repo_fixture_log_pair: repo_fixture_log_pair,
  real_two_android_logcat_required: true
}
summary_markdown =
  if summary_json.end_with?(".json")
    summary_json.sub(/\.json\z/, ".md")
  else
    "#{summary_json}.md"
  end

summary = {
  capture_context: {
    verifier: "scripts/android_ble_message_delivery_two_device.sh",
    mode: verify_only ? "verify_only" : "live",
    scan_window_sec: scan_window_sec_raw.to_i,
    wait_for_devices_sec: wait_for_devices_sec_raw.to_i,
    observer_ready_timeout_sec: observer_ready_timeout_sec_raw.to_i,
    require_scan_start: require_scan_start,
    legacy_beacon: legacy_beacon_requested,
    commands: json_array_arg(commands_raw)
  },
  sender_serial: sender_serial,
  observer_serial: observer_serial,
  summary_json: summary_json,
  summary_markdown: summary_markdown,
  sender_device: sender_device,
  observer_device: observer_device,
  sender_log: sender_log,
  observer_log: observer_log,
  adb_devices_log: present_file?(adb_devices_log) ? adb_devices_log : nil,
  adb_inventory_device_count: adb_inventory.length,
  adb_ready_device_count: adb_inventory.count { |device| device[:state] == "device" },
  adb_nonready_device_count: adb_inventory.count { |device| device[:state] != "device" },
  adb_inventory: adb_inventory,
  adb_mdns_log: present_file?(adb_mdns_log) ? adb_mdns_log : nil,
  adb_mdns_service_count: adb_mdns_services.length,
  adb_mdns_services: adb_mdns_services,
  host_usb_log: present_file?(host_usb_log) ? host_usb_log : nil,
  host_usb_android_candidate_count: host_usb_android_candidates.length,
  host_usb_android_candidates: host_usb_android_candidates,
  observer_scan_started: observer_scan_started,
  observer_scan_start_event: observer_scan_start_event,
  require_scan_start: require_scan_start,
  sender_logcat_capture_failed: sender_logcat_capture_failed,
  observer_logcat_capture_failed: observer_logcat_capture_failed,
  sender_attempt_dispatched: sender_attempt_dispatched,
  sender_attempt_event: sender_attempt_event,
  sender_attempt_matches_advertising_set: sender_attempt_matches_advertising_set,
  sender_payload_size_matches: sender_payload_size_matches,
  sender_event: sender_event,
  sender_legacy_beacon_event: sender_legacy_beacon_event,
  sender_capabilities_event: sender_capabilities_event,
  observer_event: observer_event,
  observer_beacon_event: observer_beacon_event,
  observer_m14_consistent: observer_m14_consistent,
  observer_mob_routing_metadata: observer_mob_routing_metadata,
  android_logcat_provenance: android_logcat_provenance,
  legacy_android_logcat_provenance: legacy_android_logcat_provenance,
  payload_match: payload_match,
  legacy_beacon_payload_match: legacy_beacon_payload_match,
  matched_payload: matched_payload,
  m14_envelope: m14_envelope,
  payload_sizes: payload_sizes,
  validation: validation,
  full_envelope_delivery_complete: full_envelope_delivery_complete,
  full_envelope_completion_blockers: full_envelope_completion_blockers,
  full_envelope_completion_validation: full_envelope_completion_validation,
  legacy_beacon_delivery_complete: legacy_beacon_delivery_complete,
  legacy_beacon_completion_blockers: legacy_beacon_completion_blockers,
  legacy_beacon_completion_validation: legacy_beacon_completion_validation,
  m26_android_to_android_complete: m26_android_to_android_complete,
  m26_completion_blockers: m26_completion_blockers,
  m26_completion_validation: m26_completion_validation,
  m26_completion_provenance: m26_completion_provenance
}

File.write(summary_json, JSON.pretty_generate(summary) + "\n")

validation_rows = summary[:validation].map { |name, value| "| `#{name}` | `#{value}` |" }.join("\n")
m26_rows = summary[:m26_completion_validation].map { |name, value| "| `#{name}` | `#{value}` |" }.join("\n")
m26_provenance_rows = summary[:m26_completion_provenance].map { |name, value| "| `#{name}` | `#{value}` |" }.join("\n")
m26_blocker_rows =
  if summary[:m26_completion_blockers].empty?
    "- _none_"
  else
    summary[:m26_completion_blockers].map { |blocker| "- `#{blocker}`" }.join("\n")
  end
sender_device = summary[:sender_device]
observer_device = summary[:observer_device]
sender_attempt_event_json =
  summary[:sender_attempt_event] ? JSON.pretty_generate(summary[:sender_attempt_event]) : "null"
sender_event_json = summary[:sender_event] ? JSON.pretty_generate(summary[:sender_event]) : "null"
observer_scan_start_event_json =
  summary[:observer_scan_start_event] ? JSON.pretty_generate(summary[:observer_scan_start_event]) : "null"
observer_event_json = summary[:observer_event] ? JSON.pretty_generate(summary[:observer_event]) : "null"
commands_block = summary[:capture_context][:commands].join("\n")
commands_block = "# commands unavailable" if commands_block.empty?
payload_size_rows = [
  ["sender advertising_set_started.payload", summary[:payload_sizes][:sender_advertising_payload]],
  ["sender legacy_beacon_advertising_started.beacon", summary[:payload_sizes][:sender_legacy_beacon_payload]],
  ["observer received_message.envelope", summary[:payload_sizes][:observer_received_message_envelope]],
  ["observer received_message_beacon.beacon_payload", summary[:payload_sizes][:observer_received_message_beacon_payload]],
  ["observer raw_transport_metadata.message_payload", summary[:payload_sizes][:observer_raw_transport_message_payload]],
  ["observer raw_transport_metadata.manufacturer_data", summary[:payload_sizes][:observer_raw_transport_manufacturer_data]],
  ["observer raw_transport_metadata.advertisement", summary[:payload_sizes][:observer_raw_transport_advertisement]]
].map { |name, value| "| #{name} | `#{value || "n/a"}` |" }.join("\n")
mdns_rows = summary[:adb_mdns_services].map do |service|
  "| `#{service[:raw]}` |"
end.join("\n")
mdns_rows = "| _none_ |" if mdns_rows.empty?
adb_inventory_rows = summary[:adb_inventory].map do |device|
  "| `#{device[:serial]}` | `#{device[:state] || "unknown"}` | `#{device[:ready]}` | `#{device[:details]}` |"
end.join("\n")
adb_inventory_rows = "| _none_ |  |  | |" if adb_inventory_rows.empty?
usb_rows = summary[:host_usb_android_candidates].map do |device|
  "| `#{device[:serial] || "unknown"}` | `#{device[:product] || "unknown"}` | `#{device[:vendor] || "unknown"}` | `#{device[:name] || "unknown"}` |"
end.join("\n")
usb_rows = "| _none_ |  |  | |" if usb_rows.empty?

File.write(summary_markdown, <<~MARKDOWN)
  # MeshX Android BLE Message Delivery Verification

  | Field | Value |
  | --- | --- |
  | mode | `#{summary[:capture_context][:mode]}` |
  | scan_window_sec | `#{summary[:capture_context][:scan_window_sec]}` |
  | wait_for_devices_sec | `#{summary[:capture_context][:wait_for_devices_sec]}` |
  | observer_ready_timeout_sec | `#{summary[:capture_context][:observer_ready_timeout_sec]}` |
  | sender_log | `#{summary[:sender_log]}` |
  | observer_log | `#{summary[:observer_log]}` |
  | adb_devices_log | `#{summary[:adb_devices_log] || "n/a"}` |
  | adb_inventory_device_count | `#{summary[:adb_inventory_device_count]}` |
  | adb_ready_device_count | `#{summary[:adb_ready_device_count]}` |
  | adb_nonready_device_count | `#{summary[:adb_nonready_device_count]}` |
  | adb_mdns_log | `#{summary[:adb_mdns_log] || "n/a"}` |
  | adb_mdns_service_count | `#{summary[:adb_mdns_service_count]}` |
  | host_usb_log | `#{summary[:host_usb_log] || "n/a"}` |
  | host_usb_android_candidate_count | `#{summary[:host_usb_android_candidate_count]}` |
  | sender_logcat_capture_failed | `#{summary[:sender_logcat_capture_failed]}` |
  | observer_logcat_capture_failed | `#{summary[:observer_logcat_capture_failed]}` |
  | summary_json | `#{summary_json}` |
  | summary_markdown | `#{summary_markdown}` |
  | legacy_beacon | `#{summary[:capture_context][:legacy_beacon]}` |
  | full_envelope_delivery_complete | `#{summary[:full_envelope_delivery_complete]}` |
  | legacy_beacon_delivery_complete | `#{summary[:legacy_beacon_delivery_complete]}` |
  | m26_android_to_android_complete | `#{summary[:m26_android_to_android_complete]}` |

  ## Commands

  ```bash
  #{commands_block}
  ```

  ## ADB Inventory

  | Serial | State | Ready | Details |
  | --- | --- | --- | --- |
  #{adb_inventory_rows}

  ## Devices

  | Role | Serial | Model | Android | API | BLE LE |
  | --- | --- | --- | --- | --- | --- |
  | Device A sender | `#{sender_device["serial"]}` | `#{sender_device["model"]}` | `#{sender_device["android_release"]}` | `#{sender_device["android_sdk"]}` | `#{sender_device["bluetooth_le_feature"]}` |
  | Device B observer | `#{observer_device["serial"]}` | `#{observer_device["model"]}` | `#{observer_device["android_release"]}` | `#{observer_device["android_sdk"]}` | `#{observer_device["bluetooth_le_feature"]}` |

  ## ADB mDNS Services

  | Raw Service |
  | --- |
  #{mdns_rows}

  ## Host USB Android Candidates

  | Serial | Product | Vendor | Registry Name |
  | --- | --- | --- | --- |
  #{usb_rows}

  ## Payload Sizes

  | Payload | Bytes |
  | --- | --- |
  #{payload_size_rows}

  ## Validation

  | Check | Result |
  | --- | --- |
  #{validation_rows}

  ## M26 Completion Gate

  | Check | Result |
  | --- | --- |
  #{m26_rows}

  ## M26 Completion Provenance

  | Provenance | Value |
  | --- | --- |
  #{m26_provenance_rows}

  Blockers:

  #{m26_blocker_rows}

  ## Device A Attempt Outcome

  ```json
  #{sender_attempt_event_json}
  ```

  ## Device A Advertising Event

  ```json
  #{sender_event_json}
  ```

  ## Device B Scan Start Event

  ```json
  #{observer_scan_start_event_json}
  ```

  ## Device B Received Event

  ```json
  #{observer_event_json}
  ```
MARKDOWN

unless sender_event
  if legacy_beacon_requested && sender_legacy_beacon_event
    # The compatibility path intentionally emits a compact beacon, not a full envelope.
  else
  warn "missing advertising_set_started in #{sender_log}"
  exit 1
  end
end

unless sender_attempt_dispatched
  warn "missing dispatched attempt_outcome in #{sender_log}"
  exit 1
end

if sender_event && (sender_attempt_error = sender_attempt_match_error(sender_event, sender_attempt_event))
  warn sender_attempt_error
  exit 1
end

if sender_event && (sender_size_error = sender_payload_size_error(sender_event))
  warn sender_size_error
  exit 1
end

if require_scan_start && !observer_scan_started
  warn "missing Device B scan_start_result accepted=true in #{observer_log}"
  exit 1
end

unless observer_event
  if legacy_beacon_requested && observer_beacon_event
    puts "legacy_beacon_payload_match=#{summary[:legacy_beacon_payload_match]}"
    puts "full_envelope_delivery_complete=#{summary[:full_envelope_delivery_complete]}"
    puts "legacy_beacon_delivery_complete=#{summary[:legacy_beacon_delivery_complete]}"
    puts "m26_android_to_android_complete=#{summary[:m26_android_to_android_complete]}"
    puts "m26_completion_blockers=#{summary[:m26_completion_blockers].join(",")}"
    puts "sender_log=#{sender_log}"
    puts "observer_log=#{observer_log}"
    puts "summary=#{summary_json}"
    puts "summary_markdown=#{summary_markdown}"
    exit(summary[:legacy_beacon_delivery_complete] ? 0 : 1)
  end
  warn "missing received_message in #{observer_log}; observer_scan_started=#{observer_scan_started}"
  exit 1
end

if (m14_error = m14_consistency_error(observer_event))
  warn m14_error
  exit 1
end

if (metadata_error = mob_routing_metadata_error(observer_event))
  warn metadata_error
  exit 1
end

unless summary[:payload_match]
  warn "payload mismatch: sender payload did not equal observer envelope"
  exit 1
end

puts "payload_match=true"
puts "m26_android_to_android_complete=#{summary[:m26_android_to_android_complete]}"
puts "m26_completion_blockers=#{summary[:m26_completion_blockers].join(",")}"
puts "sender_log=#{sender_log}"
puts "observer_log=#{observer_log}"
puts "summary=#{summary_json}"
puts "summary_markdown=#{summary_markdown}"
RUBY
}

if [[ "$VERIFY_ONLY" -eq 1 ]]; then
  if [[ -z "$SENDER_LOG" || -z "$OBSERVER_LOG" ]]; then
    echo "--verify-only requires --sender-log and --observer-log" >&2
    exit 2
  fi
  SENDER_SERIAL="${SENDER_SERIAL:-unknown-sender}"
  OBSERVER_SERIAL="${OBSERVER_SERIAL:-unknown-observer}"
  if [[ -z "$SUMMARY_JSON" ]]; then
    SUMMARY_JSON="/tmp/mob-android-m26-summary-$(date +%Y%m%d-%H%M%S).json"
  fi
  if [[ -z "$SENDER_DEVICE_JSON" ]]; then
    SENDER_DEVICE_JSON="$(ruby -rjson -e 'puts JSON.generate({serial: ARGV.fetch(0)})' "$SENDER_SERIAL")"
  fi
  if [[ -z "$OBSERVER_DEVICE_JSON" ]]; then
    OBSERVER_DEVICE_JSON="$(ruby -rjson -e 'puts JSON.generate({serial: ARGV.fetch(0)})' "$OBSERVER_SERIAL")"
  fi
  COMMANDS_JSON="$(ruby -rjson -e 'puts JSON.generate([ARGV.fetch(0)])' "$SCRIPT_INVOCATION")"
  mkdir -p "$(dirname "$SUMMARY_JSON")"
  verify_logs
  exit 0
fi

REQUIRE_SCAN_START=1

attached_devices=()
adb_inventory_serials=()
adb_inventory_states=()
adb_inventory_details=()

read_attached_devices() {
  attached_devices=()
  adb_inventory_serials=()
  adb_inventory_states=()
  adb_inventory_details=()

  local serial state details
  while read -r serial state details; do
    [[ -z "${serial:-}" || -z "${state:-}" ]] && continue
    adb_inventory_serials+=("$serial")
    adb_inventory_states+=("$state")
    adb_inventory_details+=("${details:-}")
    if [[ "$state" == "device" ]]; then
      attached_devices+=("$serial")
    fi
  done < <(adb devices -l | awk 'NR > 1 && NF >= 2 { print }')
}

attached_serial_present() {
  local requested_serial="$1"
  local attached_serial

  for attached_serial in "${attached_devices[@]}"; do
    if [[ "$requested_serial" == "$attached_serial" ]]; then
      return 0
    fi
  done

  return 1
}

adb_state_for_serial() {
  local requested_serial="$1"
  local index

  for index in "${!adb_inventory_serials[@]}"; do
    if [[ "$requested_serial" == "${adb_inventory_serials[$index]}" ]]; then
      printf '%s\n' "${adb_inventory_states[$index]}"
      return 0
    fi
  done

  return 1
}

nonready_adb_inventory_summary() {
  local index
  local rows=()

  for index in "${!adb_inventory_serials[@]}"; do
    if [[ "${adb_inventory_states[$index]}" != "device" ]]; then
      rows+=("${adb_inventory_serials[$index]}:${adb_inventory_states[$index]}")
    fi
  done

  local IFS=","
  printf '%s\n' "${rows[*]}"
}

auto_selection_failure_reason() {
  local ready_count="${#attached_devices[@]}"
  local inventory_count="${#adb_inventory_serials[@]}"
  local nonready_count=$((inventory_count - ready_count))
  local nonready_summary

  if [[ "$nonready_count" -gt 0 ]]; then
    nonready_summary="$(nonready_adb_inventory_summary)"
    printf 'expected exactly two ready adb devices, found %s ready (%s total adb rows, %s non-ready: %s)\n' \
      "$ready_count" "$inventory_count" "$nonready_count" "$nonready_summary"
  else
    printf 'expected exactly two attached adb devices, found %s\n' "$ready_count"
  fi
}

device_selection_ready() {
  if [[ -z "$SENDER_SERIAL" && -z "$OBSERVER_SERIAL" ]]; then
    [[ "${#attached_devices[@]}" -eq 2 ]]
    return
  fi

  attached_serial_present "$SENDER_SERIAL" && attached_serial_present "$OBSERVER_SERIAL"
}

wait_for_device_selection() {
  local wait_seconds="$1"
  local deadline

  read_attached_devices
  if [[ "$wait_seconds" -eq 0 ]]; then
    return
  fi

  deadline=$(($(date +%s) + wait_seconds))
  while ! device_selection_ready; do
    if [[ "$(date +%s)" -ge "$deadline" ]]; then
      return
    fi
    sleep 1
    read_attached_devices
  done
}

read_attached_devices

if [[ -n "$SENDER_SERIAL" && -z "$OBSERVER_SERIAL" ]] || [[ -z "$SENDER_SERIAL" && -n "$OBSERVER_SERIAL" ]]; then
  echo "provide both --sender and --observer, or omit both with exactly two adb devices attached" >&2
  exit 2
fi

if [[ -n "$SENDER_SERIAL" && "$SENDER_SERIAL" == "$OBSERVER_SERIAL" ]]; then
  reason="--sender and --observer must be different adb devices"
  write_preflight_failure_summary "$reason" "${#attached_devices[@]}"
  echo "$reason" >&2
  print_preflight_failure_summary_paths
  exit 2
fi

wait_for_device_selection "$WAIT_FOR_DEVICES_SEC"

if [[ -z "$SENDER_SERIAL" && -z "$OBSERVER_SERIAL" ]]; then
  if [[ "${#attached_devices[@]}" -ne 2 ]]; then
    reason="$(auto_selection_failure_reason)"
    write_preflight_failure_summary "$reason" "${#attached_devices[@]}"
    echo "$reason" >&2
    adb devices -l >&2
    print_preflight_failure_summary_paths
    exit 2
  fi
  SENDER_SERIAL="${attached_devices[0]}"
  OBSERVER_SERIAL="${attached_devices[1]}"
fi

missing_requested_devices=()
not_ready_requested_devices=()
for requested_serial in "$SENDER_SERIAL" "$OBSERVER_SERIAL"; do
  if ! attached_serial_present "$requested_serial"; then
    if requested_state="$(adb_state_for_serial "$requested_serial")"; then
      not_ready_requested_devices+=("$requested_serial:$requested_state")
    else
      missing_requested_devices+=("$requested_serial")
    fi
  fi
done

if [[ "${#missing_requested_devices[@]}" -gt 0 || "${#not_ready_requested_devices[@]}" -gt 0 ]]; then
  reason_parts=()
  reason=""
  if [[ "${#missing_requested_devices[@]}" -gt 0 ]]; then
    reason_parts+=("requested adb device(s) not attached: ${missing_requested_devices[*]}")
  fi
  if [[ "${#not_ready_requested_devices[@]}" -gt 0 ]]; then
    reason_parts+=("requested adb device(s) not ready: ${not_ready_requested_devices[*]}")
  fi
  for reason_part in "${reason_parts[@]}"; do
    if [[ -z "$reason" ]]; then
      reason="$reason_part"
    else
      reason="$reason; $reason_part"
    fi
  done
  write_preflight_failure_summary "$reason" "${#attached_devices[@]}"
  echo "$reason" >&2
  adb devices -l >&2
  print_preflight_failure_summary_paths
  exit 2
fi

ensure_out_dir
mkdir -p "$OUT_DIR"

grant_ble_permissions() {
  local serial="$1"
  adb -s "$serial" shell pm grant "$APP_ID" android.permission.BLUETOOTH_SCAN >/dev/null 2>&1 || true
  adb -s "$serial" shell pm grant "$APP_ID" android.permission.BLUETOOTH_ADVERTISE >/dev/null 2>&1 || true
  adb -s "$serial" shell pm grant "$APP_ID" android.permission.BLUETOOTH_CONNECT >/dev/null 2>&1 || true
  adb -s "$serial" shell pm grant "$APP_ID" android.permission.ACCESS_FINE_LOCATION >/dev/null 2>&1 || true
}

wake_device_for_ble_validation() {
  local serial="$1"
  adb -s "$serial" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
  adb -s "$serial" shell wm dismiss-keyguard >/dev/null 2>&1 || true
}

observer_scan_ready_logged() {
  local serial="$1"
  adb -s "$serial" logcat -d -s MobBleControl:I AndroidRuntime:E 2>/dev/null | ruby -rjson -e '
    STDIN.each_line do |line|
      json = line[/\{.*\}/]
      next unless json

      begin
        event = JSON.parse(json)
      rescue JSON::ParserError
        next
      end

      if event["event"] == "scan_start_result" && event["accepted"] == true
        exit 0
      end
    end

    exit 1
  '
}

wait_for_observer_scan_ready() {
  local serial="$1"
  local timeout_sec="$2"
  local deadline

  if [[ "$timeout_sec" -eq 0 ]]; then
    return 0
  fi

  deadline=$((SECONDS + timeout_sec))
  while true; do
    if observer_scan_ready_logged "$serial"; then
      return 0
    fi

    if [[ "$SECONDS" -ge "$deadline" ]]; then
      return 1
    fi

    sleep 1
  done
}

capture_filtered_logcat() {
  local serial="$1"
  local output="$2"

  if adb -s "$serial" logcat -d -s MobBle:I MobBleControl:I MobBleDispatch:I MobBleGossip:I AndroidRuntime:E > "$output" 2>&1; then
    return 0
  fi

  printf '\nlogcat_capture_failed=true\n' >> "$output"
  return 0
}

start_activity() {
  local serial="$1"
  shift

  adb -s "$serial" shell am start -n "$MAIN_ACTIVITY" "$@" >/dev/null
}

adb_prop() {
  local serial="$1"
  local prop="$2"
  adb -s "$serial" shell getprop "$prop" | tr -d '\r'
}

device_info_json() {
  local serial="$1"
  local model release sdk manufacturer product device ble_feature bluetooth_feature
  model="$(adb_prop "$serial" ro.product.model)"
  release="$(adb_prop "$serial" ro.build.version.release)"
  sdk="$(adb_prop "$serial" ro.build.version.sdk)"
  manufacturer="$(adb_prop "$serial" ro.product.manufacturer)"
  product="$(adb_prop "$serial" ro.product.name)"
  device="$(adb_prop "$serial" ro.product.device)"
  ble_feature="$(adb -s "$serial" shell pm has-feature android.hardware.bluetooth_le | tr -d '\r')"
  bluetooth_feature="$(adb -s "$serial" shell pm has-feature android.hardware.bluetooth | tr -d '\r')"

  ruby -rjson -e '
    serial, model, release, sdk, manufacturer, product, device, ble_feature, bluetooth_feature = ARGV
    puts JSON.generate({
      serial: serial,
      model: model,
      android_release: release,
      android_sdk: sdk,
      manufacturer: manufacturer,
      product: product,
      device: device,
      bluetooth_le_feature: ble_feature,
      bluetooth_feature: bluetooth_feature
    })
  ' "$serial" "$model" "$release" "$sdk" "$manufacturer" "$product" "$device" "$ble_feature" "$bluetooth_feature"
}

SENDER_DEVICE_JSON="$(device_info_json "$SENDER_SERIAL")"
OBSERVER_DEVICE_JSON="$(device_info_json "$OBSERVER_SERIAL")"

ble_capability_issue="$(
  ruby -rjson -e '
    sender = JSON.parse(ARGV.fetch(0))
    observer = JSON.parse(ARGV.fetch(1))
    missing = []
    missing << "Device A sender #{sender.fetch("serial")} bluetooth_le_feature=#{sender["bluetooth_le_feature"].inspect}" unless sender["bluetooth_le_feature"] == "true"
    missing << "Device B observer #{observer.fetch("serial")} bluetooth_le_feature=#{observer["bluetooth_le_feature"].inspect}" unless observer["bluetooth_le_feature"] == "true"
    puts "required BLE LE feature missing: #{missing.join(", ")}" unless missing.empty?
  ' "$SENDER_DEVICE_JSON" "$OBSERVER_DEVICE_JSON"
)"

if [[ -n "$ble_capability_issue" ]]; then
  write_preflight_failure_summary "$ble_capability_issue" "${#attached_devices[@]}"
  echo "$ble_capability_issue" >&2
  print_preflight_failure_summary_paths
  exit 2
fi

if [[ "$PREFLIGHT_ONLY" -eq 1 ]]; then
  write_preflight_only_summary
  echo "preflight_ready=true"
  echo "preflight_summary=$OUT_DIR/summary.json"
  echo "preflight_summary_markdown=$OUT_DIR/summary.md"
  exit 0
fi

if [[ "$INSTALL" -eq 1 ]]; then
  (cd "$ANDROID_DIR" && ./gradlew --no-daemon assembleDebug)
  resolve_debug_apk
  adb -s "$SENDER_SERIAL" install -r "$APK" >/dev/null
  adb -s "$OBSERVER_SERIAL" install -r "$APK" >/dev/null
fi

grant_ble_permissions "$SENDER_SERIAL"
grant_ble_permissions "$OBSERVER_SERIAL"
wake_device_for_ble_validation "$SENDER_SERIAL"
wake_device_for_ble_validation "$OBSERVER_SERIAL"

adb -s "$SENDER_SERIAL" logcat -c
adb -s "$OBSERVER_SERIAL" logcat -c
adb -s "$SENDER_SERIAL" shell am force-stop "$APP_ID" >/dev/null
adb -s "$OBSERVER_SERIAL" shell am force-stop "$APP_ID" >/dev/null

start_activity "$OBSERVER_SERIAL" --ez mob_start_scan true
if wait_for_observer_scan_ready "$OBSERVER_SERIAL" "$OBSERVER_READY_TIMEOUT_SEC"; then
  echo "observer_scan_ready=true"
else
  echo "observer_scan_ready=false timeout=${OBSERVER_READY_TIMEOUT_SEC}s; dispatching anyway so final logcat can prove or fail the gate" >&2
fi
sleep "$OBSERVER_SETTLE_SEC"
if [[ "$LEGACY_BEACON" -eq 1 ]]; then
  start_activity "$SENDER_SERIAL" --ez mob_dispatch_test true --ez mob_dispatch_legacy_beacon true
else
  start_activity "$SENDER_SERIAL" --ez mob_dispatch_test true
fi
sleep "$SCAN_WINDOW_SEC"

SENDER_LOG="$OUT_DIR/sender.log"
OBSERVER_LOG="$OUT_DIR/observer.log"
SUMMARY_JSON="$OUT_DIR/summary.json"
ADB_DEVICES_LOG="$OUT_DIR/adb-devices.txt"
ADB_MDNS_LOG="$OUT_DIR/adb-mdns-services.txt"
HOST_USB_LOG="$OUT_DIR/host-usb.txt"

adb devices -l > "$ADB_DEVICES_LOG" 2>&1 || true
adb mdns services > "$ADB_MDNS_LOG" 2>&1 || true
write_host_usb_log "$HOST_USB_LOG"

command_items=("$SCRIPT_INVOCATION")
if [[ "$INSTALL" -eq 1 ]]; then
  command_items+=(
    "cd $ANDROID_DIR && ./gradlew --no-daemon assembleDebug"
    "adb -s $SENDER_SERIAL install -r $APK"
    "adb -s $OBSERVER_SERIAL install -r $APK"
  )
fi
command_items+=(
  "adb -s $SENDER_SERIAL shell pm grant $APP_ID android.permission.BLUETOOTH_SCAN"
  "adb -s $SENDER_SERIAL shell pm grant $APP_ID android.permission.BLUETOOTH_ADVERTISE"
  "adb -s $SENDER_SERIAL shell pm grant $APP_ID android.permission.BLUETOOTH_CONNECT"
  "adb -s $SENDER_SERIAL shell pm grant $APP_ID android.permission.ACCESS_FINE_LOCATION"
  "adb -s $OBSERVER_SERIAL shell pm grant $APP_ID android.permission.BLUETOOTH_SCAN"
  "adb -s $OBSERVER_SERIAL shell pm grant $APP_ID android.permission.BLUETOOTH_ADVERTISE"
  "adb -s $OBSERVER_SERIAL shell pm grant $APP_ID android.permission.BLUETOOTH_CONNECT"
  "adb -s $OBSERVER_SERIAL shell pm grant $APP_ID android.permission.ACCESS_FINE_LOCATION"
  "adb -s $SENDER_SERIAL shell input keyevent KEYCODE_WAKEUP"
  "adb -s $SENDER_SERIAL shell wm dismiss-keyguard"
  "adb -s $OBSERVER_SERIAL shell input keyevent KEYCODE_WAKEUP"
  "adb -s $OBSERVER_SERIAL shell wm dismiss-keyguard"
  "adb -s $SENDER_SERIAL shell getprop ro.product.model"
  "adb -s $SENDER_SERIAL shell getprop ro.build.version.release"
  "adb -s $SENDER_SERIAL shell getprop ro.build.version.sdk"
  "adb -s $SENDER_SERIAL shell pm has-feature android.hardware.bluetooth_le"
  "adb -s $OBSERVER_SERIAL shell getprop ro.product.model"
  "adb -s $OBSERVER_SERIAL shell getprop ro.build.version.release"
  "adb -s $OBSERVER_SERIAL shell getprop ro.build.version.sdk"
  "adb -s $OBSERVER_SERIAL shell pm has-feature android.hardware.bluetooth_le"
  "adb -s $SENDER_SERIAL logcat -c"
  "adb -s $OBSERVER_SERIAL logcat -c"
  "adb -s $SENDER_SERIAL shell am force-stop $APP_ID"
  "adb -s $OBSERVER_SERIAL shell am force-stop $APP_ID"
  "adb -s $OBSERVER_SERIAL shell am start -n $MAIN_ACTIVITY --ez mob_start_scan true"
  "wait up to ${OBSERVER_READY_TIMEOUT_SEC}s for Device B scan_start_result accepted=true"
  "sleep $OBSERVER_SETTLE_SEC"
  "$([[ "$LEGACY_BEACON" -eq 1 ]] && printf 'adb -s %s shell am start -n %s --ez mob_dispatch_test true --ez mob_dispatch_legacy_beacon true' "$SENDER_SERIAL" "$MAIN_ACTIVITY" || printf 'adb -s %s shell am start -n %s --ez mob_dispatch_test true' "$SENDER_SERIAL" "$MAIN_ACTIVITY")"
  "sleep $SCAN_WINDOW_SEC"
  "adb devices -l > $ADB_DEVICES_LOG"
  "adb mdns services > $ADB_MDNS_LOG"
  "ioreg -p IOUSB -l -w0 > $HOST_USB_LOG"
  "adb -s $SENDER_SERIAL logcat -d -s MobBle:I MobBleControl:I MobBleDispatch:I MobBleGossip:I AndroidRuntime:E > $SENDER_LOG 2>&1 || true"
  "adb -s $OBSERVER_SERIAL logcat -d -s MobBle:I MobBleControl:I MobBleDispatch:I MobBleGossip:I AndroidRuntime:E > $OBSERVER_LOG 2>&1 || true"
)
COMMANDS_JSON="$(ruby -rjson -e 'puts JSON.generate(ARGV)' "${command_items[@]}")"

capture_filtered_logcat "$SENDER_SERIAL" "$SENDER_LOG"
capture_filtered_logcat "$OBSERVER_SERIAL" "$OBSERVER_LOG"

verify_logs
