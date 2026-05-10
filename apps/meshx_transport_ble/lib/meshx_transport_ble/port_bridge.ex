defmodule MeshxTransportBLE.PortBridge do
  @moduledoc """
  Port-backed BLE bridge for native platform adapters.

  This bridge starts an external executable and exchanges newline-delimited,
  base64-encoded Erlang terms. It gives the Elixir transport a production
  boundary for platform BLE implementations without making the runtime depend
  on CoreBluetooth, Android BLE, or BlueZ directly.

  Outbound commands sent to the native process:

    * `{:send_frame, peer_id, frame, opts}`
    * `{:broadcast_frame, frame, opts}`

  When `:command_ack?` is enabled, commands include an integer command id and
  the native process must answer with:

    * `{:command_result, command_id, :ok}`
    * `{:command_error, command_id, reason}`

  Inbound events expected from the native process:

    * `{:peer_up, peer_id, metadata}`
    * `{:peer_down, peer_id}`
    * `{:frame, peer_id, frame}`
  """

  @behaviour MeshxTransportBLE.Bridge

  use GenServer

  @impl MeshxTransportBLE.Bridge
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl MeshxTransportBLE.Bridge
  def send_frame(bridge, peer_id, frame, opts \\ []) do
    GenServer.call(bridge, {:send_frame, peer_id, frame, opts}, :infinity)
  end

  @impl MeshxTransportBLE.Bridge
  def broadcast_frame(bridge, frame, opts \\ []) do
    GenServer.call(bridge, {:broadcast_frame, frame, opts}, :infinity)
  end

  @impl true
  def init(opts) do
    command = Keyword.fetch!(opts, :command)
    args = Keyword.get(opts, :args, [])
    event_target = Keyword.fetch!(opts, :event_target)
    command_ack? = Keyword.get(opts, :command_ack?, false)
    command_timeout_ms = Keyword.get(opts, :command_timeout_ms, 5_000)

    port =
      Port.open({:spawn_executable, command}, [
        :binary,
        :exit_status,
        {:args, args},
        {:line, 65_536}
      ])

    {:ok,
     %{
       port: port,
       event_target: event_target,
       command_ack?: command_ack?,
       command_timeout_ms: command_timeout_ms,
       next_command_id: 1,
       pending: %{}
     }}
  end

  @impl true
  def handle_call({:send_frame, peer_id, frame, opts}, from, state) do
    send_command(state, from, {:send_frame, peer_id, frame, opts})
  end

  def handle_call({:broadcast_frame, frame, opts}, from, state) do
    send_command(state, from, {:broadcast_frame, frame, opts})
  end

  @impl true
  def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state) do
    state =
      line
      |> decode_line()
      |> handle_native_event(state)

    {:noreply, state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    send(state.event_target, {:ble_bridge_down, status})

    state =
      state
      |> reply_pending({:error, {:bridge_down, status}})
      |> Map.put(:pending, %{})

    {:noreply, state}
  end

  def handle_info({:command_timeout, command_id}, state) do
    case Map.pop(state.pending, command_id) do
      {nil, pending} ->
        {:noreply, %{state | pending: pending}}

      {%{from: from}, pending} ->
        GenServer.reply(from, {:error, :command_timeout})
        {:noreply, %{state | pending: pending}}
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

  @doc false
  @spec encode_term(term()) :: binary()
  def encode_term(term) do
    term
    |> :erlang.term_to_binary()
    |> Base.encode64()
  end

  defp send_command(%{command_ack?: false, port: port} = state, _from, command) do
    write_command(port, command)
    {:reply, :ok, state}
  end

  defp send_command(%{command_ack?: true} = state, from, command) do
    command_id = state.next_command_id
    timer = Process.send_after(self(), {:command_timeout, command_id}, state.command_timeout_ms)
    write_command(state.port, command_with_id(command, command_id))

    state = %{
      state
      | next_command_id: command_id + 1,
        pending: Map.put(state.pending, command_id, %{from: from, timer: timer})
    }

    {:noreply, state}
  end

  defp write_command(port, command) do
    send(port, {self(), {:command, encode_term(command) <> "\n"}})
  end

  defp command_with_id({:send_frame, peer_id, frame, opts}, command_id) do
    {:send_frame, command_id, peer_id, frame, opts}
  end

  defp command_with_id({:broadcast_frame, frame, opts}, command_id) do
    {:broadcast_frame, command_id, frame, opts}
  end

  defp decode_line(line) do
    with {:ok, binary} <- Base.decode64(to_string(line)) do
      {:ok, :erlang.binary_to_term(binary, [:safe])}
    end
  rescue
    _error -> {:error, :invalid_event}
  end

  defp handle_native_event({:ok, {:command_result, command_id, :ok}}, state) do
    reply_command(command_id, :ok, state)
  end

  defp handle_native_event({:ok, {:command_error, command_id, reason}}, state) do
    reply_command(command_id, {:error, reason}, state)
  end

  defp handle_native_event({:ok, {:peer_up, peer_id, metadata}}, state) when is_map(metadata) do
    send(state.event_target, {:ble_peer_up, peer_id, metadata})
    state
  end

  defp handle_native_event({:ok, {:peer_down, peer_id}}, state) do
    send(state.event_target, {:ble_peer_down, peer_id})
    state
  end

  defp handle_native_event({:ok, {:frame, peer_id, frame}}, state) when is_binary(frame) do
    send(state.event_target, {:ble_frame, peer_id, frame})
    state
  end

  defp handle_native_event(_event, state), do: state

  defp reply_command(command_id, reply, state) do
    case Map.pop(state.pending, command_id) do
      {nil, pending} ->
        %{state | pending: pending}

      {%{from: from, timer: timer}, pending} ->
        Process.cancel_timer(timer)
        GenServer.reply(from, reply)
        %{state | pending: pending}
    end
  end

  defp reply_pending(state, reply) do
    Enum.each(state.pending, fn {_command_id, %{from: from, timer: timer}} ->
      Process.cancel_timer(timer)
      GenServer.reply(from, reply)
    end)

    state
  end
end
