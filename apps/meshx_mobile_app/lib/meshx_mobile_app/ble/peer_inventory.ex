defmodule MeshxMobileApp.BLE.PeerInventory do
  @moduledoc """
  Pure-data view-model over `MeshxMobileApp.BLE.PeerTable`.

  `PeerTable` is the source of truth — one row per `device_id`, with
  identity, sighting, and collision bookkeeping. This module derives a
  *logical peer* view from it:

    * Named peers (non-nil `peer_id`) collapse `device_id` rotations
      into a single `PeerSummary`. Rotation is the iOS/Android norm
      and shouldn't show up as multiple visible peers.
    * Anonymous peers (nil `peer_id`) stay one summary per `device_id`.
      Without identity evidence we can't safely merge them.

  Each `PeerSummary` is plain data. This module never formats strings,
  never emits log lines, never owns a process. Consumers (a future
  LiveView, IEx, a JSON read API, the UI on the device) all read the
  same shape — formatting is their concern.

  ## Sorting

  `list/1` returns summaries ordered by `last_seen_at` descending,
  with `display_name` ascending as a tiebreaker. The ordering is
  deterministic: replay the same capture twice and `list/1` returns
  byte-identical lists. Consumers that need a different order can
  re-sort the result.

  ## Identity confidence

  A summary-level rollup of `PeerTable.Entry`'s `identity_source` +
  `identity_collision_count`:

    * `:unknown` — anonymous (no `peer_id`).
    * `:advertised` — `peer_id` derived from an advertised local name,
      no collisions across any constituent device.
    * `:contested` — `peer_id` is set, but at least one constituent
      device has reported a *different* `peer_id` claim. Suspicious;
      the original claim is preserved.
    * `:verified` — reserved for future `:fingerprint` or
      `:signed_identity` sources. Not produced today.
  """

  alias MeshxMobileApp.BLE.PeerTable
  alias MeshxMobileApp.BLE.PeerTable.Entry
  alias MeshxMobileApp.BLE.PresencePolicy

  defmodule PeerSummary do
    @moduledoc """
    One logical peer in the inventory. Shape consumed by UI/API/log
    layers; never refer to `PeerTable.Entry` directly from those.
    """

    @type confidence :: :unknown | :advertised | :contested | :verified

    @type t :: %__MODULE__{
            peer_id: binary() | nil,
            device_ids: [binary()],
            display_name: binary(),
            identity_confidence: confidence(),
            identity_source: MeshxMobileApp.BLE.Identity.Claim.source(),
            capabilities: MeshxMobileApp.BLE.PeerCapabilities.t(),
            presence: MeshxMobileApp.BLE.PresencePolicy.state(),
            first_seen_at: integer(),
            last_seen_at: integer(),
            last_rssi: integer(),
            advertisement_seen_count: non_neg_integer(),
            collision_count: non_neg_integer(),
            last_conflicting_peer_id: binary() | nil,
            anonymous?: boolean(),
            suspicious?: boolean()
          }

    @enforce_keys [:device_ids, :display_name, :identity_confidence, :identity_source]
    defstruct peer_id: nil,
              device_ids: [],
              display_name: "",
              identity_confidence: :unknown,
              identity_source: :none,
              capabilities: %MeshxMobileApp.BLE.PeerCapabilities{},
              # Defaults to :active so callers that don't supply a clock
              # see a sensible value — presence is opt-in derived state,
              # not transport state. `PeerInventory.list/2` re-stamps
              # this when `now:` is provided.
              presence: :active,
              first_seen_at: 0,
              last_seen_at: 0,
              last_rssi: 0,
              advertisement_seen_count: 0,
              collision_count: 0,
              last_conflicting_peer_id: nil,
              anonymous?: true,
              suspicious?: false
  end

  @typedoc """
  Optional inputs for presence derivation:

    * `:now` — integer in the same scale as `observed_at_ms`. When
      provided, each summary's `presence` is derived via the supplied
      (or default) policy. When absent, `presence` stays at its
      struct default of `:active`.
    * `:policy` — `PresencePolicy.t/0`. Defaults to `PresencePolicy.default/0`.
  """
  @type opts :: [now: integer(), policy: PresencePolicy.t()]

  @doc """
  Returns the inventory as a sorted list of `PeerSummary` structs.

  Order: `last_seen_at` desc, then `display_name` asc.

  When `:now` is supplied in `opts`, each summary's `presence` is
  derived from `now - last_seen_at` against the policy. Without
  `:now`, presence stays at its struct default (`:active`) — useful
  for callers that don't track liveness.
  """
  @spec list(PeerTable.t(), opts()) :: [PeerSummary.t()]
  def list(table, opts \\ []) do
    table
    |> summaries()
    |> with_presence(opts)
    |> Enum.sort_by(fn s -> {-s.last_seen_at, s.display_name} end)
  end

  @doc """
  Returns the inventory keyed by *logical* identity.

  Named peers are keyed by `peer_id`. Anonymous peers — which can't
  safely be merged — are keyed by their lone `device_id`. The two
  keyspaces are disjoint by construction: a `peer_id` matching a
  `device_id` byte-for-byte would be a contract violation upstream.
  """
  @spec by_logical_peer(PeerTable.t(), opts()) :: %{binary() => PeerSummary.t()}
  def by_logical_peer(table, opts \\ []) do
    table
    |> summaries()
    |> with_presence(opts)
    |> Enum.into(%{}, fn s ->
      key = s.peer_id || hd(s.device_ids)
      {key, s}
    end)
  end

  @doc """
  Returns the inventory keyed by `device_id`. Rotated `device_id`s
  belonging to the same logical peer all map to the *same* summary —
  useful when you have a `device_id` from a fresh event and want to
  look up the logical peer it belongs to.
  """
  @spec by_device(PeerTable.t(), opts()) :: %{binary() => PeerSummary.t()}
  def by_device(table, opts \\ []) do
    table
    |> summaries()
    |> with_presence(opts)
    |> Enum.flat_map(fn s -> Enum.map(s.device_ids, &{&1, s}) end)
    |> Map.new()
  end

  @doc """
  Re-stamps the `presence` field on each summary given a `now` and a
  policy. Useful when you already have a list of summaries (e.g. cached
  for the UI) and want to refresh just the liveness state without
  rebuilding from the table.

  With no `:now` opt the input is returned unchanged.
  """
  @spec with_presence([PeerSummary.t()], opts()) :: [PeerSummary.t()]
  def with_presence(summaries, opts) when is_list(summaries) do
    case Keyword.fetch(opts, :now) do
      :error ->
        summaries

      {:ok, now} ->
        policy = Keyword.get(opts, :policy, PresencePolicy.default())

        Enum.map(summaries, fn %PeerSummary{} = s ->
          %{s | presence: PresencePolicy.derive(s.last_seen_at, now, policy)}
        end)
    end
  end

  # ── derivation ────────────────────────────────────────────────────────────

  defp summaries(table) do
    {named, anonymous} =
      table
      |> Map.values()
      |> Enum.split_with(&(&1.peer_id != nil))

    named_summaries =
      named
      |> Enum.group_by(& &1.peer_id)
      |> Enum.map(fn {peer_id, entries} -> from_named_group(peer_id, entries) end)

    anonymous_summaries = Enum.map(anonymous, &from_anonymous_entry/1)

    named_summaries ++ anonymous_summaries
  end

  defp from_named_group(peer_id, entries) do
    most_recent = Enum.max_by(entries, & &1.last_seen_at)
    collision_count = entries |> Enum.map(& &1.identity_collision_count) |> Enum.sum()

    %PeerSummary{
      peer_id: peer_id,
      device_ids: entries |> Enum.map(& &1.device_id) |> Enum.sort(),
      display_name: peer_id,
      identity_confidence: confidence_for_named(most_recent.identity_source, collision_count),
      identity_source: most_recent.identity_source,
      # Capabilities follow the same rule as last_rssi: take from the
      # most recently sighted device. A peer that rotated `device_id`s
      # and re-advertised v1 caps on the new identity should surface
      # those caps, not the older device's.
      capabilities: most_recent.capabilities,
      first_seen_at: entries |> Enum.map(& &1.first_seen_at) |> Enum.min(),
      last_seen_at: most_recent.last_seen_at,
      last_rssi: most_recent.last_rssi,
      advertisement_seen_count: entries |> Enum.map(& &1.advertisement_seen_count) |> Enum.sum(),
      collision_count: collision_count,
      last_conflicting_peer_id: last_conflicting(entries),
      anonymous?: false,
      suspicious?: collision_count > 0
    }
  end

  defp from_anonymous_entry(%Entry{} = e) do
    %PeerSummary{
      peer_id: nil,
      device_ids: [e.device_id],
      display_name: e.device_id,
      identity_confidence: :unknown,
      identity_source: :none,
      capabilities: e.capabilities,
      first_seen_at: e.first_seen_at,
      last_seen_at: e.last_seen_at,
      last_rssi: e.last_rssi,
      advertisement_seen_count: e.advertisement_seen_count,
      collision_count: 0,
      last_conflicting_peer_id: nil,
      anonymous?: true,
      suspicious?: false
    }
  end

  defp confidence_for_named(_source, collisions) when collisions > 0, do: :contested
  defp confidence_for_named(:advertised_name, 0), do: :advertised
  defp confidence_for_named(:fingerprint, 0), do: :verified
  defp confidence_for_named(:signed_identity, 0), do: :verified
  # Defensive default — should not occur because named entries by
  # construction have a non-:none source, but keep the fallback so a
  # future schema drift doesn't crash the inventory layer.
  defp confidence_for_named(_other, _zero), do: :advertised

  defp last_conflicting(entries) do
    # Prefer the most-recently-seen device's `last_conflicting_peer_id`,
    # falling back to any non-nil claim across the group. Stable under
    # replay because `entries` itself is derived deterministically.
    entries
    |> Enum.sort_by(& &1.last_seen_at, :desc)
    |> Enum.find_value(& &1.last_conflicting_peer_id)
  end
end
