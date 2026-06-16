defmodule Mob.Node.Chat.ComposerEncryptionTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.MessageEnvelope
  alias Mob.Node.Chat.{Composer, GroupPayload}

  @identity %{peer_id: "alice-peer", nickname: "Alice"}
  @now 1_700_000_000_000

  defp build(channel, text, encryptor) do
    Composer.build_packet(channel, text,
      identity: @identity,
      now_ms: @now,
      encryptor: encryptor
    )
  end

  test "cleartext encryptor produces a CHAT envelope with raw text" do
    {:ok, packet, _id} = build("#general", "hello", fn _ch, _t -> :cleartext end)
    {:ok, envelope} = MessageEnvelope.parse(packet.payload)

    assert envelope.payload_type == Composer.payload_type()
    assert envelope.payload == "hello"
  end

  test "encrypting encryptor produces a CHATG envelope wrapping the sealed blob" do
    blob = :crypto.strong_rand_bytes(32)

    {:ok, packet, _id} =
      build("#general", "secret", fn "#general", "secret" -> {:ok, 3, blob} end)

    {:ok, envelope} = MessageEnvelope.parse(packet.payload)

    assert envelope.payload_type == Composer.encrypted_payload_type()
    assert {:ok, 3, ^blob} = GroupPayload.decode(envelope.payload)
    refute envelope.payload == "secret"
  end

  test "an encryptor error aborts the build" do
    assert {:error, :no_session} = build("#general", "x", fn _ch, _t -> {:error, :no_session} end)
  end

  test "channel_id and sender stay cleartext on an encrypted message (routing intact)" do
    {:ok, packet, _id} = build("#ops", "secret", fn _ch, _t -> {:ok, 0, "blob"} end)
    {:ok, envelope} = MessageEnvelope.parse(packet.payload)

    assert packet.channel_id == "#ops"
    assert envelope.sender_peer_id == @identity.peer_id
  end
end
