defmodule MeshxMobileApp.BLE.BeaconFetchProtocol do
  @moduledoc """
  Canonical in-memory fetch request/response messages for legacy beacon fetches.

  These structs define the contract only. They do not imply a transport,
  retry policy, routing, persistence, crypto, ACK, or fragmentation.
  """

  alias MeshxMobileApp.BLE.{BeaconFetchRequest, MessageEnvelope}

  defmodule Request do
    @moduledoc false
    @enforce_keys [:request_id, :message_id_hash]
    defstruct @enforce_keys ++ [requester_peer_id: nil, candidate_source_peer_ids: []]

    @type t :: %__MODULE__{
            request_id: binary(),
            message_id_hash: <<_::64>>,
            requester_peer_id: binary() | nil,
            candidate_source_peer_ids: [binary()]
          }
  end

  defmodule Response do
    @moduledoc false
    @enforce_keys [:request_id, :message_id_hash, :responder_peer_id, :status]
    defstruct @enforce_keys ++ [envelope: nil, reason: nil]

    @type status :: :ok | :not_found | :invalid_request | :unavailable

    @type t :: %__MODULE__{
            request_id: binary(),
            message_id_hash: <<_::64>>,
            responder_peer_id: binary(),
            status: status(),
            envelope: MessageEnvelope.t() | nil,
            reason: atom() | nil
          }
  end

  @statuses [:ok, :not_found, :invalid_request, :unavailable]

  @spec request_from_fetch_request(BeaconFetchRequest.t()) ::
          {:ok, Request.t()} | {:error, term()}
  def request_from_fetch_request(%BeaconFetchRequest{} = fetch_request) do
    request = %Request{
      request_id: fetch_request.request_id,
      message_id_hash: fetch_request.message_id_hash,
      requester_peer_id: fetch_request.requesting_peer_id,
      candidate_source_peer_ids: fetch_request.candidate_source_peer_ids
    }

    with :ok <- validate_request(request), do: {:ok, request}
  end

  @spec response(keyword()) :: {:ok, Response.t()} | {:error, term()}
  def response(opts) do
    response = %Response{
      request_id: Keyword.get(opts, :request_id),
      message_id_hash: Keyword.get(opts, :message_id_hash),
      responder_peer_id: Keyword.get(opts, :responder_peer_id),
      status: Keyword.get(opts, :status),
      envelope: Keyword.get(opts, :envelope),
      reason: Keyword.get(opts, :reason)
    }

    with :ok <- validate_response(response), do: {:ok, response}
  end

  @spec encode_request(Request.t()) :: map()
  def encode_request(%Request{} = request) do
    %{
      v: 1,
      type: "beacon_fetch_request",
      request_id: request.request_id,
      message_id_hash: request.message_id_hash,
      requester_peer_id: request.requester_peer_id,
      candidate_source_peer_ids: request.candidate_source_peer_ids
    }
  end

  @spec decode_request(map()) :: {:ok, Request.t()} | {:error, term()}
  def decode_request(%{v: 1, type: "beacon_fetch_request"} = map) do
    request = %Request{
      request_id: map[:request_id],
      message_id_hash: map[:message_id_hash],
      requester_peer_id: map[:requester_peer_id],
      candidate_source_peer_ids: map[:candidate_source_peer_ids] || []
    }

    with :ok <- validate_request(request), do: {:ok, request}
  end

  def decode_request(%{"v" => 1, "type" => "beacon_fetch_request"} = map) do
    decode_request(%{
      v: 1,
      type: "beacon_fetch_request",
      request_id: map["request_id"],
      message_id_hash: map["message_id_hash"],
      requester_peer_id: map["requester_peer_id"],
      candidate_source_peer_ids: map["candidate_source_peer_ids"] || []
    })
  end

  def decode_request(_), do: {:error, :invalid_fetch_request}

  @spec encode_response(Response.t()) :: map()
  def encode_response(%Response{} = response) do
    %{
      v: 1,
      type: "beacon_fetch_response",
      request_id: response.request_id,
      message_id_hash: response.message_id_hash,
      responder_peer_id: response.responder_peer_id,
      status: Atom.to_string(response.status),
      envelope: if(response.envelope, do: MessageEnvelope.encode(response.envelope)),
      reason: if(response.reason, do: Atom.to_string(response.reason))
    }
  end

  @spec decode_response(map()) :: {:ok, Response.t()} | {:error, term()}
  def decode_response(%{v: 1, type: "beacon_fetch_response"} = map) do
    with {:ok, status} <- decode_status(map[:status]),
         {:ok, envelope} <- decode_optional_envelope(map[:envelope]),
         {:ok, reason} <- decode_optional_atom(map[:reason]) do
      response = %Response{
        request_id: map[:request_id],
        message_id_hash: map[:message_id_hash],
        responder_peer_id: map[:responder_peer_id],
        status: status,
        envelope: envelope,
        reason: reason
      }

      with :ok <- validate_response(response), do: {:ok, response}
    end
  end

  def decode_response(%{"v" => 1, "type" => "beacon_fetch_response"} = map) do
    decode_response(%{
      v: 1,
      type: "beacon_fetch_response",
      request_id: map["request_id"],
      message_id_hash: map["message_id_hash"],
      responder_peer_id: map["responder_peer_id"],
      status: map["status"],
      envelope: map["envelope"],
      reason: map["reason"]
    })
  end

  def decode_response(_), do: {:error, :invalid_fetch_response}

  defp validate_request(%Request{} = request) do
    cond do
      not present_binary?(request.request_id) ->
        {:error, :invalid_request_id}

      not hash?(request.message_id_hash) ->
        {:error, :invalid_message_id_hash}

      not optional_binary?(request.requester_peer_id) ->
        {:error, :invalid_requester_peer_id}

      not peer_id_list?(request.candidate_source_peer_ids) ->
        {:error, :invalid_candidate_source_peer_ids}

      true ->
        :ok
    end
  end

  defp validate_response(%Response{} = response) do
    cond do
      not present_binary?(response.request_id) ->
        {:error, :invalid_request_id}

      not hash?(response.message_id_hash) ->
        {:error, :invalid_message_id_hash}

      not present_binary?(response.responder_peer_id) ->
        {:error, :invalid_responder_peer_id}

      response.status not in @statuses ->
        {:error, :invalid_status}

      response.status == :ok and not match?(%MessageEnvelope{}, response.envelope) ->
        {:error, :missing_envelope}

      response.status != :ok and not is_nil(response.envelope) ->
        {:error, :unexpected_envelope}

      not optional_atom?(response.reason) ->
        {:error, :invalid_reason}

      true ->
        :ok
    end
  end

  defp decode_status(status) when is_atom(status) and status in @statuses, do: {:ok, status}

  defp decode_status(status) when is_binary(status) do
    case Enum.find(@statuses, &("#{&1}" == status)) do
      nil -> {:error, :invalid_status}
      status -> {:ok, status}
    end
  end

  defp decode_status(_), do: {:error, :invalid_status}

  defp decode_optional_envelope(nil), do: {:ok, nil}
  defp decode_optional_envelope(%MessageEnvelope{} = envelope), do: {:ok, envelope}
  defp decode_optional_envelope(bytes) when is_binary(bytes), do: MessageEnvelope.parse(bytes)
  defp decode_optional_envelope(_), do: {:error, :invalid_envelope}

  defp decode_optional_atom(nil), do: {:ok, nil}
  defp decode_optional_atom(reason) when is_atom(reason), do: {:ok, reason}

  defp decode_optional_atom(reason) when is_binary(reason) do
    if reason in ["not_found", "expired", "invalid_request", "unavailable"] do
      {:ok, String.to_existing_atom(reason)}
    else
      {:error, :invalid_reason}
    end
  end

  defp present_binary?(value), do: is_binary(value) and value != ""
  defp optional_binary?(nil), do: true
  defp optional_binary?(value), do: present_binary?(value)
  defp hash?(value), do: is_binary(value) and byte_size(value) == 8
  defp optional_atom?(nil), do: true
  defp optional_atom?(value), do: is_atom(value)
  defp peer_id_list?(ids) when is_list(ids), do: Enum.all?(ids, &present_binary?/1)
  defp peer_id_list?(_), do: false
end
