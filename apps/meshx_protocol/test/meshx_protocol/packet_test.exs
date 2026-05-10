defmodule MeshxProtocol.PacketTest do
  use ExUnit.Case

  alias MeshxProtocol.Packet

  test "type byte mappings include known and unknown values" do
    assert Packet.type_byte(:data) == 0x01
    assert Packet.type_byte(:ack) == 0x02
    assert Packet.type_byte(:gossip) == 0x03
    assert Packet.type_byte(:control) == 0x04
    assert Packet.type_byte(:fragment) == 0x05
    assert Packet.type_byte(:unknown) == :unknown

    assert Packet.byte_type(0x01) == :data
    assert Packet.byte_type(0x02) == :ack
    assert Packet.byte_type(0x03) == :gossip
    assert Packet.byte_type(0x04) == :control
    assert Packet.byte_type(0x05) == :fragment
    assert Packet.byte_type(0xFF) == :unknown
  end

  test "flag helpers set, clear, and inspect flags" do
    flags = 0
    encrypted = Packet.set_flag(flags, Packet.flag_encrypted())
    fragmented = Packet.set_flag(encrypted, Packet.flag_fragmented())
    ack_requested = Packet.set_flag(fragmented, Packet.flag_ack_requested())

    assert Packet.flag_set?(ack_requested, Packet.flag_encrypted())
    assert Packet.flag_set?(ack_requested, Packet.flag_fragmented())
    assert Packet.flag_set?(ack_requested, Packet.flag_ack_requested())

    cleared = Packet.clear_flag(ack_requested, Packet.flag_fragmented())
    refute Packet.flag_set?(cleared, Packet.flag_fragmented())
    assert Packet.flag_set?(cleared, Packet.flag_encrypted())
  end

  test "decrement_ttl never returns below zero" do
    assert Packet.decrement_ttl(%Packet{type: :data, msg_id: 1, payload: <<>>, ttl: 2}) == 1
    assert Packet.decrement_ttl(%Packet{type: :data, msg_id: 1, payload: <<>>, ttl: 0}) == 0
  end

  test "new/3 uses protocol defaults" do
    packet = Packet.new(:data, 42, "payload")

    assert packet.version == Packet.version()
    assert packet.type == :data
    assert packet.msg_id == 42
    assert packet.payload == "payload"
    assert packet.ttl == 64
    assert packet.flags == 0
  end
end
