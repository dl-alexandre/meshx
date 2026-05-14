defmodule MeshxMobileApp.BLE.PeerChurn do
  @moduledoc """
  Pure churn diff between two `MeshxMobileApp.BLE.PeerInventory` snapshots.

  Given a `previous` list of `PeerSummary` structs and a `current` list
  (typically taken at two different `now` values from the same
  `PeerTable`), `diff/3` returns a deterministic, sorted list of
  `ChurnEvent` structs explaining what changed.

  ## Matching strategy

  Same logical peer is identified by either:

    * matching `peer_id` (named ↔ named), or
    * any shared `device_id` (covers anonymous ↔ named promotions and
      anonymous ↔ anonymous continuity).

  This works because `PeerTable` is monotonic — entries are never
  removed — so a peer present in `previous` always has a corresponding
  summary in `current` with at least one overlapping `device_id`.
  Summaries in `current` with no overlap are brand-new (`:appeared`).

  ## Events

    * `:appeared` — peer not present in `previous`. Carries
      `previous_presence: nil`, `previous_summary: nil`.
    * `:became_stale` — presence went `:active` → `:stale`.
    * `:expired` — presence went `:active|:stale` → `:expired`.
    * `:reappeared` — presence went `:expired` → not `:expired`.
      Strict definition: a `:stale` → `:active` transition without
      crossing expiration is *not* a reappearance.
    * `:identity_promoted` — peer gained a stable `peer_id` for the
      first time (`previous.peer_id == nil`, `current.peer_id != nil`).
      Positive transition: the inventory layer can now correlate
      future sightings of this peer across `device_id` rotation.
    * `:identity_conflict` — same logical entity now claims a
      *different* non-nil `peer_id` than it did in `previous`. Rare
      under the M8 sticky-identity rules at the `PeerTable` level;
      surfaces when grouping shifts across snapshots, or when a peer
      legitimately re-issues its identity. Distinct from
      `:collision_detected` — see below.
    * `:collision_detected` — at least one underlying
      `PeerTable.Entry` for this logical peer had its
      `identity_collision_count` increase between snapshots. The
      summary itself may still report the original `peer_id`
      (sticky); the bump is the runtime telling you a contending
      claim arrived on the wire. Pairs naturally with
      `:identity_conflict` but is at a different layer: conflict is
      a snapshot-to-snapshot identity mismatch, collision is a
      per-event counter bump.

  Transitions not in this list — identical snapshots, `:stale` →
  `:active` without an expiration in between, named-to-anonymous
  demotion (impossible under M8 rules anyway) — produce no event.
  The output list can be empty.

  ## Examples

  Peer appears, ages, dies, returns:

      iex> events = PeerChurn.diff(prev_active, curr_stale)
      [%ChurnEvent{kind: :became_stale, ...}]
      iex> PeerChurn.diff(curr_stale, much_later_expired)
      [%ChurnEvent{kind: :expired, ...}]
      iex> PeerChurn.diff(much_later_expired, after_refresh)
      [%ChurnEvent{kind: :reappeared, ...}]

  Anonymous peer gains a stable identity:

      iex> PeerChurn.diff(anon_only, after_named_advertisement)
      [%ChurnEvent{kind: :identity_promoted,
                   previous_summary: %{peer_id: nil},
                   current_summary: %{peer_id: "meshx-alpha"}}]

  Contending claim arrives for an already-named peer:

      iex> PeerChurn.diff(named_clean, after_conflicting_ad)
      [%ChurnEvent{kind: :collision_detected, ...}]

  ## Determinism

  Diff is a pure function of its inputs. Same `(previous, current,
  opts)` → same event list, byte-identical. The output is sorted by
  `(kind, peer_or_device_key)` so order is independent of input
  ordering.

  ## What this is not

  No timers, no processes, no routing, no UI formatting. The
  `detected_at` field is whatever the caller passes — typically the
  same `now` used to derive `current`'s presence, but the diff
  function doesn't enforce that.
  """

  alias MeshxMobileApp.BLE.PeerInventory.PeerSummary

  defmodule ChurnEvent do
    @moduledoc """
    One observable change between two inventory snapshots.

    `peer_id` is `nil` for events about anonymous peers — the
    `current_summary.device_ids` (or `previous_summary.device_ids`)
    is the stable identifier in that case.
    """

    @type kind ::
            :appeared
            | :became_stale
            | :expired
            | :reappeared
            | :identity_promoted
            | :identity_conflict
            | :collision_detected

    @type t :: %__MODULE__{
            kind: kind(),
            peer_id: binary() | nil,
            previous_presence: MeshxMobileApp.BLE.PresencePolicy.state() | nil,
            current_presence: MeshxMobileApp.BLE.PresencePolicy.state() | nil,
            previous_summary: PeerSummary.t() | nil,
            current_summary: PeerSummary.t() | nil,
            detected_at: integer()
          }

    @enforce_keys [:kind, :detected_at]
    defstruct kind: nil,
              peer_id: nil,
              previous_presence: nil,
              current_presence: nil,
              previous_summary: nil,
              current_summary: nil,
              detected_at: 0
  end

  @typedoc """
  Diff options:

    * `:detected_at` — integer stamped on every produced event. Caller
      decides the scale; this module never reads a clock. Defaults to
      0 (useful for unit tests where the exact value doesn't matter).
  """
  @type opts :: [detected_at: integer()]

  @doc """
  Diffs two inventory snapshots. Returns a deterministically-sorted
  list of `ChurnEvent`s.
  """
  @spec diff([PeerSummary.t()], [PeerSummary.t()], opts()) :: [ChurnEvent.t()]
  def diff(previous, current, opts \\ []) when is_list(previous) and is_list(current) do
    detected_at = Keyword.get(opts, :detected_at, 0)

    prev_by_peer_id = index_by_peer_id(previous)
    prev_by_device = index_by_device(previous)

    Enum.flat_map(current, fn %PeerSummary{} = curr ->
      case match(curr, prev_by_peer_id, prev_by_device) do
        nil -> [appeared(curr, detected_at)]
        %PeerSummary{} = prev -> transitions(prev, curr, detected_at)
      end
    end)
    |> Enum.sort_by(&{Atom.to_string(&1.kind), key_for(&1)})
  end

  # ── matching ───────────────────────────────────────────────────────────────

  defp index_by_peer_id(summaries) do
    summaries
    |> Enum.filter(&(&1.peer_id != nil))
    |> Map.new(fn s -> {s.peer_id, s} end)
  end

  defp index_by_device(summaries) do
    summaries
    |> Enum.flat_map(fn s -> Enum.map(s.device_ids, &{&1, s}) end)
    |> Map.new()
  end

  defp match(%PeerSummary{peer_id: nil} = curr, _by_peer, by_device) do
    Enum.find_value(curr.device_ids, fn d -> Map.get(by_device, d) end)
  end

  defp match(%PeerSummary{peer_id: peer_id} = curr, by_peer, by_device) do
    case Map.fetch(by_peer, peer_id) do
      {:ok, prev} ->
        prev

      :error ->
        # Named in current but not in previous as named — check whether
        # this is an anonymous-to-named promotion via device_id overlap.
        Enum.find_value(curr.device_ids, fn d -> Map.get(by_device, d) end)
    end
  end

  # ── event derivation ───────────────────────────────────────────────────────

  defp appeared(curr, detected_at) do
    %ChurnEvent{
      kind: :appeared,
      peer_id: curr.peer_id,
      previous_presence: nil,
      current_presence: curr.presence,
      previous_summary: nil,
      current_summary: curr,
      detected_at: detected_at
    }
  end

  defp transitions(prev, curr, detected_at) do
    []
    |> add_presence_event(prev, curr, detected_at)
    |> add_identity_event(prev, curr, detected_at)
    |> add_collision_event(prev, curr, detected_at)
  end

  defp add_presence_event(events, prev, curr, detected_at) do
    case {prev.presence, curr.presence} do
      {:active, :stale} ->
        [build_event(:became_stale, prev, curr, detected_at) | events]

      {p, :expired} when p in [:active, :stale] ->
        [build_event(:expired, prev, curr, detected_at) | events]

      {:expired, c} when c in [:active, :stale] ->
        [build_event(:reappeared, prev, curr, detected_at) | events]

      _ ->
        events
    end
  end

  defp add_identity_event(events, prev, curr, detected_at) do
    case {prev.peer_id, curr.peer_id} do
      # No change in identity.
      {same, same} ->
        events

      # Anonymous → named: peer gained stable identity. Positive.
      {nil, _new_name} ->
        [build_event(:identity_promoted, prev, curr, detected_at) | events]

      # Named → different named: rare under M8 sticky rules; surfaces
      # when grouping shifts or a peer legitimately re-issues itself.
      {_old_name, new_name} when is_binary(new_name) ->
        [build_event(:identity_conflict, prev, curr, detected_at) | events]

      # Named → nil: demotion. Sticky rules at PeerTable prevent this
      # for a single device, but a snapshot transition could still
      # produce it if e.g. device grouping changed. Treat as conflict —
      # a peer "losing" its identity is at least as suspicious as
      # gaining a competing one.
      {_old_name, nil} ->
        [build_event(:identity_conflict, prev, curr, detected_at) | events]
    end
  end

  defp add_collision_event(events, prev, curr, detected_at) do
    if curr.collision_count > prev.collision_count do
      [build_event(:collision_detected, prev, curr, detected_at) | events]
    else
      events
    end
  end

  defp build_event(kind, prev, curr, detected_at) do
    %ChurnEvent{
      kind: kind,
      peer_id: curr.peer_id || prev.peer_id,
      previous_presence: prev.presence,
      current_presence: curr.presence,
      previous_summary: prev,
      current_summary: curr,
      detected_at: detected_at
    }
  end

  # Stable sort key. peer_id when present, else the first device_id —
  # using the same stable identifier the inventory layer uses.
  defp key_for(%ChurnEvent{} = e) do
    s = e.current_summary || e.previous_summary
    s.peer_id || hd(s.device_ids)
  end
end
