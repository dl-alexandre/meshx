defmodule Mob.Protocol.CodecTest do
  use ExUnit.Case

  alias Mob.Protocol.{Codec, Packet}

  test "encode_fragments and decode_fragments round-trip payloads" do
    payload = :binary.copy("mob", 80)

    assert {:ok, frames} = Codec.encode_fragments(123, payload, max_chunk_size: 64)
    assert length(frames) > 1
    assert {:ok, 123, ^payload} = Codec.decode_fragments(frames)
  end

  test "decode_fragments reports incomplete fragment sets" do
    payload = :binary.copy("x", 200)
    {:ok, frames} = Codec.encode_fragments(456, payload, max_chunk_size: 60)

    assert {:incomplete, 1, total} = Codec.decode_fragments(Enum.take(frames, 1))
    assert total > 1
  end

  test "decode_fragments returns decode errors for malformed frames" do
    assert {:error, "insufficient data for header + checksum"} =
             Codec.decode_fragments([<<1, 2>>])
  end

  test "encode_packet returns framing errors" do
    packet = %Packet{type: :bad_type, msg_id: 1, payload: <<>>}

    assert {:error, "unknown packet type: :bad_type"} = Codec.encode_packet(packet)
  end
end
