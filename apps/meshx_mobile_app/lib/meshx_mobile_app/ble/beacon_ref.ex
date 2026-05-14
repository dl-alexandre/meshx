defmodule MeshxMobileApp.BLE.BeaconRef do
  @moduledoc """
  Pure reference extracted from a legacy BLE message beacon.

  A beacon is a pointer to a message envelope, not delivery of that
  envelope. It carries enough stable bytes to ask another layer for the
  full `MessageEnvelope` later, while keeping the legacy advertisement
  payload small enough for older radios.
  """

  alias MeshxMobileApp.BLE.Events.ReceivedMessageBeacon
  alias MeshxMobileApp.BLE.MessageEnvelope

  @hash_size 8

  @enforce_keys [
    :envelope_version,
    :payload_kind,
    :message_id_hash,
    :sender_peer_hash,
    :observed_at,
    :received_device_id,
    :rssi
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          envelope_version: pos_integer(),
          payload_kind: binary(),
          message_id_hash: <<_::64>>,
          sender_peer_hash: <<_::64>>,
          observed_at: integer(),
          received_device_id: binary(),
          rssi: integer()
        }

  @type error ::
          :invalid_envelope_version
          | :invalid_payload_kind
          | :invalid_message_id_hash
          | :invalid_sender_peer_hash
          | :invalid_observed_at
          | :invalid_received_device_id
          | :invalid_rssi

  @spec from_event(ReceivedMessageBeacon.t()) :: {:ok, t()} | {:error, error()}
  def from_event(%ReceivedMessageBeacon{} = event) do
    new(
      envelope_version: event.envelope_version,
      payload_kind: event.payload_kind,
      message_id_hash: event.message_id_hash,
      sender_peer_hash: event.sender_peer_id_hash,
      observed_at: event.received_at,
      received_device_id: event.received_device_id,
      rssi: event.rssi
    )
  end

  @spec new(keyword()) :: {:ok, t()} | {:error, error()}
  def new(opts) when is_list(opts) do
    ref = %__MODULE__{
      envelope_version: Keyword.get(opts, :envelope_version),
      payload_kind: Keyword.get(opts, :payload_kind),
      message_id_hash: Keyword.get(opts, :message_id_hash),
      sender_peer_hash: Keyword.get(opts, :sender_peer_hash),
      observed_at: Keyword.get(opts, :observed_at),
      received_device_id: Keyword.get(opts, :received_device_id),
      rssi: Keyword.get(opts, :rssi)
    }

    case validate(ref) do
      :ok -> {:ok, ref}
      {:error, _} = error -> error
    end
  end

  @spec validate(t()) :: :ok | {:error, error()}
  def validate(%__MODULE__{} = ref) do
    cond do
      not is_integer(ref.envelope_version) or ref.envelope_version < 1 ->
        {:error, :invalid_envelope_version}

      not is_binary(ref.payload_kind) or ref.payload_kind == "" ->
        {:error, :invalid_payload_kind}

      not valid_hash?(ref.message_id_hash) ->
        {:error, :invalid_message_id_hash}

      not valid_hash?(ref.sender_peer_hash) ->
        {:error, :invalid_sender_peer_hash}

      not is_integer(ref.observed_at) ->
        {:error, :invalid_observed_at}

      not is_binary(ref.received_device_id) or ref.received_device_id == "" ->
        {:error, :invalid_received_device_id}

      not is_integer(ref.rssi) ->
        {:error, :invalid_rssi}

      true ->
        :ok
    end
  end

  @spec message_id_hash(MessageEnvelope.t()) :: <<_::64>>
  def message_id_hash(%MessageEnvelope{} = envelope), do: short_hash(envelope.message_id)

  @spec sender_peer_hash(MessageEnvelope.t()) :: <<_::64>>
  def sender_peer_hash(%MessageEnvelope{} = envelope), do: short_hash(envelope.sender_peer_id)

  @spec matches_envelope?(t(), MessageEnvelope.t()) :: boolean()
  def matches_envelope?(%__MODULE__{} = ref, %MessageEnvelope{} = envelope) do
    ref.envelope_version == envelope.envelope_version and
      ref.payload_kind == envelope.payload_type and
      ref.message_id_hash == message_id_hash(envelope) and
      ref.sender_peer_hash == sender_peer_hash(envelope)
  end

  defp valid_hash?(bytes), do: is_binary(bytes) and byte_size(bytes) == @hash_size

  defp short_hash(bytes), do: :crypto.hash(:sha256, bytes) |> binary_part(0, @hash_size)
end
