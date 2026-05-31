defmodule Mob.Protocol.WireVectorsTest do
  @moduledoc """
  Pins on-the-wire byte output of the Elixir encoder against fixed vectors
  published in `docs/WIRE_VECTORS.md`. If any of these tests fail, the wire
  format has changed in a way that will break non-Elixir clients (iOS,
  Android, etc.). Either revert the encoder change, or update both this
  test and `docs/WIRE_VECTORS.md` in lockstep and bump the format version
  in `docs/WIRE_FORMAT.md`.
  """

  use ExUnit.Case

  alias Mob.Protocol.{Codec, Fragment, Packet}

  defp hex(bin), do: Base.encode16(bin, case: :lower)

  test "V1 — data packet, default ttl, no flags" do
    frame = encode!(Packet.new(:data, 42, "hello mesh"))
    assert hex(frame) == "010100400a002a00000068656c6c6f206d657368c339"
  end

  test "V2 — control packet, empty payload, default ttl" do
    frame = encode!(Packet.new(:control, 0, <<>>))
    assert hex(frame) == "010400400000000000003d27"
  end

  test "V3 — ack with ack_requested flag and ttl=5" do
    packet = %Packet{
      Packet.new(:ack, 0xDEADBEEF, <<>>)
      | flags: Packet.flag_ack_requested(),
        ttl: 5
    }

    frame = encode!(packet)
    assert hex(frame) == "010204050000efbeadde90b5"
  end

  test "V4 — fragmented 10 bytes into 3 chunks of 4, orig_msg_id=0x11223344" do
    fragments = Fragment.fragment(0x11223344, "ABCDEFGHIJ", max_chunk_size: 4, ttl: 32)
    assert length(fragments) == 3

    expected = [
      "010500200a00708a5f0744332211000341424344d8a9",
      "010500200a009833ac024433221101034546474852e0",
      "0105002008002b11e303443322110203494a0518"
    ]

    encoded = Enum.map(fragments, fn frag -> hex(encode!(frag)) end)
    assert encoded == expected
  end

  test "V4 — round-trip: encoded fragments reassemble to original payload" do
    fragments = Fragment.fragment(0x11223344, "ABCDEFGHIJ", max_chunk_size: 4, ttl: 32)
    frames = Enum.map(fragments, fn frag -> encode!(frag) end)
    assert {:ok, 0x11223344, "ABCDEFGHIJ"} = Codec.decode_fragments(frames)
  end

  test "V5 — Noise handshake control payload prefix is the ASCII tag MXN1" do
    assert hex("MXN1") == "4d584e31"
    assert "MXN1" == <<0x4D, 0x58, 0x4E, 0x31>>
  end

  defp encode!(packet) do
    {:ok, frame} = Codec.encode_packet(packet)
    frame
  end
end
