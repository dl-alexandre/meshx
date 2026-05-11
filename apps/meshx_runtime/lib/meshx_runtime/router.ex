defmodule MeshxRuntime.Router do
  @moduledoc """
  Runtime message router.

  The router receives normalized transport events, decodes MeshX protocol
  frames, suppresses duplicates, stores relay candidates, emits local delivery
  events, and re-broadcasts packets while TTL remains.
  """

  use GenServer

  alias MeshxProtocol.{Ack, Codec, Fragment, Packet}

  alias MeshxRuntime.{
    FlowControl,
    FragmentBuffer,
    Outbox,
    PeerRegistry,
    SessionManager,
    Telemetry
  }

  alias MeshxStore.{Dedupe, RelayCache}
  alias MeshxStore.Outbox, as: StoreOutbox
  alias MeshxTransport.Capabilities

  @type transport_entry :: %{adapter: module(), pid: pid()}

  @fragment_frame_overhead 18

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @spec attach_transport(atom(), module(), pid()) :: :ok
  def attach_transport(name, adapter, pid) do
    GenServer.call(__MODULE__, {:attach_transport, name, adapter, pid})
  end

  @spec detach_transport(atom()) :: :ok
  def detach_transport(name) do
    GenServer.call(__MODULE__, {:detach_transport, name})
  end

  @spec subscribe(pid()) :: :ok
  def subscribe(pid \\ self()) do
    GenServer.call(__MODULE__, {:subscribe, pid})
  end

  @spec unsubscribe(pid()) :: :ok
  def unsubscribe(pid \\ self()) do
    GenServer.call(__MODULE__, {:unsubscribe, pid})
  end

  @spec send_packet(term(), Packet.t(), keyword()) :: :ok | {:error, term()}
  def send_packet(peer_id, %Packet{} = packet, opts \\ []) do
    GenServer.call(__MODULE__, {:send_packet, peer_id, packet, opts})
  end

  @spec ensure_secure_session(term(), keyword()) :: :ok | {:error, term()}
  def ensure_secure_session(peer_id, opts \\ []) do
    GenServer.call(__MODULE__, {:ensure_secure_session, peer_id, opts})
  end

  @spec broadcast_packet(Packet.t(), keyword()) :: :ok | {:error, term()}
  def broadcast_packet(%Packet{} = packet, opts \\ []) do
    GenServer.call(__MODULE__, {:broadcast_packet, packet, opts})
  end

  @doc false
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def init(_opts) do
    {:ok, new_state()}
  end

  @impl true
  def handle_call({:attach_transport, name, adapter, pid}, _from, state) do
    transports = Map.put(state.transports, name, %{adapter: adapter, pid: pid})
    {:reply, :ok, %{state | transports: transports}}
  end

  def handle_call({:detach_transport, name}, _from, state) do
    {:reply, :ok, %{state | transports: Map.delete(state.transports, name)}}
  end

  def handle_call({:subscribe, pid}, _from, state) do
    {:reply, :ok, %{state | subscribers: MapSet.put(state.subscribers, pid)}}
  end

  def handle_call({:unsubscribe, pid}, _from, state) do
    {:reply, :ok, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  def handle_call({:send_packet, peer_id, packet, opts}, _from, state) do
    {reply, state} = send_packet_with_flow(peer_id, packet, opts, state)
    {:reply, reply, state}
  end

  def handle_call({:ensure_secure_session, peer_id, opts}, _from, state) do
    result = start_secure_handshake(peer_id, opts, state)
    {:reply, result, state}
  end

  def handle_call({:broadcast_packet, packet, opts}, _from, state) do
    Dedupe.record(packet.msg_id)
    RelayCache.add(packet.msg_id, packet.payload, 0)
    {:reply, broadcast(packet, opts, state), state}
  end

  def handle_call(:reset, _from, state) do
    {:reply, :ok, %{new_state() | subscribers: state.subscribers}}
  end

  @impl true
  def handle_info({:meshx_transport, transport, {:peer_up, peer}}, state) do
    :ok = PeerRegistry.up(peer)

    Telemetry.execute([:router, :peer, :up], %{count: 1}, %{
      transport: transport,
      peer_id: peer.id
    })

    notify(state, {:meshx_runtime, :peer_up, transport, peer})
    {:noreply, state}
  end

  def handle_info({:meshx_transport, transport, {:peer_down, peer_id}}, state) do
    :ok = PeerRegistry.down(peer_id)
    :ok = SessionManager.drop(peer_id)

    Telemetry.execute([:router, :peer, :down], %{count: 1}, %{
      transport: transport,
      peer_id: peer_id
    })

    notify(state, {:meshx_runtime, :peer_down, transport, peer_id})
    {:noreply, state}
  end

  def handle_info({:meshx_discovery, {:peer_up, peer}}, state) do
    :ok = PeerRegistry.up(peer)

    Telemetry.execute([:router, :peer, :discovered], %{count: 1}, %{
      transport: peer.transport,
      peer_id: peer.id
    })

    notify(state, {:meshx_runtime, :peer_up, :discovery, peer})
    {:noreply, state}
  end

  def handle_info({:meshx_transport, transport, {:frame, peer_id, frame}}, state) do
    state = handle_frame(transport, peer_id, frame, state)
    {:noreply, state}
  end

  defp handle_frame(transport, peer_id, frame, state) do
    case Codec.decode_packet(frame) do
      {:ok, packet, _rest} ->
        handle_packet(transport, peer_id, packet, state)

      {:error, reason} ->
        Telemetry.execute([:router, :frame, :decode_error], %{count: 1}, %{
          transport: transport,
          peer_id: peer_id,
          reason: reason
        })

        notify(state, {:meshx_runtime, :decode_error, transport, peer_id, reason})
        state
    end
  end

  defp handle_packet(transport, peer_id, packet, state) do
    handle_packet(transport, peer_id, packet, state, true)
  end

  defp handle_packet(transport, peer_id, packet, state, relay?) do
    case maybe_handle_fragment_packet(transport, peer_id, packet, state, relay?) do
      :not_fragment -> handle_non_fragment_packet(transport, peer_id, packet, state, relay?)
      :ok -> state
      {:state, state} -> state
    end
  end

  defp handle_non_fragment_packet(transport, peer_id, packet, state, relay?) do
    case maybe_handle_ack_packet(transport, peer_id, packet, state) do
      :not_ack ->
        maybe_handle_control_or_application_packet(transport, peer_id, packet, state, relay?)

      {:state, state} ->
        state
    end
  end

  defp maybe_handle_control_or_application_packet(transport, peer_id, packet, state, relay?) do
    case maybe_handle_control_packet(transport, peer_id, packet, state) do
      :not_control -> handle_application_packet(transport, peer_id, packet, state, relay?)
      :ok -> state
    end
  end

  defp handle_application_packet(transport, peer_id, packet, state, relay?) do
    relay? = relay? and relayable_packet?(packet)

    with {:ok, packet} <- maybe_decrypt_packet(peer_id, packet) do
      route_application_packet(transport, peer_id, packet, state, relay?)
    else
      {:error, reason} ->
        Telemetry.execute([:router, :packet, :decrypt_error], %{count: 1}, %{
          transport: transport,
          peer_id: peer_id,
          reason: reason
        })

        notify(state, {:meshx_runtime, :decrypt_error, transport, peer_id, reason})
        state
    end
  end

  defp route_application_packet(transport, peer_id, packet, state, relay?) do
    maybe_send_ack(transport, peer_id, packet, state)

    if Dedupe.record?(packet.msg_id) do
      Telemetry.execute([:router, :packet, :duplicate], %{count: 1}, %{
        transport: transport,
        peer_id: peer_id,
        msg_id: packet.msg_id
      })

      notify(state, {:meshx_runtime, :duplicate, transport, peer_id, packet.msg_id})
      state
    else
      RelayCache.add(packet.msg_id, packet.payload, 0)

      Telemetry.execute(
        [:router, :packet, :delivered],
        %{count: 1, bytes: byte_size(packet.payload)},
        %{
          transport: transport,
          peer_id: peer_id,
          msg_id: packet.msg_id,
          type: packet.type
        }
      )

      notify(state, {:meshx_runtime, :packet, transport, peer_id, packet})
      if relay?, do: relay_packet(peer_id, packet, state)
      state
    end
  end

  defp maybe_handle_ack_packet(transport, peer_id, %Packet{type: :ack} = packet, state) do
    case Ack.decode(packet) do
      {:ok, acked_msg_id} ->
        result = StoreOutbox.ack(acked_msg_id, peer_id)

        Telemetry.execute([:router, :ack, :received], %{count: 1}, %{
          transport: transport,
          peer_id: peer_id,
          msg_id: acked_msg_id,
          result: result
        })

        notify(state, {:meshx_runtime, :ack, transport, peer_id, acked_msg_id, result})
        {:state, release_flow(peer_id, acked_msg_id, state)}

      {:error, reason} ->
        Telemetry.execute([:router, :ack, :error], %{count: 1}, %{
          transport: transport,
          peer_id: peer_id,
          reason: reason
        })

        notify(state, {:meshx_runtime, :ack_error, transport, peer_id, reason})
        {:state, state}
    end
  end

  defp maybe_handle_ack_packet(_transport, _peer_id, _packet, _state), do: :not_ack

  defp maybe_handle_fragment_packet(
         transport,
         peer_id,
         %Packet{type: :fragment} = packet,
         state,
         relay?
       ) do
    if relay? and relayable_packet?(packet), do: relay_packet(peer_id, packet, state)

    case FragmentBuffer.add(packet) do
      {:complete, original_id, frame} ->
        Telemetry.execute([:router, :fragment, :complete], %{count: 1}, %{
          transport: transport,
          peer_id: peer_id,
          msg_id: original_id
        })

        notify(state, {:meshx_runtime, :fragments_complete, transport, peer_id, original_id})

        case Codec.decode_packet(frame) do
          {:ok, reassembled, _rest} ->
            {:state, handle_packet(transport, peer_id, reassembled, state, false)}

          {:error, reason} ->
            Telemetry.execute([:router, :frame, :decode_error], %{count: 1}, %{
              transport: transport,
              peer_id: peer_id,
              reason: reason
            })

            notify(state, {:meshx_runtime, :decode_error, transport, peer_id, reason})
            :ok
        end

      {:partial, received, total} ->
        Telemetry.execute([:router, :fragment, :partial], %{received: received, total: total}, %{
          transport: transport,
          peer_id: peer_id,
          msg_id: packet.msg_id
        })

        notify(
          state,
          {:meshx_runtime, :fragment, transport, peer_id, packet.msg_id, received, total}
        )

        :ok

      {:error, reason} ->
        Telemetry.execute([:router, :fragment, :error], %{count: 1}, %{
          transport: transport,
          peer_id: peer_id,
          reason: reason
        })

        notify(state, {:meshx_runtime, :fragment_error, transport, peer_id, reason})
        :ok
    end
  end

  defp maybe_handle_fragment_packet(_transport, _peer_id, _packet, _state, _relay?),
    do: :not_fragment

  defp maybe_handle_control_packet(
         transport,
         peer_id,
         %Packet{type: :control, payload: payload},
         state
       ) do
    case SessionManager.decode_handshake_payload(payload) do
      {:ok, handshake_msg} ->
        handle_noise_handshake(transport, peer_id, handshake_msg, state)

      :error ->
        :not_control
    end
  end

  defp maybe_handle_control_packet(_transport, _peer_id, _packet, _state), do: :not_control

  defp handle_noise_handshake(transport, peer_id, handshake_msg, state) do
    case SessionManager.handle_handshake(peer_id, handshake_msg) do
      {:ok, reply, established?} ->
        if reply do
          packet = control_packet(SessionManager.handshake_payload(reply))
          send_plain_packet_to_peer(peer_id, packet, [transport: transport], state, false)
        end

        if established? do
          Telemetry.execute([:router, :noise, :established], %{count: 1}, %{
            transport: transport,
            peer_id: peer_id
          })

          notify(state, {:meshx_runtime, :noise_established, transport, peer_id})
        end

        :ok

      {:error, reason} ->
        Telemetry.execute([:router, :noise, :error], %{count: 1}, %{
          transport: transport,
          peer_id: peer_id,
          reason: reason
        })

        notify(state, {:meshx_runtime, :noise_error, transport, peer_id, reason})
        :ok
    end
  end

  defp maybe_decrypt_packet(peer_id, %Packet{flags: flags, payload: ciphertext} = packet) do
    if Packet.flag_set?(flags, Packet.flag_encrypted()) do
      with {:ok, plaintext} <- SessionManager.decrypt(peer_id, ciphertext) do
        {:ok,
         %{packet | flags: Packet.clear_flag(flags, Packet.flag_encrypted()), payload: plaintext}}
      end
    else
      {:ok, packet}
    end
  end

  defp maybe_send_ack(transport, peer_id, %Packet{flags: flags, msg_id: msg_id}, state) do
    if Packet.flag_set?(flags, Packet.flag_ack_requested()) do
      ack = Ack.packet(msg_id)
      send_plain_packet_to_peer(peer_id, ack, [transport: transport], state, false)
    end
  end

  defp relay_packet(origin_peer_id, %Packet{ttl: ttl} = packet, state) when ttl > 1 do
    relayed = %{packet | ttl: ttl - 1}
    relay_broadcast(relayed, origin_peer_id, state)
  end

  defp relay_packet(_origin_peer_id, _packet, _state), do: :ok

  defp relay_broadcast(packet, origin_peer_id, state) do
    PeerRegistry.list()
    |> Enum.reject(&(&1.id == origin_peer_id))
    |> Enum.filter(&relay_peer?/1)
    |> Enum.each(fn peer ->
      send_plain_packet_to_peer(peer.id, packet, [transport: peer.transport], state, false)
    end)

    :ok
  end

  defp relayable_packet?(%Packet{type: type, flags: flags})
       when type in [:data, :gossip, :fragment] do
    not Packet.flag_set?(flags, Packet.flag_encrypted())
  end

  defp relayable_packet?(_packet), do: false

  defp relay_peer?(%{metadata: metadata}) do
    metadata
    |> Capabilities.from_metadata()
    |> Map.get(:relay?)
  end

  defp send_packet_to_peer(peer_id, packet, opts, state) do
    with {:ok, packet} <- maybe_encrypt_packet(peer_id, packet, opts) do
      send_plain_packet_to_peer(peer_id, packet, opts, state, true)
    end
  end

  defp send_packet_with_flow(peer_id, packet, opts, state) do
    case FlowControl.reserve(state.flow, peer_id, packet, opts) do
      {:untracked, flow} ->
        result = send_packet_to_peer(peer_id, packet, opts, state)
        {maybe_queue_delivery(peer_id, packet, opts, result), %{state | flow: flow}}

      {:send, flow} ->
        result = send_packet_to_peer(peer_id, packet, opts, state)
        flow = release_on_send_failure(flow, peer_id, packet, result)
        {maybe_queue_delivery(peer_id, packet, opts, result), %{state | flow: flow}}

      {:queued, depth, flow} ->
        Telemetry.execute([:router, :backpressure, :queued], %{depth: depth}, %{
          peer_id: peer_id,
          msg_id: packet.msg_id
        })

        {{:queued, :backpressure, depth}, %{state | flow: flow}}

      {:error, :queue_full, flow} ->
        Telemetry.execute([:router, :backpressure, :dropped], %{count: 1}, %{
          peer_id: peer_id,
          msg_id: packet.msg_id,
          reason: :queue_full
        })

        {{:error, :backpressure_queue_full}, %{state | flow: flow}}
    end
  end

  defp maybe_queue_delivery(_peer_id, _packet, _opts, :ok), do: :ok

  defp maybe_queue_delivery(_peer_id, _packet, _opts, {:error, :secure_required}),
    do: {:error, :secure_required}

  defp maybe_queue_delivery(peer_id, packet, opts, {:error, reason}) do
    if Keyword.get(opts, :store, false) and not Keyword.get(opts, :secure, false) do
      case Outbox.enqueue(peer_id, packet, opts) do
        {:ok, record} -> {:queued, reason, record}
        {:error, enqueue_reason} -> {:error, {reason, enqueue_reason}}
      end
    else
      {:error, reason}
    end
  end

  defp maybe_queue_delivery(_peer_id, _packet, _opts, result), do: result

  defp release_flow(peer_id, msg_id, state) do
    {flow, next} = FlowControl.release(state.flow, peer_id, msg_id)
    state = %{state | flow: flow}

    case next do
      nil -> state
      {packet, opts} -> send_dequeued_packet(peer_id, packet, opts, state)
    end
  end

  defp send_dequeued_packet(peer_id, packet, opts, state) do
    opts = Keyword.put(opts, :flow_control, false)
    result = send_packet_to_peer(peer_id, packet, opts, state)

    Telemetry.execute([:router, :backpressure, :dequeued], %{count: 1}, %{
      peer_id: peer_id,
      msg_id: packet.msg_id,
      result: result
    })

    %{state | flow: release_on_send_failure(state.flow, peer_id, packet, result)}
  end

  defp release_on_send_failure(flow, _peer_id, _packet, :ok), do: flow

  defp release_on_send_failure(flow, peer_id, packet, _result) do
    {flow, _next} = FlowControl.release(flow, peer_id, packet.msg_id)
    flow
  end

  defp send_plain_packet_to_peer(peer_id, packet, opts, state, record?) do
    with {:ok, frames} <- encode_frames(packet, peer_id, opts),
         {:ok, %{adapter: adapter, pid: transport_pid}} <-
           transport_for_peer(peer_id, opts, state) do
      if record? do
        Dedupe.record(packet.msg_id)
        RelayCache.add(packet.msg_id, packet.payload, 0)
      end

      send_frames(adapter, transport_pid, peer_id, frames, opts)
    end
  end

  defp maybe_encrypt_packet(peer_id, packet, opts) do
    secure? = Keyword.get(opts, :secure, false)

    cond do
      peer_secure_required?(peer_id) and not secure? ->
        {:error, :secure_required}

      secure? ->
        if SessionManager.established?(peer_id) do
          with {:ok, ciphertext} <- SessionManager.encrypt(peer_id, packet.payload) do
            flags = Packet.set_flag(packet.flags, Packet.flag_encrypted())
            {:ok, %{packet | flags: flags, payload: ciphertext}}
          end
        else
          {:error, :session_not_established}
        end

      true ->
        {:ok, packet}
    end
  end

  defp start_secure_handshake(peer_id, opts, state) do
    case SessionManager.ensure_initiator(peer_id) do
      {:ok, :established} ->
        :ok

      {:ok, handshake_msg} ->
        packet = control_packet(SessionManager.handshake_payload(handshake_msg))
        send_plain_packet_to_peer(peer_id, packet, opts, state, false)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp broadcast(packet, opts, state) do
    case encode_frames(packet, nil, opts) do
      {:ok, frames} ->
        results =
          Enum.map(state.transports, fn {_name, %{adapter: adapter, pid: pid}} ->
            broadcast_frames(adapter, pid, frames, opts)
          end)

        if Enum.all?(results, &(&1 == :ok)), do: :ok, else: {:error, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp encode_frames(packet, peer_id, opts) do
    with {:ok, frame} <- Codec.encode_packet(packet) do
      case mtu_for(peer_id, opts) do
        mtu when is_integer(mtu) and mtu > 0 and byte_size(frame) > mtu ->
          fragment_frame(packet, frame, mtu)

        _ ->
          {:ok, [frame]}
      end
    end
  end

  defp fragment_frame(packet, frame, mtu) do
    max_chunk_size = mtu - @fragment_frame_overhead

    cond do
      max_chunk_size <= 0 ->
        {:error, :mtu_too_small}

      fragment_count(byte_size(frame), max_chunk_size) > 255 ->
        {:error, :too_many_fragments}

      true ->
        packet.msg_id
        |> Fragment.fragment(frame,
          max_chunk_size: max_chunk_size,
          ttl: packet.ttl,
          flags: packet.flags
        )
        |> Enum.reduce_while({:ok, []}, fn fragment, {:ok, acc} ->
          case Codec.encode_packet(fragment) do
            {:ok, frame} -> {:cont, {:ok, [frame | acc]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)
        |> case do
          {:ok, frames} -> {:ok, Enum.reverse(frames)}
          error -> error
        end
    end
  end

  defp send_frames(adapter, transport_pid, peer_id, frames, opts) do
    frame_count = length(frames)
    bytes = Enum.reduce(frames, 0, fn frame, acc -> acc + byte_size(frame) end)

    Telemetry.execute([:router, :send, :start], %{frames: frame_count, bytes: bytes}, %{
      peer_id: peer_id
    })

    result =
      Enum.reduce_while(frames, :ok, fn frame, :ok ->
        case adapter.send_frame(transport_pid, peer_id, frame, opts) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)

    emit_send_result(result, peer_id, %{frames: frame_count, bytes: bytes})
    result
  end

  defp broadcast_frames(adapter, transport_pid, frames, opts) do
    result =
      Enum.reduce_while(frames, :ok, fn frame, :ok ->
        case adapter.broadcast_frame(transport_pid, frame, opts) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)

    emit_send_result(result, :broadcast, %{frames: length(frames)})
    result
  end

  defp mtu_for(peer_id, opts) do
    Keyword.get(opts, :mtu) || peer_mtu(peer_id)
  end

  defp peer_mtu(nil), do: nil

  defp peer_mtu(peer_id) do
    case PeerRegistry.capabilities(peer_id) do
      %{mtu: mtu} -> mtu
      nil -> nil
    end
  end

  defp peer_secure_required?(peer_id) do
    case PeerRegistry.capabilities(peer_id) do
      %{secure_required?: required?} -> required?
      nil -> false
    end
  end

  defp fragment_count(size, chunk_size) do
    div(size + chunk_size - 1, chunk_size)
  end

  defp transport_for_peer(peer_id, opts, state) do
    case Keyword.get(opts, :transport) do
      nil ->
        lookup_peer_transport(peer_id, state)

      transport_name when is_atom(transport_name) ->
        case Map.fetch(state.transports, transport_name) do
          {:ok, entry} -> {:ok, entry}
          :error -> {:error, :transport_not_attached}
        end

      _ ->
        lookup_peer_transport(peer_id, state)
    end
  end

  defp lookup_peer_transport(peer_id, state) do
    with %{transport: transport_name} <- PeerRegistry.get(peer_id),
         {:ok, entry} <- Map.fetch(state.transports, transport_name) do
      {:ok, entry}
    else
      nil -> {:error, :unknown_peer}
      :error -> {:error, :transport_not_attached}
    end
  end

  defp notify(state, message) do
    Enum.each(state.subscribers, &send(&1, message))
  end

  defp emit_send_result(:ok, peer_id, measurements) do
    Telemetry.execute([:router, :send, :stop], measurements, %{peer_id: peer_id})
  end

  defp emit_send_result({:error, reason}, peer_id, measurements) do
    Telemetry.execute([:router, :send, :error], Map.put(measurements, :count, 1), %{
      peer_id: peer_id,
      reason: reason
    })
  end

  defp control_packet(payload) do
    Packet.new(:control, System.unique_integer([:positive]) |> rem(4_000_000_000), payload)
  end

  defp new_state do
    %{
      transports: %{},
      subscribers: MapSet.new(),
      flow: FlowControl.new(Application.get_env(:meshx_runtime, :flow_control, []))
    }
  end
end
