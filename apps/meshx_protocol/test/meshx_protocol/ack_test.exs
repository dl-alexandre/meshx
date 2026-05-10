defmodule MeshxProtocol.AckTest do
  use ExUnit.Case

  alias MeshxProtocol.{Ack, Codec, Packet}

  test "ack packet encodes acknowledged message id" do
    packet = Ack.packet(1234, msg_id: 55)

    assert packet.type == :ack
    assert packet.msg_id == 55
    assert packet.ttl == 1
    assert {:ok, 1234} = Ack.decode(packet)
  end

  test "ack packet round-trips through codec" do
    packet = Ack.packet(9876)

    assert {:ok, frame} = Codec.encode_packet(packet)
    assert {:ok, decoded, <<>>} = Codec.decode_packet(frame)
    assert {:ok, 9876} = Ack.decode(decoded)
  end

  test "decode rejects malformed ack payload" do
    assert {:error, :malformed_ack} = Ack.decode(Packet.new(:ack, 1, <<1, 2>>))
  end

  test "decode rejects non-ack packets" do
    assert {:error, :not_ack} = Ack.decode(Packet.new(:data, 1, <<>>))
  end
end
