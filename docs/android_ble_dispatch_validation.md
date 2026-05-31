# Android BLE Dispatch — On-Device Validation Ledger (M20–M22)

First hardware validation of the M20–M22 dispatch spike. Proves a
planned `Attempt` can reach `dev.mob.mob.ble.BleDispatcher` on a
real Android device and produce an auditable v1 wire-format outcome
that round-trips into the canonical `AttemptOutcome` shape.

## Environment

| Item | Value |
| --- | --- |
| Date (validation pass) | 2026-05-11 |
| Host | macOS (Darwin 25.4.0), Apple Silicon |
| JDK | Temurin 21 |
| Gradle wrapper | 8.7 (already bootstrapped per M4 ledger) |
| Android Gradle Plugin | 8.5.0 |
| Kotlin | 1.9.24 |
| Device model | **Samsung SM-T577U** (Galaxy Tab Active 3) — same hardware as M4 |
| Android version | **13** (API 33) |
| ADB serial | `R52W90AW7EN` |

## Commands executed

```bash
# Kotlin JVM tests (validates BleDispatcher argument handling without
# touching real BLE).
cd apps/mob_node/android
./gradlew --no-daemon test
# → 14 tests, 0 failures
#     BleDispatcherTest:   7 tests
#     BleEventTest:        5 tests
#     FakeBleBridgeTest:   2 tests

# Install + launch.
ANDROID_SERIAL=R52W90AW7EN ./gradlew --no-daemon installDebug
adb -s R52W90AW7EN shell am force-stop dev.mob.mob
adb -s R52W90AW7EN shell am start -n dev.mob.mob/.MainActivity

# Capture (separate terminal).
adb -s R52W90AW7EN logcat -c
adb -s R52W90AW7EN logcat -s MobBle:I MobBleDispatch:I AndroidRuntime:E

# Resolve button bounds and tap.
adb -s R52W90AW7EN shell input keyevent KEYCODE_WAKEUP
adb -s R52W90AW7EN shell uiautomator dump /sdcard/ui.xml
# DISPATCH TEST ATTEMPT button at bounds [0,560][1200,656] → tap (600, 608).

# Test 1: dispatch with BT on (default state from prior M4 pass).
adb -s R52W90AW7EN shell settings get global bluetooth_on  # → 1
adb -s R52W90AW7EN shell input tap 600 608

# Test 2: dispatch with BT off — proves the failure path.
adb -s R52W90AW7EN shell svc bluetooth disable
adb -s R52W90AW7EN shell input tap 600 608

# Re-enable for tidiness.
adb -s R52W90AW7EN shell svc bluetooth enable
```

## Minimal fixes required during the spike

One Kotlin null-safety compile error, same shape as the M4
`BleAdvertiser` fix: `adapter?.bluetoothLeAdvertiser` is null-checked
but Kotlin flow analysis doesn't carry that back to subsequent uses
of `adapter`. Resolved with `adapter?.isEnabled != true` which
collapses both the null and disabled cases into one branch. Two
lines of code, no contract impact.

No Elixir changes were required beyond the planned additions
(`AttemptOutcome` kind taxonomy extension + new `Dispatcher.Android`
module). The existing offline pipeline kept its 254 tests green.

## Results

### Test 1: dispatch with Bluetooth ENABLED

Tapped DISPATCH TEST ATTEMPT once. Logcat captured one line on the
`MobBleDispatch` tag:

```json
{
  "v": 1,
  "event": "attempt_outcome",
  "attempt_id": "spike-att-0",
  "target_peer_id": "mob-spike",
  "kind": "dispatched",
  "reason": null,
  "adapter": "ble_android",
  "outcome_at_ms": 7983697
}
```

The local BLE stack accepted the brief (≈250 ms) manufacturer-data
advertisement carrying the spike payload. The Kotlin
`BleDispatcher.dispatch` returned `Kind.DISPATCHED` synchronously.
No `AdvertiseCallback.onStartFailure` fired.

### Test 2: dispatch with Bluetooth DISABLED

Disabled BT, tapped DISPATCH TEST ATTEMPT once. Logcat:

```json
{
  "v": 1,
  "event": "attempt_outcome",
  "attempt_id": "spike-att-0",
  "target_peer_id": "mob-spike",
  "kind": "failed",
  "reason": "bluetooth_off",
  "adapter": "ble_android",
  "outcome_at_ms": 7995673
}
```

Confirms the real-adapter failure path produces `kind: "failed"`
(NOT `:failed_simulated`) with a closed-taxonomy reason. The
distinction between `:failed` and `:failed_simulated` is exactly
what the M19–M20 outcome taxonomy was designed to preserve.

### Cross-language round-trip

Piped the Test 1 JSON line through an Elixir IEx session and
reconstructed it as a canonical `Mob.Node.BLE.AttemptOutcome`:

```elixir
%Mob.Node.BLE.AttemptOutcome{
  attempt_id: "spike-att-0",
  message_id: <<0, 0, 0, 0, …, 0>>,
  target_peer_id: "mob-spike",
  target_device_ids: ["AA:BB:CC:DD:EE:FF"],
  kind: :dispatched,
  outcome_at: 7_983_697,
  reason: nil,
  adapter: :ble_android
}
```

Programmatic assertions in the same session:

```
kind in closed set?  true
adapter is real?     true
```

The wire format Kotlin emits and the struct shape Elixir consumes
agree byte-for-byte at the field level.

### Existing test suite

```
mix test
254 tests, 0 failures   # pre-existing offline pipeline
+11 new Dispatcher.Android tests
= 265 tests total, 0 failures

./gradlew test
14 Kotlin JVM tests, 0 failures
```

## Pass / fail checklist

| Goal | Status | Evidence |
| --- | --- | --- |
| Dispatcher adapter boundary preserves outcome shape | ✅ | `Dispatcher.Android` returns `[AttemptOutcome]` of the same struct used by M17/M18 |
| New `:dispatched` / `:failed` kinds in closed taxonomy | ✅ | Both observed on hardware; pattern-match-safe set extended in `AttemptOutcome.kind` |
| Real-adapter outcomes carry `adapter: :ble_android` | ✅ | Both test runs surface this verbatim |
| Real adapter never emits `:delivered_simulated`/`:failed_simulated` | ✅ | Dedicated Elixir test (`Dispatcher.Android` `refute kind in [:delivered_simulated, :failed_simulated]`) + observed on hardware |
| Planned attempt can reach Android BLE dispatcher | ✅ | DISPATCH TEST ATTEMPT button calls `BleDispatcher.dispatch` with the same field set Elixir produces |
| Failure path observable | ✅ | Test 2 captured `kind: "failed"`, `reason: "bluetooth_off"` with BT disabled |
| Existing offline pipeline unchanged | ✅ | 254 prior tests still green |
| Hardware validation documented | ✅ | This document |

## What this is NOT proving

- **Not directed delivery.** The Kotlin dispatcher emits a brief
  manufacturer-data BLE advertisement; nothing connects to the
  target device. `:dispatched` means "local stack accepted", not
  "peer received". A return path / ack is a separate milestone.
- **Not a NIF bridge.** Elixir's `Dispatcher.Android` defaults to
  `{:error, :native_bridge_unavailable}` on hosts without the
  Android NIF, which is every runtime today (no BEAM-on-Android).
  The Kotlin side is invoked from the on-screen test button, not
  from Elixir. Wiring the NIF is a future PR.
- **Not message routing.** The spike payload is hardcoded ASCII;
  no `MessageEnvelope` is encoded or transmitted yet.
- **Not durable.** No queue, no retry, no persistence — explicitly
  out of scope per the M20–M22 plan.

## Notes for the next pass

- The chosen manufacturer CIC (`0xFFFF`) is a development placeholder.
  When MeshX gets its own Bluetooth SIG company identifier the constant
  changes in exactly one place (`BleDispatcher.MESHX_COMPANY_IDENTIFIER`).
- The 250 ms advertise window was chosen so the spike is observable
  to a nearby scanner but doesn't monopolize the radio. Real
  message delivery will probably move to GATT writes against a
  connected peer.
- The `outcome_at_ms` value is `SystemClock.elapsedRealtime()`
  (boot-relative monotonic), matching the rest of M3's wire-format
  timestamps. Wall-clock alignment is a downstream concern.
