defmodule MeshxMobileApp.BLE.MessageAdvertisement do
  @moduledoc """
  Parser for MeshX message envelopes carried in BLE advertisements.

  Android scan records arrive as raw advertising bytes in the existing
  `DeviceDiscovered` / `AdvertisementReceived` events. This module
  recognizes manufacturer-specific AD structures whose payload is the
  existing M14 `MessageEnvelope` byte shape and turns them into the
  canonical `ReceivedMessage` event.

  It does not parse any other payload shape. If a payload is tagged as
  a MeshX envelope but the M14 parser rejects it, callers receive a
  tagged error tuple instead of an exception.
  """

  alias MeshxMobileApp.BLE.Events.{
    AdvertisementReceived,
    DeviceDiscovered,
    ReceivedMessage,
    ReceivedMessageBeacon
  }

  alias MeshxMobileApp.BLE.MessageEnvelope

  @manufacturer_specific_data 0xFF
  @meshx_company_identifier 0xFFFF
  @message_magic "MX"
  @beacon_magic "MB"

  @type decode_error ::
          {:message_advertisement_decode_error,
           MessageEnvelope.error() | :truncated_ad_structure | :truncated_legacy_beacon}

  @doc """
  Decodes a canonical advertisement-class event into `ReceivedMessage`
  when it carries an M14 envelope.

  Returns `:not_message_advertisement` for ordinary BLE advertisements.
  """
  @spec decode(DeviceDiscovered.t() | AdvertisementReceived.t()) ::
          {:ok, ReceivedMessage.t() | ReceivedMessageBeacon.t()}
          | :not_message_advertisement
          | {:error, decode_error()}
  def decode(%DeviceDiscovered{} = event), do: decode_event(event)
  def decode(%AdvertisementReceived{} = event), do: decode_event(event)

  @doc """
  Extracts the raw M14 envelope payload from a BLE scan record.
  """
  @spec extract_payload(binary()) ::
          {:ok, binary(), map()} | :not_message_advertisement | {:error, decode_error()}
  def extract_payload(advertisement) when is_binary(advertisement) do
    case manufacturer_payloads(advertisement) do
      {:ok, entries} ->
        find_message_payload(entries)

      {:error, :truncated_ad_structure} ->
        {:error, {:message_advertisement_decode_error, :truncated_ad_structure}}
    end
  end

  defp decode_event(event) do
    with {:ok, payload, metadata} <- extract_payload(event.advertisement) do
      decode_payload(payload, metadata, event)
    else
      :not_message_advertisement ->
        :not_message_advertisement

      {:error, {:message_advertisement_decode_error, _} = reason} ->
        {:error, reason}

      {:error, reason} ->
        {:error, {:message_advertisement_decode_error, reason}}
    end
  end

  defp decode_payload(<<@message_magic, _rest::binary>> = payload, metadata, event) do
    with {:ok, envelope} <- MessageEnvelope.parse(payload) do
      {:ok,
       %ReceivedMessage{
         message_id: envelope.message_id,
         sender_peer_id: envelope.sender_peer_id,
         recipient_peer_id: envelope.recipient_peer_id,
         received_device_id: event.device_id,
         received_at: event.observed_at_ms,
         rssi: event.rssi,
         envelope: envelope,
         raw_transport_metadata:
           Map.merge(metadata, %{
             source_event: source_event(event),
             received_device_id: event.device_id,
             advertisement: event.advertisement,
             message_payload: payload
           })
       }}
    else
      {:error, reason} ->
        {:error, {:message_advertisement_decode_error, reason}}
    end
  end

  defp decode_payload(
         <<@beacon_magic, beacon_version, envelope_version, payload_kind_code, _flags,
           message_id_hash::binary-size(8), sender_peer_id_hash::binary-size(8)>> = payload,
         metadata,
         event
       ) do
    {:ok,
     %ReceivedMessageBeacon{
       beacon_version: beacon_version,
       envelope_version: envelope_version,
       payload_kind: payload_kind(payload_kind_code),
       message_id_hash: message_id_hash,
       sender_peer_id_hash: sender_peer_id_hash,
       received_device_id: event.device_id,
       received_at: event.observed_at_ms,
       rssi: event.rssi,
       raw_transport_metadata:
         Map.merge(metadata, %{
           source_event: source_event(event),
           received_device_id: event.device_id,
           advertisement: event.advertisement,
           beacon_payload: payload
         })
     }}
  end

  defp decode_payload(<<@beacon_magic, _rest::binary>>, _metadata, _event),
    do: {:error, {:message_advertisement_decode_error, :truncated_legacy_beacon}}

  defp manufacturer_payloads(bytes), do: manufacturer_payloads(bytes, [])

  defp manufacturer_payloads(<<>>, acc), do: {:ok, Enum.reverse(acc)}
  defp manufacturer_payloads(<<0, _rest::binary>>, acc), do: {:ok, Enum.reverse(acc)}

  defp manufacturer_payloads(<<len, rest::binary>>, acc) when byte_size(rest) >= len do
    <<type, data::binary-size(len - 1), tail::binary>> = rest

    acc =
      case {type, data} do
        {@manufacturer_specific_data, <<company_id::16-little-unsigned, payload::binary>>} ->
          [
            %{
              company_identifier: company_id,
              ad_type: type,
              manufacturer_data: data,
              payload: payload
            }
            | acc
          ]

        _ ->
          acc
      end

    manufacturer_payloads(tail, acc)
  end

  defp manufacturer_payloads(<<_len, rest::binary>>, acc) do
    cond do
      has_message_payload?(acc) ->
        {:ok, Enum.reverse(acc)}

      truncated_meshx_ad_structure?(rest) ->
        {:error, :truncated_ad_structure}

      true ->
        {:ok, Enum.reverse(acc)}
    end
  end

  defp has_message_payload?(entries) do
    Enum.any?(entries, fn
      %{company_identifier: @meshx_company_identifier, payload: <<@message_magic, _rest::binary>>} ->
        true

      %{company_identifier: @meshx_company_identifier, payload: <<@beacon_magic, _rest::binary>>} ->
        true

      _entry ->
        false
    end)
  end

  defp truncated_meshx_ad_structure?(
         <<@manufacturer_specific_data, @meshx_company_identifier::16-little-unsigned,
           payload::binary>>
       ) do
    match?(<<@message_magic, _rest::binary>>, payload) or
      match?(<<@beacon_magic, _rest::binary>>, payload)
  end

  defp truncated_meshx_ad_structure?(_rest), do: false

  defp find_message_payload([]), do: :not_message_advertisement

  defp find_message_payload([
         %{
           company_identifier: @meshx_company_identifier,
           payload: <<magic::binary-size(2), _payload_rest::binary>>
         } = entry
         | _entries_rest
       ])
       when magic in [@message_magic, @beacon_magic] do
    {:ok, entry.payload,
     %{
       transport: :ble_advertisement,
       company_identifier: entry.company_identifier,
       ad_type: entry.ad_type,
       manufacturer_data: entry.manufacturer_data
     }}
  end

  defp find_message_payload([_entry | rest]), do: find_message_payload(rest)

  defp source_event(%DeviceDiscovered{}), do: :device_discovered
  defp source_event(%AdvertisementReceived{}), do: :advertisement_received

  defp payload_kind(1), do: "TX"
  defp payload_kind(_), do: "unknown"
end
