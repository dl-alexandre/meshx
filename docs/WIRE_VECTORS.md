# MeshX Wire Test Vectors

This file contains byte-exact test vectors for the formats defined in
[`WIRE_FORMAT.md`](./WIRE_FORMAT.md). A non-Elixir client implementing the
spec should produce bit-identical bytes for these inputs (encode) and
recover the stated inputs from these bytes (decode).

The frame-layer vectors (V1–V4) are pinned by
`apps/mob_protocol/test/mob_protocol/wire_vectors_test.exs`. If the
Elixir encoder ever drifts from these bytes, that test fails. Treat any
deviation as a wire-format break and bump the format version.

All hex is lowercase, no spacing, big-string. Convert to bytes by pairing
hex digits (`01 01 00 40 …`).

---

## V1 — Data packet, default TTL, no flags

**Input:**

```
type    = data (0x01)
version = 0x01
flags   = 0x00
ttl     = 64 (0x40)
msg_id  = 42 (0x0000002A, little-endian)
payload = "hello mesh"  (10 bytes)
```

**Encoded frame (22 bytes):**

```
010100400a002a00000068656c6c6f206d657368c339
```

Breakdown:

| Bytes | Hex | Field |
|-------|-----|-------|
| 0 | `01` | version |
| 1 | `01` | type (data) |
| 2 | `00` | flags |
| 3 | `40` | ttl (64) |
| 4–5 | `0a00` | payload_len = 10 (LE) |
| 6–9 | `2a000000` | msg_id = 42 (LE) |
| 10–19 | `68656c6c6f206d657368` | payload "hello mesh" |
| 20–21 | `c339` | crc16 = 0x39c3 (LE) |

`crc16 = CRC32(bytes[0..19]) & 0xFFFF`.

---

## V2 — Control packet, empty payload

**Input:**

```
type    = control (0x04)
flags   = 0x00
ttl     = 64
msg_id  = 0
payload = <empty>
```

**Encoded (12 bytes):**

```
010400400000000000003d27
```

Minimum legal frame size: 12 bytes (10-byte header + 2-byte CRC, zero payload).

---

## V3 — ACK with `ack_requested` flag and `ttl = 5`

**Input:**

```
type    = ack (0x02)
flags   = ack_requested (0x04)
ttl     = 5
msg_id  = 0xDEADBEEF
payload = <empty>
```

**Encoded (12 bytes):**

```
010204050000efbeadde90b5
```

Note `efbeadde`: `0xDEADBEEF` little-endian.

---

## V4 — Fragmented payload (3 chunks of 4 bytes from 10-byte payload)

**Input to fragmenter:**

```
orig_msg_id    = 0x11223344
payload        = "ABCDEFGHIJ"  (10 bytes)
max_chunk_size = 4
ttl            = 32 (0x20)
flags          = 0
```

Produces three `fragment` packets (type 0x05) with these encoded frames:

| Idx | msg_id (phash2) | Encoded frame |
|-----|-----------------|---------------|
| 0 | `0x075F8A70` | `010500200a00708a5f0744332211000341424344d8a9` |
| 1 | `0x02AC3398` | `010500200a009833ac024433221101034546474852e0` |
| 2 | `0x03E3112B` | `0105002008002b11e303443322110203494a0518` |

Fragment payload layout (inside each frame, after the 10-byte frame header):

```
+----------------+--------+--------+-----------+
| orig_msg_id    | index  | total  | chunk     |
| 0x11223344 LE  | u8     | u8     | <= 4 B    |
+----------------+--------+--------+-----------+
```

- Fragment 0 chunk: `"ABCD"` (`41424344`).
- Fragment 1 chunk: `"EFGH"` (`45464748`).
- Fragment 2 chunk: `"IJ"` (`494a`) — short final chunk, frame length reflects this.

### A note on the per-fragment `msg_id`

The msg_id of each fragment frame is `:erlang.phash2({orig_msg_id, index})`.
This is BEAM-specific and not easily reproduced in Swift/Kotlin. A
mobile encoder MAY substitute any unique 32-bit value for the
per-fragment msg_id without breaking reassembly — only the receiver's
de-duplication may admit duplicates. Reassembly itself uses the
`orig_msg_id` field in the fragment payload, not the frame's msg_id.

---

## V5 — Noise handshake control prefix

The first 4 bytes of any handshake control packet's payload:

```
"MXN1" = 4d584e31
```

The remainder of the payload is the raw Noise XX message bytes produced
by the Noise library (e.g. `Decibel` on Elixir, `Noise.swift` on iOS,
`noise-java` on Android) with protocol name:

```
Noise_XX_25519_ChaChaPoly_BLAKE2s
```

Handshake message sizes for XX with this suite are fixed by Noise:

| Message | Direction | Size |
|---------|-----------|------|
| `e` | initiator → responder | 32 bytes (1 ephemeral pubkey) |
| `e, ee, s, es` | responder → initiator | 96 bytes (1 ephemeral pubkey + 1 encrypted static pubkey + 16-byte tag) |
| `s, se` | initiator → responder | 64 bytes (1 encrypted static pubkey + 16-byte tag + payload tag) |

Add 4 bytes of `MXN1` prefix to each, then 12 bytes of MeshX frame
overhead, then BLE chunking. Total wire bytes for handshake at MTU 185:
all three messages fit in one BLE chunk each.

---

## V6 — BLE chunk header (`MXB1`)

Reference vector — the BLE chunk layer is implemented in the Python
bridge, not in the Elixir tree. These bytes match
`apps/mob_routing_ble/priv/bin/mob_bluez_bridge`'s
`chunk_frame` function.

**Input:**

```
frame      = 50 bytes of 0xAA
mtu        = 30  (chunk_size = mtu - 12 = 18)
stream_id  = 7
```

Produces 3 chunks:

| Idx | Header (12 bytes) | Header hex | + Payload (18 / 18 / 14 bytes of 0xAA) |
|-----|--------------------|-----------|-----------------------------------------|
| 0/3 | `MXB1` + `00000007` + `0000` + `0003` | `4d58423100000007 00000003` | `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` |
| 1/3 | `MXB1` + `00000007` + `0001` + `0003` | `4d58423100000007 00010003` | `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` |
| 2/3 | `MXB1` + `00000007` + `0002` + `0003` | `4d58423100000007 00020003` | `aaaaaaaaaaaaaaaaaaaaaaaaaaaa` |

Full chunk bytes:

```
4d5842310000000700000003aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
4d5842310000000700010003aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
4d5842310000000700020003aaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

> **Endianness reminder.** The 12-byte chunk header is **big-endian**:
> `stream_id::u32-BE, seq::u16-BE, total::u16-BE`. This is the only
> big-endian field in the stack; the MeshX frame (§3 of WIRE_FORMAT.md)
> is little-endian.

---

## How to verify a client implementation

1. **Frame round-trip.** Encode V1's input → expect V1's bytes. Decode
   V1's bytes → expect V1's input fields and a valid CRC.
2. **CRC.** Flip any byte of V1's frame, attempt decode, expect
   `crc mismatch` error.
3. **Fragment reassembly.** Decode each V4 frame, then reassemble using
   the `orig_msg_id` / `index` / `total` fields. Expect
   `(0x11223344, "ABCDEFGHIJ")`.
4. **Chunk reassembly.** Concatenate V6 chunks 0, 1, 2 by `seq` after
   stripping the 12-byte header. Expect 50 bytes of `0xAA`.
5. **Noise handshake.** Run the standard `Noise_XX_25519_ChaChaPoly_BLAKE2s`
   test vectors from the Noise library of your choice against a peer
   running the Elixir MeshX node. Any compliant Noise library should
   interop after the `MXN1` prefix is stripped on receive and prepended
   on send.

A client that passes 1–4 against this file and successfully exchanges
one Noise-encrypted `data` packet with the Elixir MeshX node is
considered wire-conformant.
