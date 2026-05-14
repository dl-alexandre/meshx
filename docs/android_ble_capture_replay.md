# BLE v1 Capture and Replay

Capture/replay tooling for the unified BLE bridge contract
(`MeshxMobileApp.BLE.BridgeProtocol`). Decouples Session-level work
from physical hardware: any recorded session can be replayed
deterministically into a fresh `MeshxMobileApp.Session` without an
Android or iOS device attached.

The tooling is intentionally narrow — it captures and replays v1 wire
format and nothing else. No mesh routing, no peer graph, no crypto,
no persistence beyond the capture file.

## File format

Newline-delimited JSON. One v1 wire-format event per line, exactly as
emitted by `dev.meshx.mob.ble.BleEvent.toJsonObject()`. Blank lines
and lines beginning with `#` are skipped by the replay loader, so
curated fixtures can carry inline annotations.

```jsonl
# cross_platform_discovery.jsonl
{"v":1,"event":"device_discovered","device_id":"4F:9C:5A:DC:6E:6D","rssi":-50,"advertisement":"AgEa…","observed_at_ms":761035}
{"v":1,"event":"advertisement_received","device_id":"4F:9C:5A:DC:6E:6D","rssi":-50,"advertisement":"AgEa…","observed_at_ms":761312}
```

Binary fields (`advertisement`, `payload`) are base64 strings —
`MeshxMobileApp.BLE.Replay` performs the base64→binary step uniformly
before handing each line to `BridgeProtocol.decode/1`, so the wire
shape replay sees is identical to what the production NIF transport
will deliver.

## Capture

The capture mix task reads `adb logcat` output (or any text stream)
from STDIN, strips the logcat prefix (`timestamp pid pid I MeshxBle: `),
validates that each payload parses as JSON, and appends to a
timestamped JSONL file.

```bash
# Live capture from a device
adb -s R52W90AW7EN logcat -s MeshxBle:I | mix meshx.mobile.capture

# Capture an existing logcat dump
mix meshx.mobile.capture < /tmp/meshxble.log

# Explicit output path
mix meshx.mobile.capture --output captures/run-42.jsonl
```

Default output is `priv/captures/<UTC-timestamp>.jsonl` inside the
`meshx_mobile_app` app. The directory is gitignored — only curated
slices under `test/fixtures/captures/` are checked in.

Per-line `.` and `x` markers stream to stderr so a long-running
capture shows liveness (`--quiet` to suppress).

## Replay

### From a mix task (manual debugging)

```bash
mix meshx.mobile.replay test/fixtures/captures/cross_platform_discovery.jsonl
```

Starts a fresh `MeshxMobileApp.Session`, pumps every line through
`Adapter.event_message/1` (which routes through `BridgeProtocol.decode/1`),
and prints the final snapshot:

```
replayed 8 events from test/fixtures/captures/cross_platform_discovery.jsonl
status: Waiting for Bluetooth
peer_id: nil
event log (most recent first):
  [2026-05-11T21:53:35Z] Advertisement — 4F:9C:5A:DC:6E:6D (rssi -50)
  [2026-05-11T21:53:35Z] Device discovered — 4F:9C:5A:DC:6E:6D (rssi -50)
  …
```

### From ExUnit (deterministic tests)

```elixir
alias MeshxMobileApp.BLE.Replay
alias MeshxMobileApp.Session

{:ok, session} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)

count = Replay.into(session, "test/fixtures/captures/cross_platform_discovery.jsonl")
assert count == 8

# snapshot/1 is a GenServer.call — drains the mailbox to this point,
# so the assertion is deterministic without sleeps or polling.
snapshot = Session.snapshot(session)
assert Enum.any?(snapshot.events, &(&1.title == "Device discovered"))
```

The replay path is the same path live transport takes:

```
JSONL line
  → :json.decode/1            (transport adapter: text → map)
  → base64 → binary           (transport adapter: JSON → NIF shape)
  → Adapter.event_message/1
  → BridgeProtocol.decode/1   (single normalization point)
  → %MeshxMobileApp.BLE.Events.X{}
  → Session.handle_info/2
```

Adapters (`NativeBridge.IOS`, future Android NIF sink) are never
invoked during replay. They remain dumb.

## Fixture corpus

Real-hardware captures live under
`apps/meshx_mobile_app/test/fixtures/captures/`:

| File | Lines | Notes |
| --- | --- | --- |
| `cross_platform_discovery.jsonl` | 8 | iPad MeshX peer (`4F:9C:5A:DC:6E:6D`); advertisement contains ASCII `meshx-ipad`. Proves Android scanner ingests iOS broadcasts on the unified contract. |
| `bluetooth_off.jsonl` | 2 | Two `bluetooth_off` errors emitted before BT was enabled on the tablet during the hardware validation pass. |
| `mixed_devices_burst.jsonl` | 50 | First 50 lines of the live capture: a `bluetooth_off` error followed by a burst of `device_discovered` + `advertisement_received` from 60+ unique nearby BLE devices. |

All three were extracted verbatim from the Galaxy Tab Active 3 capture
documented in `docs/android_ble_validation.md`. To regenerate or extend
the corpus:

```bash
adb logcat -s MeshxBle:I > /tmp/meshxble.log    # while the app scans
mix meshx.mobile.capture --output apps/meshx_mobile_app/test/fixtures/captures/<name>.jsonl \
    < /tmp/meshxble.log
```

## What replay deliberately does **not** do

- No real-time pacing — every event is sent as fast as the target
  process can drain its mailbox. Replay is a determinism tool, not a
  load test.
- No schema migration. A capture file recorded today must replay
  identically tomorrow. If `BridgeProtocol` ever needs a v2 wire
  format, the loader will need an explicit version-aware path —
  silent transformation would break the contract.
- No re-emission to a different transport. Replay drives a process,
  not a wire.
- No mesh, no crypto, no peer authentication, no reconnect — those
  remain out of scope until their own PRs land.
