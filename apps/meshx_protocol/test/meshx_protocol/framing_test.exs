defmodule MeshxProtocol.FramingTest do
  use ExUnit.Case
  alias MeshxProtocol.{Framing, Packet}

  test "round-trip encode and decode" do
    packet = Packet.new(:data, 42, "hello mesh")
    assert {:ok, frame} = Framing.encode(packet)
    assert {:ok, decoded, rest} = Framing.decode(frame)
    assert decoded.type == :data
    assert decoded.msg_id == 42
    assert decoded.payload == "hello mesh"
    assert decoded.ttl == 64
    assert decoded.version == 1
    assert rest == <<>>
  end

  test "decode returns leftover bytes" do
    packet = Packet.new(:gossip, 7, <<1, 2, 3>>)
    {:ok, frame} = Framing.encode(packet)
    extra = <<9, 9, 9>>
    assert {:ok, decoded, rest} = Framing.decode(frame <> extra)
    assert decoded.type == :gossip
    assert rest == extra
  end

  test "decode detects checksum mismatch" do
    packet = Packet.new(:data, 1, "x")
    {:ok, frame} = Framing.encode(packet)
    # Corrupt the last byte (part of checksum or payload)
    corrupted = binary_slice(frame, 0, byte_size(frame) - 1) <> <<255>>
    assert {:error, "checksum mismatch"} = Framing.decode(corrupted)
  end

  test "decode requires minimum bytes" do
    assert {:error, "insufficient data for header + checksum"} = Framing.decode(<<1, 2>>)
  end

  test "encode rejects unknown type" do
    packet = %Packet{type: :unknown_type, msg_id: 1, payload: <<>>}
    assert {:error, _} = Framing.encode(packet)
  end

  test "encode rejects oversized payload" do
    huge = :binary.copy("x", 66_000)
    packet = Packet.new(:data, 1, huge)
    assert {:error, "payload exceeds maximum 65,535 bytes"} = Framing.encode(packet)
  end

  test "scan finds valid frame in noise" do
    packet = Packet.new(:ack, 99, <<>>)
    {:ok, frame} = Framing.encode(packet)
    noise = <<0, 0, 0>> <> frame <> <<1, 1>>
    assert {:ok, decoded, rest} = Framing.scan(noise)
    assert decoded.type == :ack
    assert decoded.msg_id == 99
    assert rest == <<1, 1>>
  end

  describe "channel segment" do
    test "channel-less frame is byte-identical to the legacy format and decodes channel_id \"\"" do
      packet = Packet.new(:data, 42, "hello")
      {:ok, frame} = Framing.encode(packet)

      plen = byte_size("hello")
      header = <<1::8, 1::8, 0::8, 64::8, plen::16-little, 42::32-little>>
      crc = Bitwise.band(:erlang.crc32(header <> "hello"), 0xFFFF)

      assert frame == header <> "hello" <> <<crc::16-little>>
      assert {:ok, decoded, <<>>} = Framing.decode(frame)
      assert decoded.channel_id == ""
      refute Packet.flag_set?(decoded.flags, Packet.flag_channel())
    end

    test "round-trips a channel id and sets the channel flag" do
      packet = %Packet{type: :data, msg_id: 7, payload: "hi", channel_id: "bluetooth"}
      assert {:ok, frame} = Framing.encode(packet)
      assert {:ok, decoded, <<>>} = Framing.decode(frame)
      assert decoded.channel_id == "bluetooth"
      assert decoded.payload == "hi"
      assert Packet.flag_set?(decoded.flags, Packet.flag_channel())
    end

    test "channel segment is covered by the checksum" do
      packet = %Packet{type: :data, msg_id: 1, payload: "x", channel_id: "c"}
      {:ok, frame} = Framing.encode(packet)
      # header is 10 bytes, then chan_len byte; flip the channel-id byte at offset 11
      <<head::binary-size(11), _c::8, tail::binary>> = frame
      assert {:error, "checksum mismatch"} = Framing.decode(head <> <<?z>> <> tail)
    end

    test "rejects a channel id longer than 255 bytes" do
      packet = %Packet{
        type: :data,
        msg_id: 1,
        payload: "",
        channel_id: String.duplicate("x", 256)
      }

      assert {:error, _} = Framing.encode(packet)
    end

    test "errors when the channel flag is set but the segment is truncated" do
      truncated = <<1::8, 1::8, Packet.flag_channel()::8, 64::8, 0::16-little, 9::32-little>>
      assert {:error, _} = Framing.decode(truncated <> <<0::16>>)
    end
  end
end
