defmodule MeshxMobileApp.Chat.ChannelViewModel do
  @moduledoc """
  Per-channel chat ViewModel.

  Subscribes to `MeshxRuntime.Router` filtered by the channel id, folds
  inbound `MeshxProtocol.Packet`s carrying a `MessageEnvelope` of
  `payload_type: "CHAT"` into a list of `Message`s, and exposes both
  a synchronous `snapshot/1` and a push-based `subscribe/2` so screens
  can render without re-querying.

  Outbound messages are appended locally with `direction: :out, status:
  :pending` when the user calls `send_text/2`; the entry is reconciled
  to `:delivered` when the ack for that envelope `message_id` arrives
  on the router (future step — ack reconciliation lives in a follow-up
  commit; for now outbound entries stay `:pending` after dispatch).

  The Router subscription is optional at start (tests inject `router:
  nil` to skip), so the VM is unit-testable by sending it a router-shape
  message directly via `send/2`.
  """

  use GenServer

  alias MeshxMobileApp.BLE.MessageEnvelope
  alias MeshxMobileApp.Chat.Composer
  alias MeshxProtocol.Packet

  defmodule Message do
    @moduledoc false
    @enforce_keys [:message_id, :sender_peer_id, :body, :at, :direction, :status]
    defstruct [:message_id, :sender_peer_id, :body, :at, :direction, :status]

    @type direction :: :in | :out
    @type status :: :pending | :delivered | :failed
    @type t :: %__MODULE__{
            message_id: binary(),
            sender_peer_id: binary(),
            body: binary(),
            at: integer(),
            direction: direction(),
            status: status()
          }
  end

  @type snapshot :: %{
          channel: String.t(),
          messages: [Message.t()],
          message_count: non_neg_integer()
        }

  # ── public API ───────────────────────────────────────────────────────────

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name)
    server_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, server_opts)
  end

  @spec snapshot(GenServer.server()) :: snapshot()
  def snapshot(server), do: GenServer.call(server, :snapshot)

  @doc """
  Subscribes `pid` to receive `{__MODULE__, :updated, snapshot}` messages
  on every state change. Returns the current snapshot for an initial
  render without a race against the next update.
  """
  @spec subscribe(GenServer.server(), pid()) :: {:ok, snapshot()}
  def subscribe(server, pid \\ self()) do
    GenServer.call(server, {:subscribe, pid})
  end

  @doc """
  Sends `text` on this channel. Builds the packet via `Composer`,
  dispatches via the configured router's `broadcast_packet/2`, and
  appends a `:pending`-status `:out` entry to the local view.
  """
  @spec send_text(GenServer.server(), String.t()) ::
          {:ok, binary()} | {:error, term()}
  def send_text(server, text), do: GenServer.call(server, {:send_text, text})

  # ── GenServer ────────────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    channel = Keyword.fetch!(opts, :channel)
    router = Keyword.get(opts, :router, MeshxRuntime.Router)

    state = %{
      channel: channel,
      router: router,
      messages: [],
      subscribers: MapSet.new()
    }

    case router && subscribe_to_router(router, channel) do
      :ok -> {:ok, state}
      nil -> {:ok, state}
      # Treat any subscribe error as non-fatal; the VM still works for the
      # local send path and tests can inject without a router.
      _ -> {:ok, state}
    end
  end

  defp subscribe_to_router(router, channel) do
    try do
      router.subscribe(self(), channels: [channel])
    rescue
      _ -> :error
    catch
      :exit, _ -> :error
    end
  end

  @impl true
  def handle_call(:snapshot, _from, state), do: {:reply, to_snapshot(state), state}

  def handle_call({:subscribe, pid}, _from, state) do
    state = %{state | subscribers: MapSet.put(state.subscribers, pid)}
    {:reply, {:ok, to_snapshot(state)}, state}
  end

  def handle_call({:send_text, text}, _from, state) do
    with {:ok, packet, message_id} <- Composer.build_packet(state.channel, text),
         :ok <- dispatch(state.router, packet) do
      out = %Message{
        message_id: message_id,
        sender_peer_id: local_sender(),
        body: text,
        at: System.system_time(:millisecond),
        direction: :out,
        status: :pending
      }

      state = append(state, out)
      {:reply, {:ok, message_id}, state}
    else
      {:error, _reason} = err -> {:reply, err, state}
    end
  end

  @impl true
  def handle_info({:meshx_runtime, :packet, _transport, _peer_id, %Packet{} = packet}, state) do
    state =
      case maybe_chat_message(packet, state.channel) do
        {:ok, message} -> append(state, message)
        :skip -> state
      end

    {:noreply, state}
  end

  def handle_info(_other, state), do: {:noreply, state}

  # ── pure helpers (unit-testable without a process) ───────────────────────

  @doc false
  @spec maybe_chat_message(Packet.t(), String.t()) :: {:ok, Message.t()} | :skip
  def maybe_chat_message(%Packet{channel_id: channel_id, payload: payload}, channel)
      when channel_id == channel do
    with {:ok, envelope} <- MessageEnvelope.parse(payload),
         true <- envelope.payload_type == Composer.payload_type() do
      {:ok,
       %Message{
         message_id: envelope.message_id,
         sender_peer_id: envelope.sender_peer_id,
         body: envelope.payload,
         at: envelope.created_at,
         direction: :in,
         status: :delivered
       }}
    else
      _ -> :skip
    end
  end

  def maybe_chat_message(_packet, _channel), do: :skip

  defp append(state, %Message{} = message) do
    state = %{state | messages: state.messages ++ [message]}
    snapshot = to_snapshot(state)
    Enum.each(state.subscribers, &send(&1, {__MODULE__, :updated, snapshot}))
    state
  end

  defp to_snapshot(state) do
    %{
      channel: state.channel,
      messages: state.messages,
      message_count: length(state.messages)
    }
  end

  defp dispatch(nil, _packet), do: :ok
  defp dispatch(router, packet), do: router.broadcast_packet(packet)

  # The composer reads identity from MeshxStore; for the local-out display
  # entry we just need the local peer_id. Identity.get/0's spec is
  # `{:ok, t()}`; let the call crash if the store isn't up so the supervisor
  # surfaces the real cause instead of masking it as a "local" sender label.
  defp local_sender do
    {:ok, %{peer_id: peer_id}} = MeshxMobileApp.Chat.Identity.get()
    peer_id
  end
end
