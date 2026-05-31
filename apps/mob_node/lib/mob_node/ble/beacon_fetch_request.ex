defmodule Mob.Node.BLE.BeaconFetchRequest do
  @moduledoc """
  Auditable intent to fetch a full envelope for a legacy beacon reference.

  This is a pure request shape only. It does not send, retry, persist,
  route, open BLE connections, acknowledge, decrypt, or fragment
  anything.
  """

  @max_ttl_ms 60_000

  @enforce_keys [
    :request_id,
    :message_id_hash,
    :sender_peer_hash,
    :candidate_source_peer_ids,
    :observed_at,
    :expires_at,
    :reason
  ]
  defstruct @enforce_keys ++ [requesting_peer_id: nil]

  @type t :: %__MODULE__{
          request_id: binary(),
          message_id_hash: <<_::64>>,
          sender_peer_hash: <<_::64>>,
          requesting_peer_id: binary() | nil,
          candidate_source_peer_ids: [binary()],
          observed_at: integer(),
          expires_at: integer(),
          reason: :legacy_beacon_ref
        }

  @type error ::
          :not_needed
          | :unresolvable_beacon
          | :invalid_request_id
          | :invalid_message_id_hash
          | :invalid_sender_peer_hash
          | :invalid_requesting_peer_id
          | :invalid_candidate_source_peer_ids
          | :invalid_observed_at
          | :invalid_expires_at
          | :invalid_reason
          | :expired
          | :ttl_too_large

  @type opts :: [
          now: integer(),
          ttl_ms: pos_integer(),
          requesting_peer_id: binary() | nil,
          candidate_source_peer_ids: [binary()],
          id_fun: (map() -> binary())
        ]

  @spec max_ttl_ms() :: pos_integer()
  def max_ttl_ms, do: @max_ttl_ms

  @spec from_resolver_result(tuple(), opts()) :: {:ok, t()} | {:error, error()}
  def from_resolver_result({:already_known, _envelope}, _opts), do: {:error, :not_needed}
  def from_resolver_result({:unresolvable, _reason}, _opts), do: {:error, :unresolvable_beacon}

  def from_resolver_result({:needs_fetch, request}, opts) when is_map(request) do
    now = Keyword.fetch!(opts, :now)
    ttl_ms = Keyword.fetch!(opts, :ttl_ms)
    id_fun = Keyword.get(opts, :id_fun, &default_id/1)
    candidate_source_peer_ids = Keyword.get(opts, :candidate_source_peer_ids, [])

    fetch_request = %__MODULE__{
      request_id: id_fun.(request),
      message_id_hash: Map.get(request, :message_id_hash),
      sender_peer_hash: Map.get(request, :sender_peer_hash),
      requesting_peer_id: Keyword.get(opts, :requesting_peer_id),
      candidate_source_peer_ids: candidate_source_peer_ids,
      observed_at: Map.get(request, :observed_at),
      expires_at: now + ttl_ms,
      reason: :legacy_beacon_ref
    }

    with :ok <- validate_ttl(now, ttl_ms),
         :ok <- validate(fetch_request, now: now) do
      {:ok, fetch_request}
    end
  end

  def from_resolver_result(_other, _opts), do: {:error, :unresolvable_beacon}

  @spec validate(t(), keyword()) :: :ok | {:error, error()}
  def validate(%__MODULE__{} = request, opts \\ []) do
    now = Keyword.get(opts, :now)

    cond do
      not is_binary(request.request_id) or request.request_id == "" ->
        {:error, :invalid_request_id}

      not valid_hash?(request.message_id_hash) ->
        {:error, :invalid_message_id_hash}

      not valid_hash?(request.sender_peer_hash) ->
        {:error, :invalid_sender_peer_hash}

      not (is_nil(request.requesting_peer_id) or
               (is_binary(request.requesting_peer_id) and request.requesting_peer_id != "")) ->
        {:error, :invalid_requesting_peer_id}

      not valid_candidate_ids?(request.candidate_source_peer_ids) ->
        {:error, :invalid_candidate_source_peer_ids}

      not is_integer(request.observed_at) ->
        {:error, :invalid_observed_at}

      not is_integer(request.expires_at) ->
        {:error, :invalid_expires_at}

      request.reason != :legacy_beacon_ref ->
        {:error, :invalid_reason}

      is_integer(now) and request.expires_at <= now ->
        {:error, :expired}

      true ->
        :ok
    end
  end

  defp validate_ttl(_now, ttl_ms) when not is_integer(ttl_ms) or ttl_ms <= 0,
    do: {:error, :invalid_expires_at}

  defp validate_ttl(_now, ttl_ms) when ttl_ms > @max_ttl_ms, do: {:error, :ttl_too_large}
  defp validate_ttl(now, _ttl_ms) when not is_integer(now), do: {:error, :invalid_expires_at}
  defp validate_ttl(_now, _ttl_ms), do: :ok

  defp valid_hash?(bytes), do: is_binary(bytes) and byte_size(bytes) == 8

  defp valid_candidate_ids?(ids) when is_list(ids) do
    Enum.all?(ids, &(is_binary(&1) and &1 != ""))
  end

  defp valid_candidate_ids?(_ids), do: false

  defp default_id(request) do
    [
      request.message_id_hash,
      request.sender_peer_hash,
      Integer.to_string(request.observed_at || 0)
    ]
    |> Enum.join(":")
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end
end
