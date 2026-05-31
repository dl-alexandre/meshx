# MeshX Wire Format Specification

This document specifies the on-the-wire encoding of MeshX traffic so a
non-Elixir client (iOS Swift, Android Kotlin, embedded C) can interoperate
with an Elixir MeshX node over BLE.

The MeshX protocol is layered. A single application byte traverses, in order:

1. **Application payload** (your data)
2. **Noise transport encryption** (ChaCha20-Poly1305) — when secured
3. **Fragmentation** (optional, application-level, for payloads larger than the per-frame budget)
4. **MeshX frame** (header + CRC, little-endian)
5. **BLE chunking** (transport-level, MTU-sized chunks, big-endian header)
6. **GATT write** to the peer's RX characteristic

A client implementation must produce and consume all six layers correctly.

> **Endianness warning.** Layers 4 and 5 use *different* byte orders.
> The MeshX frame header is **little-endian**. The BLE chunk header is
> **big-endian**. This is the most common interop mistake.

---

## 1. GATT Service and Characteristics

A MeshX node advertises a single primary GATT service and exposes two
characteristics under it.

| Role | UUID (default) | Properties |
|------|----------------|------------|
| Service | `8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f1000` | primary |
| RX (peer → me) | `8f4f1202-6f3d-4f9c-9e3b-7f4a4f0f1000` | `write`, `write-without-response` |
| TX (me → peer, notifications) | `8f4f1203-6f3d-4f9c-9e3b-7f4a4f0f1000` | `notify` |

The service UUID is also placed in the LE advertisement so peers can
filter scans on it.

UUIDs are configurable at node startup. A client and server **must** be
configured with the same triple to interoperate. The defaults above are
what `Mob.Routing.BLE.BluezBridge` uses out of the box.

**Direction convention.** RX and TX are named from the perspective of the
*characteristic owner*. To send a frame to a peer, write to that peer's
**RX** characteristic. To receive frames from a peer, subscribe to that
peer's **TX** characteristic (via `StartNotify`).

**Initiating side.** Each node acts as both peripheral (advertising +
hosting the GATT service) and central (scanning + connecting). Either
side may initiate the GATT connection. Discovery uses the advertised
service UUID to filter scan results.

---

## 2. BLE Chunk Layer (`MXB1`)

A MeshX frame (Layer 4 below) is often larger than the negotiated ATT
MTU. The BLE transport splits each frame into chunks before issuing GATT
writes, and reassembles on receipt.

### Chunk header

Each GATT write/notify carries exactly one chunk:

```
+---------+-------------+--------+--------+----------------------+
| "MXB1"  | stream_id   | seq    | total  | payload bytes        |
| 4 bytes | 4 bytes BE  | 2 BE   | 2 BE   | (mtu - 12) bytes max |
+---------+-------------+--------+--------+----------------------+
```

| Field | Size | Encoding | Notes |
|-------|------|----------|-------|
| Magic | 4 | ASCII `MXB1` | Allows the receiver to distinguish chunked frames from bare frames (legacy clients). |
| `stream_id` | 4 | uint32 big-endian | Random per outbound frame. Distinguishes interleaved frames from the same peer. |
| `seq` | 2 | uint16 big-endian | Chunk index, 0-based. |
| `total` | 2 | uint16 big-endian | Total chunks in this frame. Constant across all chunks of one frame. |
| Payload | variable | raw bytes | Max `mtu - 12` bytes per chunk. The final chunk may be shorter. |

The header is **big-endian** (network order) and 12 bytes. Chunk size
target is `mtu - 12`; default `mtu` is 185 (a common BLE 4.2 ATT MTU
after the 3-byte ATT header on iOS/Android), so chunks are up to 173
bytes of frame data.

### Reassembly rules

- Buffer chunks keyed by `(peer_id, stream_id)`.
- When `len(received_chunks) == total`, concatenate by ascending `seq`
  to recover the MeshX frame.
- If a duplicate `seq` arrives, replace. If `total` changes for an
  existing `(peer_id, stream_id)`, discard the buffer and start fresh.
- A reasonable timeout (e.g. 10s) should evict half-assembled frames so
  memory can't grow unbounded if a chunk is lost.

If a received chunk does **not** begin with `MXB1`, treat it as a bare
unframed MeshX frame (back-compat path; not used by current clients).

---

## 3. MeshX Frame (Layer 4)

After BLE reassembly, you hold a single MeshX frame:

```
+----+----+----+----+----------+----------+-------------+----------+
| ver| typ| fl | ttl| len      | msg_id   | payload     | crc16    |
| u8 | u8 | u8 | u8 | u16 LE   | u32 LE   | len bytes   | u16 LE   |
+----+----+----+----+----------+----------+-------------+----------+
```

| Field | Size | Encoding | Notes |
|-------|------|----------|-------|
| `version` | 1 | uint8 | Current value: `0x01`. |
| `type` | 1 | uint8 | Packet type, see table below. |
| `flags` | 1 | uint8 | Bit flags, see table below. |
| `ttl` | 1 | uint8 | Decremented on each hop. Default 64. |
| `payload_len` | 2 | uint16 little-endian | Length of `payload` field. Max 65,535. |
| `msg_id` | 4 | uint32 little-endian | Caller-chosen message id (for dedup, ACK correlation). |
| `payload` | `payload_len` | opaque | Interpretation depends on `type` + `flags`. |
| `crc` | 2 | uint16 little-endian | `crc32(header ‖ payload) & 0xFFFF` — truncated CRC-32. |

Total fixed overhead: 12 bytes (10-byte header + 2-byte CRC).

### Packet types

| Value | Type | Purpose |
|-------|------|---------|
| `0x01` | `data` | Application payload. |
| `0x02` | `ack` | Delivery acknowledgement or read receipt for a previously sent packet (correlates by `msg_id`). |
| `0x03` | `gossip` | Routing/topology gossip. |
| `0x04` | `control` | Out-of-band control. Used for the Noise handshake (see §5). |
| `0x05` | `fragment` | Application-level fragmentation (see §4). |

### Flags

| Bit | Name | Meaning when set |
|-----|------|------------------|
| `0x01` | `encrypted` | `payload` is Noise ciphertext (see §5). |
| `0x02` | `fragmented` | `payload` is a fragment chunk (see §4). |
| `0x04` | `ack_requested` | Sender requests an `ack` packet referencing this `msg_id`. |

### ACK payloads

Current ACK packets carry a typed receipt payload:

```
+---------+------+--------------+
| version | kind | acked_msg_id |
| u8      | u8   | u32 LE       |
+---------+------+--------------+
```

| Field | Size | Encoding | Notes |
|-------|------|----------|-------|
| `version` | 1 | uint8 | Current value: `0x01`. |
| `kind` | 1 | uint8 | `0x01` = delivery acknowledgement, `0x02` = read receipt. |
| `acked_msg_id` | 4 | uint32 little-endian | The original packet `msg_id` being acknowledged. |

Legacy four-byte ACK payloads (`acked_msg_id` only) are still accepted and
treated as delivery acknowledgements.

### Checksum

```
crc16 = CRC32(header_bytes || payload_bytes) & 0xFFFF
```

Computed over the 10-byte header **without** the CRC field itself, plus
the full payload. The truncation is deliberate (CRC-32 is overkill for
this size; the low 16 bits give adequate detection for small frames at
half the wire cost).

A frame with a mismatched CRC must be dropped silently.

---

## 4. Fragmentation (Layer 3, application-level)

This is **separate** from BLE chunking (§2). BLE chunking exists so a
single MeshX frame can cross a small MTU. Fragmentation exists so a
single *application message* larger than the MeshX frame budget
(typically the same MTU minus framing) can be sent as multiple frames.

A fragmented payload is sent as one or more frames with:

- `type = 0x05` (`fragment`)
- `flags` may set `0x02` (`fragmented`)
- `msg_id` is a per-fragment id (the original message id is in the payload)

### Fragment payload layout

```
+----------------+--------+--------+-----------+
| orig_msg_id    | index  | total  | chunk     |
| u32 LE         | u8     | u8     | bytes     |
+----------------+--------+--------+-----------+
```

| Field | Size | Encoding | Notes |
|-------|------|----------|-------|
| `orig_msg_id` | 4 | uint32 little-endian | The original (pre-fragmentation) message id. Same value across all fragments of one message. |
| `index` | 1 | uint8 | 0-based fragment index. |
| `total` | 1 | uint8 | Total fragments for this message. Max 255. |
| `chunk` | variable | opaque | Slice of the original payload. |

### Reassembly

Buffer fragments keyed by `(peer_id, orig_msg_id)`. When `total`
fragments are received, sort by `index` and concatenate `chunk` fields
to recover the original application payload.

Maximum reassembled payload size: `total × max_chunk_size`, capped by
the MeshX frame `payload_len` limit of 65,535 bytes.

Default `max_chunk_size` is 185 bytes (matches default BLE MTU). With
the per-fragment overhead of 6 bytes, a fragment payload is up to
≈191 bytes, plus 12 bytes of MeshX framing, plus 12 bytes of BLE chunk
header — so a fragment fits in one BLE chunk at MTU 215+, and spills
to a second chunk at MTU 185.

---

## 5. Noise Handshake and Transport Encryption (Layer 2)

MeshX uses **Noise Protocol XX** with the following primitives:

```
Noise_XX_25519_ChaChaPoly_BLAKE2s
```

- Key exchange: X25519
- AEAD: ChaCha20-Poly1305
- Hash: BLAKE2s
- Pattern: XX (3 messages, mutual authentication of static keys)

A reference Swift implementation is [Noise.swift](https://github.com/IndustrialBinaries/Noise);
for Kotlin, [Noise-Java](https://github.com/rweather/noise-java) is the closest.

### Handshake transport

The three Noise XX handshake messages are carried in MeshX `control`
packets. The payload of each handshake control packet is:

```
"MXN1" || <raw Noise XX message bytes>
```

That is: the 4-byte ASCII tag `MXN1`, followed by the bytes the Noise
library produces for that handshake step. No length prefix — the MeshX
`payload_len` field already bounds the message.

A control packet whose payload does not begin with `MXN1` is ignored
by the Noise machinery (reserved for future control types).

### Handshake flow

XX is a 3-message pattern. With the convention that the side calling
`send_packet` first is the initiator:

```
initiator                                responder
   |                                         |
   |  control(MXN1 || e)             →       |
   |  ←        control(MXN1 || e, ee, s, es) |
   |  control(MXN1 || s, se)         →       |
   |                                         |
   |  ====  session established  ===========|
```

After the third message, both sides have an established Noise
transport state with split send/receive cipher pairs. Subsequent
`data` packets are sent with `flags |= 0x01` (`encrypted`) and the
`payload` is the Noise transport ciphertext (`Cipher.encrypt(plaintext)`).

### Trust

When a session is established, the responder receives the initiator's
static public key (from message 3) and the initiator receives the
responder's static public key (from message 2). MeshX records this in
its trust store keyed by `peer_id` → static public key. A mobile
client should either:

- pin the expected static key (if known out-of-band), or
- TOFU on first contact and persist the binding.

A peer presenting a different static key on subsequent contact under
the same `peer_id` must be treated as untrusted.

### Encrypted data packets

Once established:

```
plaintext  = <application bytes>
ciphertext = Cipher.encrypt(nonce, plaintext, aad = "")
packet     = {type: data, flags: encrypted, payload: ciphertext, ...}
```

Nonces are managed by the Noise library and are monotonic. **Sessions
are not resumable.** If the underlying transport drops the peer
(`peer_down`), both sides MUST tear down their Noise state and
renegotiate from message 1. (See `Mob.Runtime.SessionManager.drop/1`.)

### AAD

The current implementation passes empty AAD (`<<>>`) to both encrypt
and decrypt. A client must match this; otherwise authentication tags
will not verify.

---

## 6. Full Encode Path (Reference)

To send an application payload `data` to a peer:

```
                  +----------------------------------+
data ───────────▶ | if secure: Noise.encrypt(data)   |
                  +----------------------------------+
                                  │
                                  ▼
                  +----------------------------------+
                  | if > max_chunk_size:             |
                  |   fragment into N fragment       |
                  |   packets                        |
                  +----------------------------------+
                                  │
                                  ▼
                  +----------------------------------+
                  | for each packet:                 |
                  |   wrap in MeshX frame (§3)       |
                  |   compute CRC                    |
                  +----------------------------------+
                                  │
                                  ▼
                  +----------------------------------+
                  | for each MeshX frame:            |
                  |   chunk into MXB1 chunks (§2)    |
                  +----------------------------------+
                                  │
                                  ▼
                  +----------------------------------+
                  | for each chunk:                  |
                  |   GATT write to peer.RX_char     |
                  +----------------------------------+
```

Decode is the same path reversed: GATT notify on local TX → reassemble
chunks → parse frame + verify CRC → defragment → if encrypted, Noise
decrypt → deliver to application.

---

## 7. Compatibility and Versioning

- `version` byte at the MeshX frame layer is currently `0x01`. A
  receiver MUST drop frames with an unknown version.
- The Noise handshake tag is `MXN1` (4 bytes). A future Noise protocol
  change (e.g. different cipher suite) will use a new tag.
- The BLE chunk magic is `MXB1`. A future chunk-format change will use
  a new tag.
- New flag bits are reserved; receivers MUST ignore unknown flags.
- New packet types are reserved; receivers SHOULD relay (subject to
  TTL) but not interpret unknown types.

---

## 8. Reference Constants

```
SERVICE_UUID  = "8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f1000"
RX_UUID       = "8f4f1202-6f3d-4f9c-9e3b-7f4a4f0f1000"
TX_UUID       = "8f4f1203-6f3d-4f9c-9e3b-7f4a4f0f1000"

NOISE_PROTOCOL = "Noise_XX_25519_ChaChaPoly_BLAKE2s"
HANDSHAKE_TAG  = "MXN1"
CHUNK_MAGIC    = "MXB1"
FRAME_VERSION  = 0x01

PACKET_DATA      = 0x01
PACKET_ACK       = 0x02
PACKET_GOSSIP    = 0x03
PACKET_CONTROL   = 0x04
PACKET_FRAGMENT  = 0x05

FLAG_ENCRYPTED      = 0x01
FLAG_FRAGMENTED     = 0x02
FLAG_ACK_REQUESTED  = 0x04

DEFAULT_MTU              = 185
DEFAULT_TTL              = 64
DEFAULT_MAX_CHUNK_SIZE   = 185   # fragment layer (§4)
BLE_CHUNK_OVERHEAD       = 12    # MXB1 header (§2)
MESHX_FRAME_OVERHEAD     = 12    # header + CRC (§3)
FRAGMENT_HEADER_SIZE     = 6     # orig_msg_id + index + total (§4)
```

---

## 9. Implementation Notes for Mobile Clients

- **iOS / CoreBluetooth.** Connection setup latency is 5–30 s on a cold
  pair. Build retry/backoff on the Noise handshake messages; do not
  treat a single failed write as a fatal session error.
- **Android / BluetoothGatt.** ATT MTU starts at 23 and must be
  negotiated up via `requestMtu(517)` after connection. Until MTU is
  negotiated, chunk size will be small; use the negotiated MTU, not
  the advertised one.
- **Background mode.** Both platforms suspend BLE radio access in deep
  background. The MeshX `mob_node` platform context tracks this; a
  mobile client should likewise gate sends and pause keep-alives when
  in `:suspended`.
- **Pairing.** The handshake is end-to-end at the Noise layer; OS-level
  BLE pairing/bonding is neither required nor sufficient. Clients
  should leave bonding off by default to avoid stuck bonds during
  development.
- **No central/peripheral assumption.** Each MeshX node is both. A
  pure-client mobile app that only acts as central is acceptable; it
  will still complete Noise as the initiator. A node that wishes to
  receive unsolicited messages must also advertise and host the GATT
  service.

---

## 10. Advert-Only Message References (BLE manufacturer data)

The GATT chunk layer above (Sections 1–8) carries the full encrypted
MeshX frame between a paired central/peripheral. Mobile mesh use
cases also need a **connectionless** path so two peers can exchange
*references* to messages without establishing a Noise session —
useful for proximity announce, neighbor presence, and store-and-
forward hint propagation. This is the advert-only profile served by
`Mob.Node.BLE` + `mob_routing_ble` on Android and iOS.

### Manufacturer data envelope

The advert-only profile rides on BLE manufacturer-specific data (AD
type `0xFF`) with company identifier **`0xFFFF`** (the Bluetooth SIG
reserved "no company" id, appropriate for a local mesh that is not a
registered Bluetooth vendor). The payload is two bytes of magic
followed by a versioned body:

| Magic   | Body shape              | Carried in                  | Receive event              |
|---------|-------------------------|-----------------------------|----------------------------|
| `M` `X` | Full v1 envelope        | Extended advertising (≤1024B) | `ReceivedMessage`        |
| `M` `B` | 22-byte legacy beacon   | Legacy advertising (≤24B)   | `ReceivedMessageBeacon`    |

A scanner that sees company `0xFFFF` and magic `MX` or `MB` parses
the body as a MeshX advert-only message. Any other manufacturer
entry, or company `0xFFFF` without the magic, falls through as a
plain `DeviceDiscovered` / `AdvertisementReceived` event.

### `MX` — Full v1 envelope

The full envelope (`Mob.Node.BLE.MessageEnvelope` v1) starts
with `'M','X', VERSION (1), 0` and carries:

```
+--------+--------+--------+--------+
|  'M'   |  'X'   | ver=1  | 0x00   |   magic + version (4 B)
+--------+--------+--------+--------+
|          message_id (16 B)        |   random per-message id
+-----------------------------------+
|        created_at_ms (8 B BE)     |   ms since epoch
+--------+--------------------------+
| ttl(1) | sender_len(1) | sender   |   length-prefixed peer id
+--------+--------------------------+
| recip_len(1) | recipient_peer_id  |   optional (len=0 -> broadcast)
+--------------+--------------------+
| type_len(1)  | payload_type       |   short ASCII tag, e.g. "TX"
+--------------+--------------------+
| cap_req(1)   | payload_len (2 BE) | payload (...)  |
+--------------+--------------------+------------------+
```

Size: ~30 B header overhead + payload. The full envelope only fits
in BLE 5 *extended* advertising; legacy advertising's 24-byte
manufacturer-data budget rejects it. **Not every controller that
*sends* extended advertising can *scan* it** — the Android BLE 5
landscape is asymmetric across hardware generations (see
[FAILURE_DOMAINS](FAILURE_DOMAINS.md#extended-advertising-scan-support-is-per-device)).

### `MB` — Legacy beacon

When the envelope won't fit legacy advertising and the peer fleet
includes hardware that can't scan extended adverts, MeshX dispatches
a 22-byte **legacy beacon** instead. The beacon carries a reference
to the message, not its payload:

```
+--------+--------+--------+--------+--------+--------+
|  'M'   |  'B'   | bvers  | evers  | kind   | flags  |   header (6 B)
+--------+--------+--------+--------+--------+--------+
|              message_id_hash (8 B)                    |   sha256(message_id)[0..8]
+--------+--------+--------+--------+--------+--------+
|              sender_peer_id_hash (8 B)                |   sha256(sender_peer_id)[0..8]
+-------------------------------------------------------+
```

Header field semantics:

- `bvers` — beacon-format version, currently `1`.
- `evers` — MeshX envelope version the beacon references (`1`).
- `kind` — payload-type tag mapped to a small enum (`0` unknown,
  `1` = `TX`, …). Receivers verify against the canonical tag set.
- `flags` — reserved, must be `0`.

A receiver that sees a beacon and wants the full payload retrieves
it via the GATT-fetch protocol (`MobFetchGatt`) keyed on the
`message_id_hash`. Subscribers operating in the advert-only profile
treat the beacon itself as the delivery: it proves the sender was
in range at time T announcing a message with those coordinates.

### v1 wire JSON (bridge protocol)

Both the native bridge (Kotlin / Swift) and the BEAM-side runtime
exchange BLE events as **v1 wire JSON**. Each event is a JSON
object with a `v` discriminator and an `event` tag; binary fields
are base64-encoded:

```json
{
  "v": 1,
  "event": "received_message_beacon",
  "beacon_version": 1,
  "envelope_version": 1,
  "payload_kind": "TX",
  "message_id_hash": "8gRcw6LUtdc=",
  "sender_peer_id_hash": "9wgG7dwoW8w=",
  "received_device_id": "5E:42:6B:2F:BF:31",
  "received_at": 159409,
  "rssi": -46,
  "raw_transport_metadata": {
    "transport": "ble_android_advertisement",
    "source_event": "advertisement_received",
    "advertisement": "AgE...",
    "beacon_payload": "TUIB...",
    "manufacturer_data": "//9NQg...",
    "company_identifier": 65535,
    "ad_type": 255
  }
}
```

The set of `event` tags is closed and corresponds 1:1 to the
`Mob.Node.BLE.Events.*` Elixir structs (`device_discovered`,
`advertisement_received`, `received_message`, `received_message_beacon`,
`connection_state_changed`, `peer_authenticated`, `message_received`,
`device_lost`, `advert_gossip_outcome`, `error`).

The Elixir `Mob.Node.BLE.BridgeProtocol` decoder accepts the
JSON form (with base64 binary fields) *and* the raw atom-keyed-map
form produced by the iOS NIF directly. Binary fields carried as
base64 on the JSON path are recursively decoded by `atomize_top_level`
before structural validation runs. **Any v1 binary field added to a
new event tag must also be added to `@b64_top_level_fields` or
`@b64_metadata_fields` in `bridge_protocol.ex`**, otherwise strict
validators will reject correctly-formatted advertisements with
`{:..._invalid_field, :the_new_field}` errors.

### Scan callback semantics

`ScanSettings.CALLBACK_TYPE_ALL_MATCHES` delivers a callback for
every advertising event observed within a peer's advertising window
— typically 15–50 callbacks per 5-second legacy beacon at default
intervals. **Counting beacon callbacks is *not* a delivery rate.**
The canonical "message received" cardinality is the cardinality of
the set of `{sender_peer_id_hash, message_id_hash}` pairs observed
(or `{sender_peer_id, message_id}` on the full-envelope path).
Reliability claims must dedup on those keys.
