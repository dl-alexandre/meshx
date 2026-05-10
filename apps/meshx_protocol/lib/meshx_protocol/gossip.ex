defmodule MeshxProtocol.Gossip do
  @moduledoc """
  Epidemic gossip primitives for MeshX.

  Gossip messages are used to propagate knowledge of message existence across
  the mesh without forwarding the full payload. Each node periodically emits a
  gossip packet containing a bloom-filter-like summary or a truncated list of
  recently seen message IDs.
  """

  alias MeshxProtocol.Packet

  @doc """
  Creates a gossip packet summarising a list of seen message IDs.

  To keep packets small for BLE, only the most recent N IDs are included
  (default 20).
  """
  @spec gossip_packet([non_neg_integer()], keyword()) :: Packet.t()
  def gossip_packet(msg_ids, opts \\ []) do
    max_ids = Keyword.get(opts, :max_ids, 20)
    ttl = Keyword.get(opts, :ttl, 64)

    ids = msg_ids |> Enum.take(max_ids)

    # Encode as a simple binary: <<count::16-little, id::32-little, ...>>
    payload =
      [<<length(ids)::16-little>> | Enum.map(ids, fn id -> <<id::32-little>> end)]
      |> IO.iodata_to_binary()

    %Packet{
      version: Packet.version(),
      type: :gossip,
      flags: 0,
      ttl: ttl,
      msg_id: :erlang.phash2({:gossip, ids, System.monotonic_time()}),
      payload: payload
    }
  end

  @doc """
  Decodes a gossip packet payload into a list of message IDs.
  """
  @spec decode_gossip(Packet.t()) :: [non_neg_integer()]
  def decode_gossip(%Packet{type: :gossip, payload: payload}) do
    <<count::16-little, rest::binary>> = payload

    rest
    |> :erlang.binary_to_list()
    |> Enum.chunk_every(4)
    |> Enum.take(count)
    |> Enum.map(fn bytes ->
      <<id::32-little>> = IO.iodata_to_binary(bytes)
      id
    end)
  end

  def decode_gossip(%Packet{}), do: []

  @doc """
  Merges two gossip sets (union of message IDs).
  """
  @spec merge([non_neg_integer()], [non_neg_integer()]) :: [non_neg_integer()]
  def merge(set_a, set_b) do
    MapSet.union(MapSet.new(set_a), MapSet.new(set_b))
    |> MapSet.to_list()
  end

  @doc """
  Returns the difference: IDs in `remote` that are not in `local`.
  These are messages the local node may want to request.
  """
  @spec missing([non_neg_integer()], [non_neg_integer()]) :: [non_neg_integer()]
  def missing(local, remote) do
    MapSet.difference(MapSet.new(remote), MapSet.new(local))
    |> MapSet.to_list()
  end
end
