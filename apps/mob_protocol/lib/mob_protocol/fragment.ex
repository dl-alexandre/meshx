defmodule Mob.Protocol.Fragment do
  @moduledoc """
  Packet fragmentation and reassembly.

  Designed for BLE-like transports with small MTUs. A large payload is split
  into chunks, each wrapped in a `fragment` packet carrying metadata needed
  for reassembly.

  Fragment payload layout:

      <<original_msg_id::32-little, frag_index::8, total_frags::8, chunk::binary>>
  """

  alias Mob.Protocol.Packet

  @doc """
  Fragments a raw payload into a list of fragment packets.

  ## Options

    * `:max_chunk_size` – maximum bytes per fragment chunk (default: 185).
      BLE ATT MTU is often 185 after headers on mobile.
    * `:ttl` – TTL to assign to each fragment (default: 64).
    * `:flags` – flags to assign to each fragment (default: 0).

  The returned packets have `type: :fragment` and sequential `msg_id`s
  derived from a hash of the original message id and index.
  """
  @spec fragment(non_neg_integer(), binary(), keyword()) :: [Packet.t()]
  def fragment(original_msg_id, payload, opts \\ []) do
    max_chunk = Keyword.get(opts, :max_chunk_size, 185)
    ttl = Keyword.get(opts, :ttl, 64)
    flags = Keyword.get(opts, :flags, 0)

    chunks = chunk_payload(payload, max_chunk)
    total = length(chunks)

    chunks
    |> Enum.with_index()
    |> Enum.map(fn {chunk, index} ->
      frag_payload =
        <<original_msg_id::32-little, index::8, total::8, chunk::binary>>

      # Unique msg_id per fragment to help deduplication/ACKs
      frag_msg_id = :erlang.phash2({original_msg_id, index})

      %Packet{
        version: Packet.version(),
        type: :fragment,
        flags: flags,
        ttl: ttl,
        msg_id: frag_msg_id,
        payload: frag_payload
      }
    end)
  end

  @doc """
  Attempts to reassemble a list of fragment packets into the original payload.

  Returns `{:ok, original_msg_id, payload}` or `{:incomplete, received_count, total_count}`.
  """
  @spec reassemble([Packet.t()]) ::
          {:ok, non_neg_integer(), binary()} | {:incomplete, non_neg_integer(), pos_integer()}
  def reassemble(fragments) do
    parsed =
      Enum.map(fragments, fn %Packet{type: :fragment, payload: payload} ->
        <<original_msg_id::32-little, index::8, total::8, chunk::binary>> = payload
        {original_msg_id, index, total, chunk}
      end)

    [{original_msg_id, _idx, total, _chunk} | _] = parsed

    indexed =
      parsed
      |> Enum.sort_by(fn {_, idx, _, _} -> idx end)
      |> Enum.map(fn {_, idx, _, chunk} -> {idx, chunk} end)
      |> Enum.into(%{})

    received = map_size(indexed)

    if received == total do
      payload =
        0..(total - 1)
        |> Enum.map(fn i -> Map.fetch!(indexed, i) end)
        |> IO.iodata_to_binary()

      {:ok, original_msg_id, payload}
    else
      {:incomplete, received, total}
    end
  end

  @doc """
  Checks if a set of fragments is complete.
  """
  @spec complete?([Packet.t()]) :: boolean()
  def complete?(fragments) do
    case reassemble(fragments) do
      {:ok, _, _} -> true
      {:incomplete, _, _} -> false
    end
  end

  # --- Internal ---

  defp chunk_payload(<<>>, _), do: []

  defp chunk_payload(payload, size) do
    case payload do
      <<chunk::bytes-size(^size), rest::binary>> ->
        [chunk | chunk_payload(rest, size)]

      last_chunk ->
        [last_chunk]
    end
  end
end
