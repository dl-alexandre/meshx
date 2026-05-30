# MeshX Feature-Parity Matrix

Parity means MeshX does what BitChat does on the MeshX wire. The Noise hash
choice, BitChat packet layout, and internet/Nostr transports are out of scope.

| # | Capability | Acceptance scenario | Status | Gated by |
|---|------------|---------------------|--------|----------|
| 1 | Locked/background delivery | Locked receiver gets messages sustained through 15-30 minutes screen-off; RT-01 strict pass with `after_5m > 0`. | Failing: freezes. | Hardware run plus `292da30` validation. |
| 2 | Multi-hop relay | Three-node line A to B to C delivers when A and C are out of range; TTL decrements; dedupe; up to 7 hops. | Unit-tested, not on-device. | At least 3 devices. |
| 3 | Store-and-forward | Message to offline peer is queued and delivered when it returns. | Unit-tested. | 2 devices, offline to online. |
| 4 | E2E private message | Noise XX session plus encrypted private A to B; stable identity fingerprint. | `meshx_noise` vectors pass; on-device E2E unverified. | 2 devices. |
| 5 | Delivery/read acks plus retry | Delivery ack on receipt, auto-retry if no ack, read receipt. | Code-complete in protocol/runtime/store; needs hardware validation. | Hardware. |
| 6 | Fragmentation / large payload | Payload larger than MTU is fragmented and reassembled, or delivered by GATT fetch. | Partial. | Code verify plus hardware. |
| 7 | Broadcast plus channels | Broadcast to all peers; channel scoping. | Channels in `MeshxProtocol.Packet`/`Framing` + `Router` filtered subscribe (done 2026-05-27); chat UI (`ChatScreen` + `ChannelsScreen` + `Chat.ChannelViewModel` + `Chat.Composer`) on master 2026-05-30 — see `docs/chat_interface_mvp.md`. Hardware cross-device receive still gated on RT-01 deploy. | Hardware (two-device chat). |
| 8 | Adaptive power | Duty-cycled scan/advertise; survives hours on battery. | Likely gap. | Code plus long hardware run. |

Critical path: #1 gates real-world validation. Then validate #2/#3 on mesh
hardware, #4 crypto on device, and #5 ack/retry/read-receipt behavior. #8 is
last because it needs long battery runs.
