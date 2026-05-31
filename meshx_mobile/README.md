# Mob.Node (Swift Native Harness)

iOS / macOS native harness for the MeshX BLE wire format specified in
[`../docs/WIRE_FORMAT.md`](../docs/WIRE_FORMAT.md).

The production mobile app surface is now the Mob app in
[`../apps/mob_node`](../apps/mob_node). This Swift package is
kept for byte-vector interop tests, CoreBluetooth bridge work, and direct
hardware smoke tests while the Mob native bridge is completed.

## Status

| Layer | Status | Notes |
|-------|--------|-------|
| MeshX frame codec (§3) | ✅ done | Byte-identical to Elixir, verified against [`../docs/WIRE_VECTORS.md`](../docs/WIRE_VECTORS.md). |
| Application fragmentation (§4) | ✅ done | Round-trip + byte-layout verified. Per-fragment `msg_id` uses random values (Elixir uses `phash2`; see WIRE_VECTORS.md note). |
| BLE chunk codec MXB1 (§2) | ✅ done | Encode + out-of-order reassembly verified. |
| Noise XX handshake (§5) | ✅ done | `Noise_XX_25519_ChaChaPoly_BLAKE2s` implemented with CryptoKit X25519/ChaChaPoly plus local BLAKE2s/HKDF. Deterministic handshake and transport vectors are tested. |
| Secure BLE session boundary (§1/§5) | ✅ done | `MXN1` control frames drive the Noise handshake; encrypted data packets decrypt back to normal application frames. Covered by tests. |
| CoreBluetooth transport (§1) | 🟡 hardware untested | Central scan/connect and peripheral advertise/GATT responder are wired. Reconnect strategy, MTU negotiation timing, and error retry are TODO. |

`swift test` passes 25/25 tests.

## Build and test

Requires Xcode's Swift (homebrew/nanobrew toolchains may have linker
issues on macOS 26). Use `xcrun swift` if your default `swift` is from
a third-party toolchain:

```sh
cd mob_node
xcrun swift test
```

Or open `Package.swift` in Xcode and `Cmd+U`.

## iOS harness

A small SwiftUI harness lives in `Examples/Mob.NodeHarness`. It scans for
MeshX BLE peers, can advertise as a BLE peripheral responder, shows
connection/events, and sends an encrypted ping once a secure peer is connected.
Use it as a bridge-validation tool, not as the long-term app shell.

Generate the local Xcode project with XcodeGen:

```sh
cd mob_node/Examples/Mob.NodeHarness
xcodegen generate
open Mob.NodeHarness.xcodeproj
```

The generated `.xcodeproj` is ignored by git. Use a real iOS device for BLE
smoke tests; the simulator is useful for confirming the app links and renders.

For a two-device iOS smoke test:

1. On one device, select `Advertise` and tap `Advertise`.
2. On the other device, select `Scan` and tap `Scan`.
3. Wait for `Secure peer connected` on both devices.
4. Tap `Ping Secure Peer`; the other device should log a received `data` frame.

## Architecture

```
+-------------------+   Application bytes
| Your app          |
+-------------------+
        |
        v
+-------------------+   Noise transport encryption
| MobSecureSession|   MXN1 handshake + plaintext/ciphertext frames
+-------------------+
        |
        v
+-------------------+   Optional: split large payloads
| Fragment          |   into <= 185-byte fragment packets
+-------------------+
        |
        v
+-------------------+   Header + CRC, little-endian
| Frame             |   ✅ matches docs/WIRE_VECTORS.md V1-V4
+-------------------+
        |
        v
+-------------------+   MXB1 chunk header, big-endian
| Chunk             |   ✅ matches docs/WIRE_VECTORS.md V6
+-------------------+
        |
        v
+-------------------+
| MobBLEClient /  |   CoreBluetooth central/peripheral: RX writes,
| MobBLEPeripheral|   TX notifications
+-------------------+
```

## What's needed to reach hardware testing

1. **Smoke test against a Pi.** On a Linux+BlueZ host, run:

   ```sh
   # From the mob Elixir umbrella root:
   MESHX_NODE_ID=pi-receiver \
   MESHX_READY_FILE=/tmp/ble_ready \
   MESHX_PAYLOAD_FILE=/tmp/ble_payload.bin \
   mix run --no-halt scripts/ble_receiver.exs
   ```

   From an iOS device or macOS host running this Swift package, scan for
   the MeshX service UUID, connect, complete the Noise handshake, and
   send a single data frame. Receiver writes `{peer_id, msg_id, payload}`
   to `MESHX_PAYLOAD_FILE` and exits 0 on success.

2. **Handle MTU.** iOS negotiates ATT MTU automatically up to 185
   (CoreBluetooth caps at 185 for write-without-response). Android needs
   `requestMtu(517)` post-connect; not applicable here.

3. **Background mode.** If you need to receive frames while the app is
   backgrounded, declare `bluetooth-central` in `UIBackgroundModes` in
   `Info.plist`. Even then, iOS will throttle scanning aggressively.

## Project layout

```
mob_node/
├── Package.swift
├── README.md
├── Examples/
│   └── Mob.NodeHarness/ # SwiftUI iOS test app, generated with XcodeGen
├── Sources/Mob.Node/
│   ├── Frame.swift       # MeshX frame codec, CRC
│   ├── Fragment.swift    # Application-level fragmentation
│   ├── Chunk.swift       # MXB1 BLE chunk codec + reassembler
│   ├── BLAKE2s.swift     # BLAKE2s + HMAC used by Noise HKDF
│   ├── Noise.swift       # Noise XX session + MXN1 wrapper
│   ├── SecureSession.swift # Frame/Noise bridge for BLE sessions
│   └── BLE.swift         # CoreBluetooth client (hardware untested)
└── Tests/Mob.NodeTests/
    ├── NoiseSessionTests.swift
    ├── SecureSessionTests.swift
    └── WireVectorsTests.swift
```

## License

Same as the parent MeshX project.
