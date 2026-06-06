defmodule Mob.Node.Chat.RouterIngress do
  @moduledoc """
  Bridges passive BLE `ReceivedMessage` events into the runtime router.

  Chat send uses `Router.broadcast_packet/2` (mesh transport). Inbound
  gossip on iOS often arrives as advertisement envelopes on the session
  bridge before (or without) a connected peer frame. This module wraps
  those envelopes as router packets so `ChannelViewModel` subscribers
  receive them on the same `{:mob_runtime, :packet, ...}` path as TCP.
  """

  alias Mob.Node.BLE.Events.ReceivedMessage
  alias Mob.Node.BLE.MessageEnvelope
  alias Mob.Node.Chat.Composer
  alias Mob.Protocol.{Codec, Packet}

  @default_channel "#general"

  @spec forward_received_message(ReceivedMessage.t()) :: :ok | :skip | {:error, term()}
  def forward_received_message(%ReceivedMessage{envelope: envelope} = event) do
    if envelope.payload_type == Composer.payload_type() do
      packet = packet_from_envelope(event, envelope)

      with {:ok, frame} <- Codec.encode_packet(packet) do
        send(
          Mob.Runtime.Router,
          {:mob_routing, :ble, {:frame, event.sender_peer_id, frame}}
        )

        :ok
      end
    else
      :skip
    end
  end

  defp packet_from_envelope(event, envelope) do
    %Packet{
      version: Packet.version(),
      type: :data,
      flags: Packet.set_flag(0, Packet.flag_channel()),
      ttl: envelope.ttl,
      msg_id: msg_id_from_envelope(envelope.message_id),
      channel_id: channel_from_metadata(event) || @default_channel,
      payload: MessageEnvelope.encode(envelope)
    }
  end

  defp msg_id_from_envelope(<<id::32-little, _rest::binary>>), do: id

  defp channel_from_metadata(%ReceivedMessage{raw_transport_metadata: meta})
       when is_map(meta) do
    Map.get(meta, :channel_id) || Map.get(meta, "channel_id")
  end

  defp channel_from_metadata(_), do: nil
end