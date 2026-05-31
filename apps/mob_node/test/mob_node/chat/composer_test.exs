defmodule Mob.Node.Chat.ComposerTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.MessageEnvelope
  alias Mob.Node.Chat.Composer
  alias Mob.Protocol.Packet

  @identity %{peer_id: "alice-peer", nickname: "Alice"}
  @now 1_700_000_000_000

  describe "build_packet/3" do
    test "produces a :data packet whose payload is a parseable CHAT envelope" do
      {:ok, packet, message_id} =
        Composer.build_packet("#general", "hello world", identity: @identity, now_ms: @now)

      assert %Packet{
               version: 1,
               type: :data,
               channel_id: "#general",
               ttl: 8,
               payload: bytes
             } = packet

      assert is_binary(message_id) and byte_size(message_id) == 16
      assert Packet.flag_set?(packet.flags, Packet.flag_channel())
      assert Packet.flag_set?(packet.flags, Packet.flag_ack_requested())

      assert {:ok, envelope} = MessageEnvelope.parse(bytes)
      assert envelope.payload_type == Composer.payload_type()
      assert envelope.payload == "hello world"
      assert envelope.sender_peer_id == @identity.peer_id
      assert envelope.recipient_peer_id == nil
      assert envelope.created_at == @now
      assert envelope.message_id == message_id
    end

    test "packet.msg_id is the little-endian first 4 bytes of envelope.message_id" do
      {:ok, packet, message_id} =
        Composer.build_packet("#general", "hi", identity: @identity, now_ms: @now)

      <<expected::32-little, _rest::binary>> = message_id
      assert packet.msg_id == expected
    end

    test "honors custom ttl + recipient_peer_id (DM shape)" do
      {:ok, packet, _id} =
        Composer.build_packet("#general", "psst",
          identity: @identity,
          now_ms: @now,
          ttl: 3,
          recipient_peer_id: "bob-peer"
        )

      assert packet.ttl == 3
      {:ok, envelope} = MessageEnvelope.parse(packet.payload)
      assert envelope.ttl == 3
      assert envelope.recipient_peer_id == "bob-peer"
    end

    test "rejects empty / non-binary channel" do
      assert {:error, :invalid_channel} =
               Composer.build_packet("", "hi", identity: @identity, now_ms: @now)

      assert {:error, :invalid_channel} =
               Composer.build_packet(nil, "hi", identity: @identity, now_ms: @now)
    end

    test "rejects empty / non-binary text" do
      assert {:error, :empty_text} =
               Composer.build_packet("#general", "", identity: @identity, now_ms: @now)

      assert {:error, :empty_text} =
               Composer.build_packet("#general", nil, identity: @identity, now_ms: @now)
    end

    test "two calls with the same text produce distinct message_ids (random id by default)" do
      {:ok, _p1, id1} =
        Composer.build_packet("#general", "same text", identity: @identity, now_ms: @now)

      {:ok, _p2, id2} =
        Composer.build_packet("#general", "same text", identity: @identity, now_ms: @now)

      assert id1 != id2
    end

    test "round-trips through the codec (encoded packet decodes back to the same envelope payload)" do
      {:ok, packet, _id} =
        Composer.build_packet("#general", "round trip", identity: @identity, now_ms: @now)

      {:ok, frame} = Mob.Protocol.Codec.encode_packet(packet)
      assert {:ok, decoded, <<>>} = Mob.Protocol.Codec.decode_packet(frame)
      assert decoded.channel_id == "#general"
      assert decoded.type == :data
      assert decoded.payload == packet.payload

      {:ok, envelope} = MessageEnvelope.parse(decoded.payload)
      assert envelope.payload == "round trip"
    end
  end
end
