defmodule MeshxRuntime.FragmentBuffer do
  @moduledoc """
  Buffers inbound fragment packets until the original frame can be reassembled.

  The protocol fragment payload contains the original message id, fragment index,
  total fragment count, and byte chunk. The router fragments whole encoded
  protocol frames, so successful reassembly returns the original frame binary.
  """

  use GenServer

  alias MeshxProtocol.{Fragment, Packet}

  @type add_result ::
          {:complete, non_neg_integer(), binary()}
          | {:partial, non_neg_integer(), pos_integer()}
          | {:error, term()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @spec add(Packet.t()) :: add_result()
  def add(%Packet{type: :fragment} = packet) do
    GenServer.call(__MODULE__, {:add, packet})
  end

  @doc false
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:add, packet}, _from, state) do
    case parse(packet) do
      {:ok, original_id, index, total} ->
        fragments =
          state
          |> Map.get(original_id, %{})
          |> Map.put(index, packet)

        if map_size(fragments) == total do
          packets = Map.values(fragments)

          case Fragment.reassemble(packets) do
            {:ok, ^original_id, frame} ->
              {:reply, {:complete, original_id, frame}, Map.delete(state, original_id)}

            {:incomplete, received, expected} ->
              {:reply, {:partial, received, expected}, Map.put(state, original_id, fragments)}
          end
        else
          {:reply, {:partial, map_size(fragments), total}, Map.put(state, original_id, fragments)}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{}}
  end

  defp parse(%Packet{payload: <<original_id::32-little, index::8, total::8, _chunk::binary>>})
       when total > 0 and index < total do
    {:ok, original_id, index, total}
  end

  defp parse(_packet), do: {:error, :malformed_fragment}
end
