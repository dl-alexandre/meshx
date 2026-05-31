defmodule Mob.Protocol.Codec do
  @moduledoc """
  High-level codec API for MeshX protocol packets.

  Orchestrates framing, fragmentation, and reassembly into a single module.
  """

  alias Mob.Protocol.{Framing, Fragment, Packet}

  @doc """
  Encodes a packet into a framed binary.
  """
  @spec encode_packet(Packet.t()) :: {:ok, binary()} | {:error, String.t()}
  def encode_packet(%Packet{} = packet) do
    Framing.encode(packet)
  end

  @doc """
  Decodes a binary into a packet, returning any leftover bytes.
  """
  @spec decode_packet(binary()) :: {:ok, Packet.t(), binary()} | {:error, String.t()}
  def decode_packet(binary) do
    Framing.decode(binary)
  end

  @doc """
  Encodes a large payload by fragmenting it into multiple framed packets.

  ## Options

    * `:max_chunk_size` – see `Mob.Protocol.Fragment.fragment/3`.
    * `:ttl` – TTL for each fragment.
    * `:flags` – flags for each fragment.

  Returns `{:ok, [binary()]}` where each binary is a framed fragment.
  """
  @spec encode_fragments(non_neg_integer(), binary(), keyword()) ::
          {:ok, [binary()]} | {:error, String.t()}
  def encode_fragments(original_msg_id, payload, opts \\ []) do
    fragments = Fragment.fragment(original_msg_id, payload, opts)

    Enum.reduce_while(fragments, {:ok, []}, fn frag, {:ok, acc} ->
      case Framing.encode(frag) do
        {:ok, frame} -> {:cont, {:ok, [frame | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, frames} -> {:ok, Enum.reverse(frames)}
      error -> error
    end
  end

  @doc """
  Decodes a list of framed fragments and reassembles the original payload.

  Returns `{:ok, original_msg_id, payload}` or `{:incomplete, received, total}`.
  """
  @spec decode_fragments([binary()]) ::
          {:ok, non_neg_integer(), binary()}
          | {:incomplete, non_neg_integer(), pos_integer()}
          | {:error, String.t()}
  def decode_fragments(frames) do
    packets =
      Enum.reduce_while(frames, {:ok, []}, fn frame, {:ok, acc} ->
        case Framing.decode(frame) do
          {:ok, packet, _rest} -> {:cont, {:ok, [packet | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case packets do
      {:ok, decoded} -> Fragment.reassemble(decoded)
      error -> error
    end
  end
end
