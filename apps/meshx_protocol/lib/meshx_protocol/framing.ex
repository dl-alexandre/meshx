defmodule MeshxProtocol.Framing do
  @moduledoc """
  Frame encoding and decoding for MeshX packets.

  Each frame is:

      <<version::8, type::8, flags::8, ttl::8, payload_len::16-little,
        msg_id::32-little,
        # optional, present only when the channel flag (0x08) is set:
        chan_len::8, channel_id::bytes-size(chan_len),
        payload::bytes-size(payload_len),
        checksum::16-little>>

  The channel segment is cleartext (so relays/receivers can scope-filter
  without decrypting) and is omitted for the default empty channel, making
  channel-less frames byte-identical to the original format. The 2-byte
  checksum is a truncated CRC-32 over the header + channel segment + payload.
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
    channel_id = packet.channel_id || ""
    payload_len = byte_size(packet.payload)

    cond do
      type_byte == :unknown ->
        {:error, "unknown packet type: #{inspect(packet.type)}"}

      payload_len > 65_535 ->
        {:error, "payload exceeds maximum 65,535 bytes"}

      byte_size(channel_id) > 255 ->
        {:error, "channel_id exceeds maximum 255 bytes"}

      true ->
        flags =
          if channel_id == "",
            do: packet.flags,
            else: Packet.set_flag(packet.flags, Packet.flag_channel())

        header =
          <<packet.version::8, type_byte::8, flags::8, packet.ttl::8, payload_len::16-little,
            packet.msg_id::32-little>>

        body = header <> channel_segment(channel_id) <> packet.payload
        checksum = compute_checksum(body)
        {:ok, body <> <<checksum::16-little>>}
    end
  end

  defp channel_segment(""), do: <<>>
  defp channel_segment(channel_id), do: <<byte_size(channel_id)::8, channel_id::binary>>

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
    <<version::8, type_byte::8, flags::8, ttl::8, payload_len::16-little, msg_id::32-little,
      rest::binary>> = binary

    with {:ok, channel_id, after_channel} <- take_channel(flags, rest),
         true <-
           byte_size(after_channel) >= payload_len + @checksum_size or
             {:error, "insufficient data for payload + checksum"} do
      <<payload::bytes-size(payload_len), checksum::16-little, leftover::binary>> = after_channel

      header =
        <<version::8, type_byte::8, flags::8, ttl::8, payload_len::16-little, msg_id::32-little>>

      expected_checksum = compute_checksum(header <> channel_segment(channel_id) <> payload)

      if checksum != expected_checksum do
        {:error, "checksum mismatch"}
      else
        packet = %Packet{
          version: version,
          type: Packet.byte_type(type_byte),
          flags: flags,
          ttl: ttl,
          msg_id: msg_id,
          payload: payload,
          channel_id: channel_id
        }

        {:ok, packet, leftover}
      end
    end
  end

  defp take_channel(flags, rest) do
    if Packet.flag_set?(flags, Packet.flag_channel()) do
      case rest do
        <<chan_len::8, channel_id::bytes-size(chan_len), after_channel::binary>> ->
          {:ok, channel_id, after_channel}

        _ ->
          {:error, "insufficient data for channel segment"}
      end
    else
      {:ok, "", rest}
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
