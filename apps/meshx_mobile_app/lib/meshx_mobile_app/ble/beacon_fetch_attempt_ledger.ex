defmodule MeshxMobileApp.BLE.BeaconFetchAttemptLedger do
  @moduledoc """
  Immutable fetch-attempt intents for legacy beacon fetch planning.

  Attempts are only records. They do not fetch, connect, retry, persist,
  acknowledge, route, encrypt, or fragment.
  """

  alias MeshxMobileApp.BLE.BeaconFetchPlanner.Candidate
  alias MeshxMobileApp.BLE.BeaconFetchRequest

  defmodule FetchAttempt do
    @moduledoc false

    @enforce_keys [
      :fetch_attempt_id,
      :request_id,
      :message_id_hash,
      :target_peer_id,
      :target_device_ids,
      :planned_at
    ]
    defstruct @enforce_keys ++ [status: :planned]

    @type t :: %__MODULE__{
            fetch_attempt_id: binary(),
            request_id: binary(),
            message_id_hash: binary(),
            target_peer_id: binary(),
            target_device_ids: [binary()],
            planned_at: integer(),
            status: :planned
          }
  end

  @type opts :: [
          planned_at: integer(),
          id_fun: (non_neg_integer() -> binary())
        ]

  @spec record(BeaconFetchRequest.t(), [Candidate.t()], opts()) :: [FetchAttempt.t()]
  def record(%BeaconFetchRequest{} = request, candidates, opts) when is_list(candidates) do
    planned_at = Keyword.fetch!(opts, :planned_at)
    id_fun = Keyword.get(opts, :id_fun, &default_id/1)

    candidates
    |> Enum.with_index()
    |> Enum.map(fn {%Candidate{} = candidate, index} ->
      %FetchAttempt{
        fetch_attempt_id: id_fun.(index),
        request_id: request.request_id,
        message_id_hash: request.message_id_hash,
        target_peer_id: candidate.peer_id,
        target_device_ids: candidate.device_ids,
        planned_at: planned_at
      }
    end)
  end

  defp default_id(index), do: "fetch-attempt-#{index}"
end
