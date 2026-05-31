defmodule Mob.Runtime.FlowControl do
  @moduledoc """
  Per-peer send window and bounded queue for ACK-tracked packets.
  """

  alias Mob.Protocol.Packet

  defstruct send_window: 8,
            queue_limit: 256,
            in_flight: %{},
            queues: %{}

  @type queued_packet :: {Packet.t(), keyword()}
  @type t :: %__MODULE__{
          send_window: pos_integer(),
          queue_limit: non_neg_integer(),
          in_flight: %{optional(term()) => MapSet.t(non_neg_integer())},
          queues: %{optional(term()) => :queue.queue(queued_packet())}
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      send_window: max(1, Keyword.get(opts, :send_window, 8)),
      queue_limit: max(0, Keyword.get(opts, :queue_limit, 256))
    }
  end

  @spec reserve(t(), term(), Packet.t(), keyword()) ::
          {:send, t()}
          | {:untracked, t()}
          | {:queued, non_neg_integer(), t()}
          | {:error, :queue_full, t()}
  def reserve(%__MODULE__{} = flow, peer_id, %Packet{} = packet, opts) do
    if controlled?(packet, opts) do
      reserve_controlled(flow, peer_id, packet, opts)
    else
      {:untracked, flow}
    end
  end

  @spec release(t(), term(), non_neg_integer()) :: {t(), queued_packet() | nil}
  def release(%__MODULE__{} = flow, peer_id, msg_id) do
    flow
    |> remove_in_flight(peer_id, msg_id)
    |> pop_next(peer_id)
  end

  @spec controlled?(Packet.t(), keyword()) :: boolean()
  def controlled?(%Packet{flags: flags}, opts) do
    Keyword.get(opts, :flow_control, true) and
      Packet.flag_set?(flags, Packet.flag_ack_requested())
  end

  defp reserve_controlled(flow, peer_id, packet, opts) do
    send_window = Keyword.get(opts, :send_window, flow.send_window)
    queue_limit = Keyword.get(opts, :queue_limit, flow.queue_limit)

    cond do
      in_flight_count(flow, peer_id) < send_window ->
        {:send, track(flow, peer_id, packet.msg_id)}

      queue_depth(flow, peer_id) < queue_limit ->
        flow = enqueue(flow, peer_id, packet, opts)
        {:queued, queue_depth(flow, peer_id), flow}

      true ->
        {:error, :queue_full, flow}
    end
  end

  defp track(flow, peer_id, msg_id) do
    in_flight = Map.update(flow.in_flight, peer_id, MapSet.new([msg_id]), &MapSet.put(&1, msg_id))
    %{flow | in_flight: in_flight}
  end

  defp remove_in_flight(flow, peer_id, msg_id) do
    in_flight =
      Map.update(flow.in_flight, peer_id, MapSet.new(), fn msg_ids ->
        MapSet.delete(msg_ids, msg_id)
      end)

    %{flow | in_flight: in_flight}
  end

  defp pop_next(flow, peer_id) do
    queue = Map.get(flow.queues, peer_id, :queue.new())

    case :queue.out(queue) do
      {{:value, {packet, opts}}, queue} ->
        flow =
          flow
          |> put_queue(peer_id, queue)
          |> track(peer_id, packet.msg_id)

        {flow, {packet, opts}}

      {:empty, _queue} ->
        {flow, nil}
    end
  end

  defp enqueue(flow, peer_id, packet, opts) do
    queue = :queue.in({packet, opts}, Map.get(flow.queues, peer_id, :queue.new()))

    put_queue(flow, peer_id, queue)
  end

  defp put_queue(flow, peer_id, queue) do
    if :queue.is_empty(queue) do
      %{flow | queues: Map.delete(flow.queues, peer_id)}
    else
      %{flow | queues: Map.put(flow.queues, peer_id, queue)}
    end
  end

  defp in_flight_count(flow, peer_id) do
    flow.in_flight
    |> Map.get(peer_id, MapSet.new())
    |> MapSet.size()
  end

  defp queue_depth(flow, peer_id) do
    flow.queues
    |> Map.get(peer_id, :queue.new())
    |> :queue.len()
  end
end
