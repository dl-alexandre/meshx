defmodule Mob.Node.BLE.BeaconFetchPlanner do
  @moduledoc """
  Pure candidate selection for legacy beacon envelope fetches.

  The planner only ranks already-known inventory entries. It does not
  fetch, connect, route, retry, persist, acknowledge, or infer success.
  """

  alias Mob.Node.BLE.{BeaconFetchRequest, PeerCapabilities}
  alias Mob.Node.BLE.PeerInventory.PeerSummary

  defmodule Candidate do
    @moduledoc false

    @enforce_keys [:peer_id, :device_ids, :source, :rank]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            peer_id: binary(),
            device_ids: [binary()],
            source: PeerSummary.t(),
            rank: map()
          }
  end

  @type opts :: [limit: pos_integer()]

  @spec select(BeaconFetchRequest.t(), [PeerSummary.t()], opts()) :: [Candidate.t()]
  def select(%BeaconFetchRequest{} = request, summaries, opts \\ []) when is_list(summaries) do
    limit = Keyword.get(opts, :limit, :all)
    allowed = MapSet.new(request.candidate_source_peer_ids)
    restrict? = MapSet.size(allowed) > 0

    summaries
    |> Enum.filter(&eligible?(&1, allowed, restrict?))
    |> Enum.sort_by(&sort_key(&1, request))
    |> Enum.map(&candidate(&1, request))
    |> maybe_limit(limit)
  end

  defp eligible?(%PeerSummary{peer_id: nil}, _allowed, _restrict?), do: false

  defp eligible?(%PeerSummary{presence: presence}, _allowed, _restrict?) when presence != :active,
    do: false

  defp eligible?(%PeerSummary{} = summary, allowed, true) do
    MapSet.member?(allowed, summary.peer_id)
  end

  defp eligible?(%PeerSummary{}, _allowed, false), do: true

  defp sort_key(%PeerSummary{} = summary, %BeaconFetchRequest{} = request) do
    {
      source_hash_rank(summary, request),
      mob_capable_rank(summary),
      confidence_rank(summary.identity_confidence),
      -summary.last_seen_at,
      summary.display_name,
      summary.peer_id
    }
  end

  defp candidate(%PeerSummary{} = summary, %BeaconFetchRequest{} = request) do
    %Candidate{
      peer_id: summary.peer_id,
      device_ids: summary.device_ids,
      source: summary,
      rank: %{
        sender_hash_match: source_hash_rank(summary, request) == 0,
        mob_capable: PeerCapabilities.mesh_x_capable?(summary.capabilities),
        identity_confidence: summary.identity_confidence,
        last_seen_at: summary.last_seen_at
      }
    }
  end

  defp source_hash_rank(%PeerSummary{peer_id: peer_id}, %BeaconFetchRequest{
         sender_peer_hash: sender_peer_hash
       }) do
    if short_hash(peer_id) == sender_peer_hash, do: 0, else: 1
  end

  defp mob_capable_rank(%PeerSummary{capabilities: caps}) do
    if PeerCapabilities.mesh_x_capable?(caps), do: 0, else: 1
  end

  defp confidence_rank(:verified), do: 0
  defp confidence_rank(:advertised), do: 1
  defp confidence_rank(:contested), do: 2
  defp confidence_rank(:unknown), do: 3
  defp confidence_rank(_), do: 4

  defp maybe_limit(candidates, :all), do: candidates

  defp maybe_limit(candidates, limit) when is_integer(limit) and limit > 0,
    do: Enum.take(candidates, limit)

  defp short_hash(peer_id), do: :crypto.hash(:sha256, peer_id) |> binary_part(0, 8)
end
