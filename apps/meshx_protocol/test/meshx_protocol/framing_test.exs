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
end
