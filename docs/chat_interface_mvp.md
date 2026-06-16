# Chat interface MVP

A bitchat-style group-chat UI built on the mob runtime that landed on master
on 2026-05-30. The wire and runtime layers (channels #7, acks/retry #5,
fragmentation #6, multi-hop/TTL #2) already shipped earlier; this doc covers
the Elixir + `Mob.Screen` UI sitting on top.

## What it does today

- Per-channel scrollback with sender label, body, and clock-relative meta
  ("you · 5s ago · sending").
- Compose: tap **Chat** on `HomeScreen` → **ChannelsScreen** lists your
  joined channels (persisted across restarts) → tap one → **ChatScreen**
  with a `<TextField>` and Send button. Send broadcasts a `:data` packet
  via `Mob.Runtime.Router.broadcast_packet/2`; the runtime handles ack /
  retry / multi-hop unchanged.
- Outbound entries appear immediately as `:pending`; ack reconciliation
  (`:pending → :delivered`) is the next follow-up (see below).
- Channel join: type a name (with or without `#`), tap Join — persisted to
  `Mob.Store.DB` under `{:chat, :joined_channels}`.

## Module layout

```
apps/mob_node/lib/mob_node/
  chat/
    identity.ex                  # nickname overlay over Mob.Store.Identity
    composer.ex                  # text -> %Packet{} (pure)
    channel_view_model.ex        # GenServer per channel
    channel_native_surface.ex    # VM snapshot -> screen surface (pure)
  chat_screen.ex                 # Mob.Screen: messages + compose row
  channels_screen.ex             # Mob.Screen: channel list + Join row
  home_screen.ex                 # nav entry button (push_screen)
```

Tests in the mirror tree under `test/mob_node/chat/` cover the four
pure modules; 34 unit tests total.

## Identity contract

`Mob.Node.Chat.Identity.get/0` returns

```elixir
%{
  peer_id:      "abc…",     # Base64URL of the Noise static public key (display)
  wire_peer_id: <<32 raw bytes>>,  # raw 32-byte public key (wire / envelope)
  nickname:     "anon-abcdefgh"    # user-editable, default derived from peer_id
}
```

Two peer-id forms by design: `MessageEnvelope`'s `@max_peer_id_size` is 32
bytes, so the wire side carries the raw public key. The Base64URL form is
display-only.

The Noise static keypair is the same one `Mob.Store.Identity.ensure_local/0`
manages — chat reuses it rather than creating a parallel identity.

## Send flow

1. `ChatScreen` `:tap, :send` reads `assigns.draft`, calls
   `ChannelViewModel.send_text(vm, text)`.
2. `ChannelViewModel.handle_call({:send_text, text})` →
   `Composer.build_packet(channel, text)`.
3. `Composer.build_packet/3`:
   - reads `Identity.get/0` for `wire_peer_id`,
   - builds `%MessageEnvelope{payload_type: "CHAT", payload: text, sender_peer_id: wire_peer_id, …}`,
   - encodes,
   - wraps as `%Mob.Protocol.Packet{type: :data, channel_id: channel,
     flags: flag_channel | flag_ack_requested, payload: encoded_envelope,
     msg_id: <<le32 of first 4 bytes of envelope.message_id>>}`,
   - returns `{:ok, packet, message_id}` (the 16-byte envelope id for ack
     correlation).
4. VM dispatches `Mob.Runtime.Router.broadcast_packet/2`.
5. VM appends a `%Message{direction: :out, status: :pending}` entry locally
   so the UI echoes immediately, and pushes the new snapshot to subscribers.

## Receive flow

1. `Mob.Runtime.Router` notifies subscribers whose channel filter matches:
   `{:mob_runtime, :packet, transport, peer_id, %Packet{}}`.
2. `ChannelViewModel.handle_info/2` parses the envelope (`MessageEnvelope.parse/1`),
   filters on `payload_type == "CHAT"`, and appends a
   `%Message{direction: :in, status: :delivered, …}`.
3. Snapshot pushed to all `subscribe/2` subscribers; `ChatScreen` re-renders.

The `ChannelNativeSurface.from_self?` flag compares each message's
`sender_peer_id` (raw bytes) against the screen's `local_peer_id` (also
raw bytes from `Identity.wire_peer_id`), so the user's own messages render
on a `:primary` background regardless of which device they were sent from.

## Wire shape (recap)

Same `%Packet{}` and `%MessageEnvelope{}` the rest of the runtime uses
— chat does not introduce new wire types. The chat-specific marker is
`MessageEnvelope.payload_type == "CHAT"` (a length-prefixed string in the
envelope). `Composer.payload_type/0` returns the constant for receivers
who want to filter at the envelope layer.

## Current limits / follow-ups

- **`:pending → :delivered` reconciliation** — outbound entries stay
  `:pending` after Router accepts the packet. Hooks into the Router's
  ack notification (`Mob.Protocol.Ack.decode_receipt/1` already handles
  the receipt; the VM just needs a `handle_info` clause that finds the
  matching `:out` entry by `message_id` and flips status).
- **Per-channel supervision** — `ChatScreen` starts a `ChannelViewModel`
  inline at mount; leaving the screen drops state. A `DynamicSupervisor`
  + `Registry` keyed by `channel_id` would let `ChannelsScreen` show
  unread counts by `snapshot`-ing each VM, and survive screen pops.
- **DM (recipient-scoped messages)** — `Composer` already accepts
  `:recipient_peer_id`; the UI affordance and a per-peer view aren't built.
- **Receive on-device validation** — the receive-pipeline gap was closed
  on the same merge (the `Mob.Routing.BLE` → `BleSelfTest` wiring), but
  `mix mob.deploy --native` must run with valid hex.pm auth before the
  new `.so` reaches a device. Until then the chat UI works locally but
  cross-device receive is untested.
- **Encryption** — **group (channel) encryption is implemented** via
  Sender Keys (Signal-style symmetric ratchet), chosen over MLS/TreeKEM
  because a lossy, server-less BLE mesh can't carry MLS's ordered-commit
  delivery assumptions. Threat model: *confidential to current
  key-holders* — new joiners can't read history (forward secrecy), no
  enforced member removal.

  Layers:
    * `Mob.Noise.SenderKey` / `GroupCipher` / `GroupSession` /
      `SenderKeyDistribution` — pure ratchet + ChaCha20-Poly1305 AEAD,
      out-of-order tolerance, replay rejection.
    * `Mob.Store.GroupKeys` — per-channel chain persistence (CubDB).
    * `Mob.Runtime.GroupKeyManager` + `GroupKeyControl` — owns channel
      state; `ensure_channel`/`encrypt`/`install_remote`/`decrypt` and the
      distribution/request control codec (carried over the existing
      pairwise Noise sessions, never broadcast).
    * Chat path — `Composer` seals into a `CHATG` envelope
      (`Mob.Node.Chat.GroupPayload`); `ChannelViewModel` decrypts on
      receive and surfaces undecryptable messages as **locked**
      ("🔒 waiting for key"); the channel surface shows a lock badge. The
      packet stays cleartext so relay/TTL/ack are unaffected.

  **Remaining integration:** automatic sender-key *distribution over the
  live Router/BLE* — i.e. wiring `GroupKeyManager.ensure_channel`'s SKDM
  and the request/reply control messages onto `Router.send_packet(..,
  secure: true)` + a control-packet ingress branch, plus a join-time
  "encrypt this channel" affordance. The engine + on-demand request/reply
  logic are built and unit-tested; binding them to peer events is the
  final mile (gated with the rest of live BLE on hardware — see
  `remaining_items_audit.md`).

  Accepted limitation: sender keys are symmetric, so a key-holder could
  forge messages attributed to another member. Per-message signatures (a
  versioned SKDM upgrade) would close it.
