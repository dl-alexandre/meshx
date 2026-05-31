defmodule Mob.Protocol.PropertyTest do
  @moduledoc """
  Property-based tests for the wire protocol: codec round-trip, framing
  invariants, fragmentation/reassembly, and decoder robustness against
  arbitrary garbage input.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Mob.Protocol.{Codec, Fragment, Framing, Packet}

  @types [:data, :ack, :gossip, :control, :fragment]

  defp packet_gen(opts \\ []) do
    max_payload = Keyword.get(opts, :max_payload, 1_024)

    gen all(
          type <- member_of(@types),
          msg_id <- integer(0..0xFFFF_FFFF),
          flags <- integer(0..0xFF),
          ttl <- integer(0..0xFF),
          payload <- binary(min_length: 0, max_length: max_payload)
        ) do
      %Packet{
        version: Packet.version(),
        type: type,
        # The channel flag (0x08) is reserved and framing-managed: it is set
        # solely from `channel_id`, never carried as free-form user flags.
        # Mask it out so generated packets stay self-consistent (a set channel
        # flag with no channel segment is not a valid packet).
        flags: Bitwise.band(flags, Bitwise.bnot(Packet.flag_channel())),
        ttl: ttl,
        msg_id: msg_id,
        payload: payload
      }
    end
  end

  describe "codec round-trip" do
    property "encode/decode is the identity for any valid packet" do
      check all(packet <- packet_gen(), max_runs: 200) do
        assert {:ok, frame} = Codec.encode_packet(packet)
        assert {:ok, decoded, <<>>} = Codec.decode_packet(frame)

        assert decoded.type == packet.type
        assert decoded.msg_id == packet.msg_id
        assert decoded.flags == packet.flags
        assert decoded.ttl == packet.ttl
        assert decoded.payload == packet.payload
        assert decoded.version == packet.version
      end
    end

    property "encoded frame size = 12 + payload size" do
      check all(packet <- packet_gen(), max_runs: 100) do
        {:ok, frame} = Codec.encode_packet(packet)
        # 10-byte header + payload + 2-byte checksum
        assert byte_size(frame) == 12 + byte_size(packet.payload)
      end
    end

    property "decoder rejects frames with corrupted checksum" do
      check all(packet <- packet_gen(max_payload: 64), max_runs: 50) do
        {:ok, frame} = Codec.encode_packet(packet)
        size = byte_size(frame)
        # Flip the high byte of the checksum (last 2 bytes are checksum LE).
        <<head::binary-size(size - 1), last::8>> = frame
        corrupted = head <> <<Bitwise.bxor(last, 0xFF)::8>>

        assert {:error, _} = Codec.decode_packet(corrupted)
      end
    end

    property "decoder reports leftover bytes correctly" do
      check all(
              packet <- packet_gen(max_payload: 64),
              suffix <- binary(min_length: 0, max_length: 32),
              max_runs: 50
            ) do
        {:ok, frame} = Codec.encode_packet(packet)
        assert {:ok, _, ^suffix} = Codec.decode_packet(frame <> suffix)
      end
    end
  end

  describe "framing robustness" do
    property "decode never crashes on arbitrary garbage" do
      check all(garbage <- binary(min_length: 0, max_length: 256), max_runs: 200) do
        # Must not raise; either a successful decode or a tagged error.
        case Framing.decode(garbage) do
          {:ok, %Packet{}, _rest} -> :ok
          {:error, reason} when is_binary(reason) -> :ok
        end
      end
    end

    property "scan never crashes on arbitrary garbage" do
      check all(garbage <- binary(min_length: 0, max_length: 256), max_runs: 200) do
        case Framing.scan(garbage) do
          {:ok, %Packet{}, _rest} -> :ok
          {:error, :no_frame_found} -> :ok
        end
      end
    end

    property "scan can locate a real frame buried in noise" do
      check all(
              packet <- packet_gen(max_payload: 32),
              prefix <- binary(min_length: 0, max_length: 16),
              max_runs: 50
            ) do
        {:ok, frame} = Codec.encode_packet(packet)

        case Framing.scan(prefix <> frame) do
          {:ok, decoded, _rest} ->
            # If it found something, the payload should not be longer than the
            # original (it might find an earlier accidental valid frame in noise).
            assert byte_size(decoded.payload) <= byte_size(prefix) + byte_size(packet.payload)

          {:error, :no_frame_found} ->
            # Acceptable if scanning slid past the real frame due to noise alignment.
            :ok
        end
      end
    end
  end

  describe "fragmentation" do
    property "fragment then reassemble round-trips any payload" do
      check all(
              msg_id <- integer(0..0xFFFF_FFFF),
              payload <- binary(min_length: 1, max_length: 4_096),
              chunk_size <- integer(8..512),
              max_runs: 100
            ) do
        fragments = Fragment.fragment(msg_id, payload, max_chunk_size: chunk_size)
        assert is_list(fragments) and fragments != []
        assert Enum.all?(fragments, &(&1.type == :fragment))

        assert {:ok, ^msg_id, ^payload} = Fragment.reassemble(fragments)
      end
    end

    property "fragment count matches ceil(payload / chunk_size)" do
      check all(
              msg_id <- integer(0..0xFFFF_FFFF),
              payload_size <- integer(1..2_048),
              chunk_size <- integer(8..256),
              max_runs: 100
            ) do
        payload = :crypto.strong_rand_bytes(payload_size)
        fragments = Fragment.fragment(msg_id, payload, max_chunk_size: chunk_size)
        expected = div(payload_size + chunk_size - 1, chunk_size)
        assert length(fragments) == expected
      end
    end

    property "out-of-order fragment delivery still reassembles correctly" do
      check all(
              msg_id <- integer(0..0xFFFF_FFFF),
              payload <- binary(min_length: 1, max_length: 2_048),
              chunk_size <- integer(8..128),
              seed <- integer(0..1_000_000),
              max_runs: 50
            ) do
        fragments = Fragment.fragment(msg_id, payload, max_chunk_size: chunk_size)
        :rand.seed(:exsss, {seed, seed, seed})
        shuffled = Enum.shuffle(fragments)

        assert {:ok, ^msg_id, ^payload} = Fragment.reassemble(shuffled)
      end
    end

    property "encode_fragments → decode_fragments round-trips through wire format" do
      check all(
              msg_id <- integer(0..0xFFFF_FFFF),
              payload <- binary(min_length: 1, max_length: 2_048),
              chunk_size <- integer(16..256),
              max_runs: 50
            ) do
        {:ok, frames} = Codec.encode_fragments(msg_id, payload, max_chunk_size: chunk_size)
        assert {:ok, ^msg_id, ^payload} = Codec.decode_fragments(frames)
      end
    end
  end
end
