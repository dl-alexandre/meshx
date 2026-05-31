defmodule Mob.Runtime.Outbox do
  @moduledoc """
  Runtime store-and-forward worker.

  Packets can be queued for one or more destination peers while they are
  offline. When the router reports a matching peer as available, this worker
  decodes the stored packet and asks the router to send it over the currently
  attached transport.
  """

  use GenServer

  alias Mob.Protocol.{Codec, Packet}
  alias Mob.Runtime.{PeerRegistry, Router, Telemetry}
  alias Mob.Store.Outbox, as: StoreOutbox

  @default_limit 100
  @default_retry_interval_ms :timer.seconds(30)
  @default_max_retry_backoff_ms :timer.minutes(5)

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec enqueue(term(), Packet.t(), keyword()) :: {:ok, struct()} | {:error, term()}
  def enqueue(peer_id, %Packet{} = packet, opts \\ []) do
    GenServer.call(__MODULE__, {:enqueue, peer_id, packet, opts})
  end

  @spec track_sent(term(), Packet.t(), keyword()) :: {:ok, struct()} | {:error, term()}
  def track_sent(peer_id, %Packet{} = packet, opts \\ []) do
    GenServer.call(__MODULE__, {:track_sent, peer_id, packet, opts})
  end

  @spec replay(term()) :: :ok
  def replay(peer_id) do
    GenServer.cast(__MODULE__, {:replay, peer_id})
  end

  @spec retry_now() :: :ok
  def retry_now do
    GenServer.cast(__MODULE__, :retry)
  end

  @doc false
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def init(opts) do
    Router.subscribe(self())
    interval = Keyword.get(opts, :retry_interval_ms, @default_retry_interval_ms)
    max_backoff = Keyword.get(opts, :max_retry_backoff_ms, @default_max_retry_backoff_ms)
    auto_retry? = Keyword.get(opts, :auto_retry?, true)
    _ = if auto_retry?, do: schedule_retry(interval)

    {:ok,
     %{
       limit: Keyword.get(opts, :limit, @default_limit),
       retry_interval_ms: interval,
       max_retry_backoff_ms: max_backoff,
       retry_attempt: 0,
       auto_retry?: auto_retry?
     }}
  end

  @impl true
  def handle_call({:enqueue, peer_id, packet, opts}, _from, state) do
    result = enqueue_packet(peer_id, packet, opts)
    {:reply, result, state}
  end

  def handle_call({:track_sent, peer_id, packet, opts}, _from, state) do
    result = enqueue_packet(peer_id, packet, Keyword.put_new(opts, :attempts, 1))
    {:reply, result, state}
  end

  def handle_call(:reset, _from, state) do
    Router.subscribe(self())
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:replay, peer_id}, state) do
    replay_peer(peer_id, state)
    {:noreply, state}
  end

  def handle_cast(:retry, state) do
    retry_visible_peers(state)
    {:noreply, bump_retry_attempt(state)}
  end

  @impl true
  def handle_info({:mob_runtime, :peer_up, _transport, %{id: peer_id}}, state) do
    replay_peer(peer_id, state)
    {:noreply, %{state | retry_attempt: 0}}
  end

  def handle_info(:retry, %{auto_retry?: auto_retry?} = state) do
    retry_visible_peers(state)
    state = bump_retry_attempt(state)
    _ = if auto_retry?, do: schedule_retry(next_retry_interval(state))
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp enqueue_packet(peer_id, packet, opts) do
    packet = request_ack(packet)

    with {:ok, frame} <- Codec.encode_packet(packet) do
      attempts = Keyword.get(opts, :attempts, 0)
      max_attempts = Keyword.get(opts, :max_attempts, 5)
      status = Keyword.get(opts, :status, initial_status(attempts, max_attempts))

      result =
        StoreOutbox.enqueue(%{
          msg_id: packet.msg_id,
          payload: frame,
          destinations: [destination(peer_id)],
          attempts: attempts,
          max_attempts: max_attempts,
          status: status
        })

      case result do
        {:ok, record} ->
          Telemetry.execute([:outbox, :enqueue, :stop], %{count: 1}, %{
            peer_id: peer_id,
            msg_id: packet.msg_id,
            record_id: record.id
          })

        {:error, reason} ->
          Telemetry.execute([:outbox, :enqueue, :error], %{count: 1}, %{
            peer_id: peer_id,
            msg_id: packet.msg_id,
            reason: reason
          })
      end

      result
    end
  end

  defp replay_peer(peer_id, state) do
    peer_id
    |> StoreOutbox.pending_for_destination(state.limit)
    |> Enum.each(&replay_record(peer_id, &1))
  end

  defp replay_record(peer_id, record) do
    with {:ok, packet, _rest} <- Codec.decode_packet(record.payload),
         :ok <- Router.send_packet(peer_id, packet, store: false, flow_control: false) do
      Telemetry.execute([:outbox, :replay, :stop], %{count: 1}, %{
        peer_id: peer_id,
        msg_id: record.msg_id,
        record_id: record.id
      })

      StoreOutbox.record_attempt_by_id(record.id)
    else
      error ->
        Telemetry.execute([:outbox, :replay, :error], %{count: 1}, %{
          peer_id: peer_id,
          msg_id: record.msg_id,
          record_id: record.id,
          reason: error
        })

        StoreOutbox.mark_failed_by_id(record.id)
    end
  end

  defp retry_visible_peers(state) do
    Telemetry.execute([:outbox, :retry, :start], %{count: 1}, %{
      limit: state.limit,
      attempt: state.retry_attempt,
      next_interval_ms: next_retry_interval(state)
    })

    PeerRegistry.list()
    |> Enum.each(fn peer -> replay_peer(peer.id, state) end)
  end

  defp request_ack(%Packet{flags: flags} = packet) do
    %{packet | flags: Packet.set_flag(flags, Packet.flag_ack_requested())}
  end

  defp initial_status(attempts, max_attempts) when attempts >= max_attempts, do: :failed
  defp initial_status(_attempts, _max_attempts), do: :pending

  defp schedule_retry(interval) do
    Process.send_after(self(), :retry, interval)
  end

  defp bump_retry_attempt(state) do
    %{state | retry_attempt: state.retry_attempt + 1}
  end

  defp next_retry_interval(state) do
    retry_interval_for(state.retry_attempt, state.retry_interval_ms, state.max_retry_backoff_ms)
  end

  @doc """
  Backoff for a retry attempt: exponential (`interval * 2^attempt`), capped at
  `max_backoff_ms`, then equal-jittered into `[capped/2, capped]`.

  Jitter decorrelates retries so peers/workers that went offline together don't
  resend in lockstep when they return. Exposed for unit testing.
  """
  @spec retry_interval_for(non_neg_integer(), pos_integer(), pos_integer()) :: pos_integer()
  def retry_interval_for(attempt, interval_ms, max_backoff_ms)
      when is_integer(attempt) and attempt >= 0 do
    capped = min(interval_ms * 2 ** attempt, max_backoff_ms)
    apply_jitter(capped)
  end

  defp apply_jitter(ms) when ms <= 1, do: ms

  defp apply_jitter(ms) do
    floor = div(ms, 2)
    floor + :rand.uniform(ms - floor)
  end

  defp destination(peer_id), do: to_string(peer_id)
end
