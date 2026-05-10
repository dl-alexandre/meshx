defmodule MeshxProtocol.Framing do
  @moduledoc """
  Frame encoding and decoding for MeshX packets.

  Each frame is:

      <<version::8, type::8, flags::8, ttl::8, payload_len::16-little,
        msg_id::32-little, payload::bytes-size(payload_len),
        checksum::16-little>>

  The 2-byte checksum is a truncated CRC-32 over the header + payload.
  """

  alias MeshxProtocol.Packet

  @header_size 10
  @checksum_size 2

  @doc """
  Encodes a `Packet` into a framed binary.

  Returns `{:ok, frame_binary}` or `{:error, reason}`.
  """
  @spec encode(Packet.t()) :: {:ok, binary()} | {:error, String.t()}
  def encode(%Packet{} = packet) do
    type_byte = Packet.type_byte(packet.type)

    if type_byte == :unknown do
      {:error, "unknown packet type: #{inspect(packet.type)}"}
    else
      payload_len = byte_size(packet.payload)

      if payload_len > 65_535 do
        {:error, "payload exceeds maximum 65,535 bytes"}
      else
        header =
          <<packet.version::8, type_byte::8, packet.flags::8, packet.ttl::8,
            payload_len::16-little, packet.msg_id::32-little>>

        checksum = compute_checksum(header <> packet.payload)
        frame = header <> packet.payload <> <<checksum::16-little>>
        {:ok, frame}
      end
    end
  end

  @doc """
  Decodes a binary into a `Packet`.

  Returns `{:ok, packet, rest}` where `rest` is any unconsumed bytes,
  or `{:error, reason}`.
  """
  @spec decode(binary()) :: {:ok, Packet.t(), binary()} | {:error, String.t()}
  def decode(binary) when byte_size(binary) < @header_size + @checksum_size do
    {:error, "insufficient data for header + checksum"}
  end

  def decode(binary) do
    <<version::8, type_byte::8, flags::8, ttl::8, payload_len::16-little,
      msg_id::32-little, rest::binary>> = binary

    total_needed = payload_len + @checksum_size

    if byte_size(rest) < total_needed do
      {:error, "insufficient data for payload + checksum"}
    else
      <<payload::bytes-size(payload_len), checksum::16-little, leftover::binary>> = rest

      header =
        <<version::8, type_byte::8, flags::8, ttl::8, payload_len::16-little,
          msg_id::32-little>>

      expected_checksum = compute_checksum(header <> payload)

      if checksum != expected_checksum do
        {:error, "checksum mismatch"}
      else
        packet = %Packet{
          version: version,
          type: Packet.byte_type(type_byte),
          flags: flags,
          ttl: ttl,
          msg_id: msg_id,
          payload: payload
        }

        {:ok, packet, leftover}
      end
    end
  end

  @doc """
  Scans a binary for the first valid frame.

  Useful when reading from a stream where frame boundaries may be unknown.
  Returns `{:ok, packet, rest}` or `{:error, :no_frame_found}`.
  """
  @spec scan(binary()) :: {:ok, Packet.t(), binary()} | {:error, atom()}
  def scan(binary) when byte_size(binary) < @header_size + @checksum_size do
    {:error, :no_frame_found}
  end

  def scan(binary) do
    case decode(binary) do
      {:ok, packet, rest} ->
        {:ok, packet, rest}

      {:error, _reason} ->
        <<_byte, rest::binary>> = binary
        scan(rest)
    end
  end

  # --- Internal ---

  defp compute_checksum(data) do
    # Truncate CRC-32 to 16 bits for a compact, good-enough checksum.
    Bitwise.band(:erlang.crc32(data), 0xFFFF)
  end
end
