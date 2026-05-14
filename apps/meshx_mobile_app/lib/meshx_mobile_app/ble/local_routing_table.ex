defmodule MeshxMobileApp.BLE.LocalRoutingTable do
  @moduledoc """
  Pure candidate route table for local BLE peer observations.

  This module derives deterministic direct-route candidates from
  `PeerInventory` summaries. It is a planning/read-model boundary only:
  it does not forward, route live traffic, ACK, retry, persist, fetch,
  scan, advertise, encrypt, authenticate, or run in the background.
  """

  alias MeshxMobileApp.BLE.{PeerCapabilities, PeerInventory}
  alias MeshxMobileApp.BLE.PeerInventory.PeerSummary

  defmodule Entry do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :destination_peer_id,
               :next_hop_peer_id,
               :target_device_ids,
               :presence,
               :identity_confidence,
               :last_seen_at,
               :last_rssi,
               :meshx_capable?,
               :forwardable?,
               :blocked_reasons
             ]}
    @enforce_keys [
      :destination_peer_id,
      :next_hop_peer_id,
      :target_device_ids,
      :presence,
      :identity_confidence,
      :last_seen_at,
      :last_rssi,
      :meshx_capable?,
      :forwardable?,
      :blocked_reasons
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            destination_peer_id: binary() | nil,
            next_hop_peer_id: binary() | nil,
            target_device_ids: [binary()],
            presence: atom(),
            identity_confidence: PeerSummary.confidence(),
            last_seen_at: integer(),
            last_rssi: integer(),
            meshx_capable?: boolean(),
            forwardable?: boolean(),
            blocked_reasons: [atom()]
          }
  end

  defmodule Selection do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :destination_peer_id,
               :status,
               :selected,
               :candidates,
               :blocked_reasons,
               :routing_claim_allowed?
             ]}
    @enforce_keys [
      :destination_peer_id,
      :status,
      :selected,
      :candidates,
      :blocked_reasons,
      :routing_claim_allowed?
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            destination_peer_id: binary(),
            status: :selected | :no_forwardable_route,
            selected: Entry.t() | nil,
            candidates: [Entry.t()],
            blocked_reasons: [atom()],
            routing_claim_allowed?: false
          }
  end

  @spec entries([PeerSummary.t()]) :: [Entry.t()]
  def entries(peer_summaries) when is_list(peer_summaries) do
    peer_summaries
    |> Enum.map(&entry/1)
    |> Enum.sort_by(&sort_key/1)
  end

  @spec from_peer_table(map(), keyword()) :: [Entry.t()]
  def from_peer_table(peer_table, opts \\ []) do
    peer_table
    |> PeerInventory.list(opts)
    |> entries()
  end

  @spec select([PeerSummary.t()] | [Entry.t()], binary()) :: Selection.t()
  def select(candidates_or_summaries, destination_peer_id) when is_binary(destination_peer_id) do
    candidates = normalize_candidates(candidates_or_summaries)

    matching =
      candidates
      |> Enum.filter(&(&1.destination_peer_id == destination_peer_id))
      |> Enum.sort_by(&sort_key/1)

    case Enum.find(matching, & &1.forwardable?) do
      %Entry{} = selected ->
        %Selection{
          destination_peer_id: destination_peer_id,
          status: :selected,
          selected: selected,
          candidates: matching,
          blocked_reasons: [],
          routing_claim_allowed?: false
        }

      nil ->
        %Selection{
          destination_peer_id: destination_peer_id,
          status: :no_forwardable_route,
          selected: nil,
          candidates: matching,
          blocked_reasons: blocked_reasons(matching),
          routing_claim_allowed?: false
        }
    end
  end

  @spec snapshot([PeerSummary.t()] | [Entry.t()]) :: map()
  def snapshot(candidates_or_summaries) do
    candidates = normalize_candidates(candidates_or_summaries)

    %{
      table_version: 1,
      boundary: :local_observation_route_candidates,
      entries: candidates,
      entry_count: length(candidates),
      forwardable_count: Enum.count(candidates, & &1.forwardable?),
      routing_claim_allowed?: false,
      forwarding_service_available?: false,
      delivery_semantics_available?: false,
      notes: [
        "Route candidates are derived from local peer observations only.",
        "A selected candidate is not a forwarding action and not delivery proof.",
        "Live routing claims remain blocked until forwarding, delivery semantics, and hardware validation exist."
      ]
    }
  end

  @spec json_snapshot([PeerSummary.t()] | [Entry.t()]) :: map()
  def json_snapshot(candidates_or_summaries) do
    candidates_or_summaries
    |> snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp normalize_candidates([]), do: []

  defp normalize_candidates([%Entry{} | _] = entries), do: Enum.sort_by(entries, &sort_key/1)
  defp normalize_candidates([%PeerSummary{} | _] = summaries), do: entries(summaries)

  defp normalize_candidates(_other), do: []

  defp entry(%PeerSummary{} = summary) do
    meshx_capable? = PeerCapabilities.mesh_x_capable?(summary.capabilities)
    blocked_reasons = entry_blockers(summary, meshx_capable?)

    %Entry{
      destination_peer_id: summary.peer_id,
      next_hop_peer_id: summary.peer_id,
      target_device_ids: summary.device_ids,
      presence: summary.presence,
      identity_confidence: summary.identity_confidence,
      last_seen_at: summary.last_seen_at,
      last_rssi: summary.last_rssi,
      meshx_capable?: meshx_capable?,
      forwardable?: blocked_reasons == [],
      blocked_reasons: blocked_reasons
    }
  end

  defp entry_blockers(%PeerSummary{} = summary, meshx_capable?) do
    [
      if(is_nil(summary.peer_id), do: :anonymous_peer),
      if(summary.presence != :active, do: :not_active),
      if(summary.suspicious?, do: :identity_contested),
      if(summary.identity_confidence not in [:advertised, :verified], do: :identity_not_usable),
      if(not meshx_capable?, do: :missing_meshx_capability)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp blocked_reasons([]), do: [:no_observed_candidate]

  defp blocked_reasons(candidates) do
    candidates
    |> Enum.flat_map(& &1.blocked_reasons)
    |> Enum.uniq()
    |> case do
      [] -> [:no_forwardable_candidate]
      reasons -> reasons
    end
  end

  defp sort_key(%Entry{} = entry) do
    {
      if(entry.forwardable?, do: 0, else: 1),
      confidence_rank(entry.identity_confidence),
      -entry.last_seen_at,
      -entry.last_rssi,
      entry.destination_peer_id || "",
      entry.target_device_ids
    }
  end

  defp confidence_rank(:verified), do: 0
  defp confidence_rank(:advertised), do: 1
  defp confidence_rank(:contested), do: 2
  defp confidence_rank(:unknown), do: 3
  defp confidence_rank(_confidence), do: 4
end
