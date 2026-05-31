defmodule Mob.Node.BLE.PeerTable do
  @moduledoc """
  In-memory inventory of BLE peers observed via canonical events.

  **Passive only.** Built solely from `Mob.Node.BLE.Events.*` —
  no routing, no handshakes, no crypto, no persistence. The table is
  derived state: throw it away and rebuild from a replay and you get
  the same result.

  ## Identity

  Entries are keyed by `device_id` (transport-local, opaque) — the same
  identifier `DeviceDiscovered` / `AdvertisementReceived` /
  `ConnectionStateChanged` already carry.

  Each entry also carries an optional stable `peer_id` derived
  passively from the advertisement payload via
  `Mob.Node.BLE.Identity.classify/1`, along with the evidence
  `identity_source` (`:none`, `:advertised_name`, with `:fingerprint`
  and `:signed_identity` reserved). Use `by_peer_id/1` to collapse
  `device_id` rotations into a single logical peer.

  ## Identity collisions

  Two distinct `device_id`s claiming the same `peer_id` is grouping,
  not a collision — that's what `by_peer_id/1` is for and that's how
  iOS UUID rotation surfaces.

  A single `device_id` claiming a *different* `peer_id` over time is
  suspicious. The table never overwrites a stable `peer_id` from the
  same transport device: the first claim wins, `identity_collision_count`
  bumps, and `last_conflicting_peer_id` records what was attempted.
  Callers can inspect those fields to surface the suspicion — this
  module emits no logs, raises no errors, and never quarantines an
  entry.

  ## Tracked fields

  Per `Entry`:

    * `device_id` — the key.
    * `first_seen_at` / `last_seen_at` — `observed_at_ms` from the
      first/most-recent advertisement-class event. Boot-relative
      milliseconds (Android `SystemClock.elapsedRealtime`), not
      wall-clock.
    * `last_rssi` — RSSI from the most-recent advertisement.
    * `advertisement_seen_count` — total `DeviceDiscovered` +
      `AdvertisementReceived` events for this device.
    * `error_count` — `Error` events with a matching `device_id`. Stays
      at zero for the common case where errors aren't peer-specific.
  """

  alias Mob.Node.BLE.{Events, Identity, PeerCapabilities}
  alias Mob.Node.BLE.Identity.Claim

  defmodule Entry do
    @moduledoc false

    @type t :: %__MODULE__{
            device_id: binary(),
            peer_id: binary() | nil,
            identity_source: Claim.source(),
            identity_collision_count: non_neg_integer(),
            last_conflicting_peer_id: binary() | nil,
            capabilities: PeerCapabilities.t(),
            first_seen_at: integer(),
            last_seen_at: integer(),
            last_rssi: integer(),
            advertisement_seen_count: non_neg_integer(),
            error_count: non_neg_integer()
          }

    @enforce_keys [:device_id, :first_seen_at, :last_seen_at, :last_rssi]
    defstruct device_id: nil,
              peer_id: nil,
              identity_source: :none,
              identity_collision_count: 0,
              last_conflicting_peer_id: nil,
              capabilities: %PeerCapabilities{},
              first_seen_at: 0,
              last_seen_at: 0,
              last_rssi: 0,
              advertisement_seen_count: 0,
              error_count: 0
  end

  @type t :: %{optional(binary()) => Entry.t()}

  @spec new() :: t()
  def new, do: %{}

  @spec size(t()) :: non_neg_integer()
  def size(table), do: map_size(table)

  @spec get(t(), binary()) :: Entry.t() | nil
  def get(table, device_id), do: Map.get(table, device_id)

  @doc """
  Returns peers sorted by most-recently-seen first. Useful for UI
  surfaces that want a stable ordering without re-sorting per render.
  """
  @spec sorted(t()) :: [Entry.t()]
  def sorted(table) do
    table
    |> Map.values()
    |> Enum.sort_by(& &1.last_seen_at, :desc)
  end

  @doc """
  Folds a canonical BLE event into the table. Events without an
  advertisement-class presence signal (`MessageReceived`,
  `ReceivedMessage`, status-class errors, etc.) leave the table
  unchanged.
  """
  @spec update(t(), Mob.Node.BLE.Event.t()) :: t()
  def update(table, %Events.DeviceDiscovered{} = e) do
    record_sighting(
      table,
      e.device_id,
      Identity.classify(e.advertisement),
      PeerCapabilities.parse(e.advertisement),
      e.observed_at_ms,
      e.rssi
    )
  end

  def update(table, %Events.AdvertisementReceived{} = e) do
    record_sighting(
      table,
      e.device_id,
      Identity.classify(e.advertisement),
      PeerCapabilities.parse(e.advertisement),
      e.observed_at_ms,
      e.rssi
    )
  end

  def update(table, %Events.Error{device_id: nil}), do: table

  def update(table, %Events.Error{device_id: device_id}) when is_binary(device_id) do
    # Errors don't create entries — a peer only exists in the table
    # once we've seen an advertisement from it. If the error references
    # an unknown device_id, leave the table untouched.
    case Map.get(table, device_id) do
      nil -> table
      %Entry{} = entry -> Map.put(table, device_id, %{entry | error_count: entry.error_count + 1})
    end
  end

  # ConnectionStateChanged, PeerAuthenticated, MessageReceived,
  # ReceivedMessage, DeviceLost — all valid canonical events but none of them carry the
  # advertisement-class signal this table is built from. Leaving the
  # table unchanged is the correct passive behavior; once handshake
  # events flow, a separate clause can attach peer_id without touching
  # the existing entries.
  def update(table, _other), do: table

  defp record_sighting(
         table,
         device_id,
         %Claim{} = claim,
         %PeerCapabilities{} = caps,
         observed_at_ms,
         rssi
       ) do
    Map.update(
      table,
      device_id,
      %Entry{
        device_id: device_id,
        peer_id: claim.peer_id,
        identity_source: claim.source,
        capabilities: caps,
        first_seen_at: observed_at_ms,
        last_seen_at: observed_at_ms,
        last_rssi: rssi,
        advertisement_seen_count: 1
      },
      fn %Entry{} = entry ->
        entry
        |> merge_identity(claim)
        |> merge_capabilities(caps)
        |> Map.merge(%{
          last_seen_at: max(entry.last_seen_at, observed_at_ms),
          last_rssi: rssi,
          advertisement_seen_count: entry.advertisement_seen_count + 1
        })
      end
    )
  end

  # Capability merge rule — sticky on absence:
  #
  #   no version claimed now  → keep existing
  #   version claimed now     → replace with the new claim
  #
  # Rationale: a peer that previously advertised v1 capabilities and
  # then emits a name-only advertisement (no 0xFF/MX record) should
  # not be downgraded to "unknown caps" — that's almost certainly
  # the advertisement budget at work, not a capability change. A
  # peer that advertises a *different* version or *different* flag
  # set legitimately replaces. We don't track "conflicting caps"
  # the way identity tracks conflicting names; capability churn is
  # expected to be benign in the passive layer.
  defp merge_capabilities(%Entry{} = entry, %PeerCapabilities{protocol_version: nil}), do: entry

  defp merge_capabilities(%Entry{} = entry, %PeerCapabilities{} = caps),
    do: %{entry | capabilities: caps}

  # Identity merge rules — first-wins for stability, with collisions
  # counted on the entry rather than overwritten silently.
  #
  #   anonymous + anonymous   → no change
  #   anonymous + named       → promote (claim wins, source advances)
  #   named     + same name   → no change (reinforces existing identity)
  #   named     + no name     → no demotion (sticky)
  #   named     + diff name   → COLLISION: keep existing, bump counter,
  #                             record the conflicting claim so callers
  #                             can see what was attempted
  #
  # The collision case is the only place this module emits observable
  # suspicion signal. It's still passive — no warnings, no logging,
  # no side effects — just state callers can inspect.
  defp merge_identity(%Entry{} = entry, %Claim{peer_id: nil}), do: entry

  defp merge_identity(%Entry{peer_id: nil} = entry, %Claim{peer_id: new, source: src}) do
    %{entry | peer_id: new, identity_source: src}
  end

  defp merge_identity(%Entry{peer_id: same} = entry, %Claim{peer_id: same}), do: entry

  defp merge_identity(%Entry{peer_id: _existing} = entry, %Claim{peer_id: different}) do
    %{
      entry
      | identity_collision_count: entry.identity_collision_count + 1,
        last_conflicting_peer_id: different
    }
  end

  @doc """
  Groups entries by their derived `peer_id`. The `nil` key collects
  all anonymous peers (one entry per `device_id`). Named peers are
  collapsed across `device_id` rotations under their stable key.

  This is the inventory shape the runtime should reason about: a list
  of *logical* peers rather than a list of transport sightings.
  """
  @spec by_peer_id(t()) :: %{(binary() | nil) => [Entry.t()]}
  def by_peer_id(table) do
    table
    |> Map.values()
    |> Enum.group_by(& &1.peer_id)
  end
end
