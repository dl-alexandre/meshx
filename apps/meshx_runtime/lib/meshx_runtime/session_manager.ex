defmodule MeshxRuntime.SessionManager do
  @moduledoc """
  Tracks per-peer Noise XX sessions for the runtime.

  Handshake bytes are intentionally transport-agnostic. The router wraps them in
  `:control` packets using the payload helpers in this module and delivers the
  resulting frames over whichever transport discovered the peer.
  """

  use GenServer

  alias MeshxNoise.{Session, Supervisor}
  alias MeshxRuntime.Telemetry
  alias MeshxStore.{Identity, Trust}

  @handshake_tag "MXN1"

  @type peer_id :: term()

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @doc "Encodes a Noise handshake message into a control-packet payload."
  @spec handshake_payload(iodata()) :: binary()
  def handshake_payload(message) do
    @handshake_tag <> IO.iodata_to_binary(message)
  end

  @doc "Decodes a Noise handshake control-packet payload."
  @spec decode_handshake_payload(binary()) :: {:ok, binary()} | :error
  def decode_handshake_payload(<<@handshake_tag, message::binary>>), do: {:ok, message}
  def decode_handshake_payload(_payload), do: :error

  @doc "Starts an initiator handshake if no session exists for the peer."
  @spec ensure_initiator(peer_id()) :: {:ok, binary() | :established} | {:error, term()}
  def ensure_initiator(peer_id) do
    GenServer.call(__MODULE__, {:ensure_initiator, peer_id})
  end

  @doc "Processes an inbound handshake message and optionally returns a reply."
  @spec handle_handshake(peer_id(), binary()) ::
          {:ok, binary() | nil, boolean()} | {:error, term()}
  def handle_handshake(peer_id, message) do
    GenServer.call(__MODULE__, {:handle_handshake, peer_id, message})
  end

  @spec established?(peer_id()) :: boolean()
  def established?(peer_id) do
    GenServer.call(__MODULE__, {:established, peer_id})
  end

  @doc "Returns the peer's remote static public key when a session has one."
  @spec remote_key(peer_id()) :: binary() | nil
  def remote_key(peer_id) do
    GenServer.call(__MODULE__, {:remote_key, peer_id})
  end

  @spec encrypt(peer_id(), binary(), iodata()) :: {:ok, binary()} | {:error, term()}
  def encrypt(peer_id, plaintext, aad \\ []) do
    GenServer.call(__MODULE__, {:encrypt, peer_id, plaintext, aad})
  end

  @spec decrypt(peer_id(), binary(), iodata()) :: {:ok, binary()} | {:error, term()}
  def decrypt(peer_id, ciphertext, aad \\ []) do
    GenServer.call(__MODULE__, {:decrypt, peer_id, ciphertext, aad})
  end

  @doc """
  Tears down the Noise session for a peer, if any.

  Call on transport peer_down so that a subsequent reconnect renegotiates a
  fresh session instead of reusing one whose cipher state will desync.
  """
  @spec drop(peer_id()) :: :ok
  def drop(peer_id) do
    GenServer.call(__MODULE__, {:drop, peer_id})
  end

  @doc false
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:ensure_initiator, peer_id}, _from, state) do
    case Map.get(state, peer_id) do
      nil ->
        case start_session(:initiator) do
          {:ok, session} ->
            case Session.handshake_send(session) do
              {:ok, msg} ->
                Telemetry.execute([:noise, :handshake, :started], %{count: 1}, %{
                  peer_id: peer_id,
                  role: :initiator
                })

                state = Map.put(state, peer_id, %{pid: session, role: :initiator})
                {:reply, {:ok, IO.iodata_to_binary(msg)}, state}

              {:error, reason} ->
                Telemetry.execute([:noise, :handshake, :error], %{count: 1}, %{
                  peer_id: peer_id,
                  reason: reason
                })

                {:reply, {:error, reason}, state}
            end

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      %{pid: session} ->
        if Session.established?(session) do
          {:reply, {:ok, :established}, state}
        else
          {:reply, {:error, :handshake_in_progress}, state}
        end
    end
  end

  def handle_call({:handle_handshake, peer_id, msg}, _from, state) do
    with {:ok, session_entry, state} <- ensure_responder_session(peer_id, state),
         {:ok, reply, established?} <- advance_handshake(session_entry, msg),
         :ok <- maybe_authorize_peer(peer_id, session_entry, established?) do
      if established? do
        Telemetry.execute([:noise, :handshake, :established], %{count: 1}, %{
          peer_id: peer_id,
          role: session_entry.role
        })
      end

      {:reply, {:ok, reply, established?}, Map.put(state, peer_id, session_entry)}
    else
      {:error, reason} ->
        Telemetry.execute([:noise, :handshake, :error], %{count: 1}, %{
          peer_id: peer_id,
          reason: reason
        })

        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:established, peer_id}, _from, state) do
    established? =
      case Map.get(state, peer_id) do
        nil -> false
        %{pid: session} -> Session.established?(session)
      end

    {:reply, established?, state}
  end

  def handle_call({:remote_key, peer_id}, _from, state) do
    remote_key =
      case Map.get(state, peer_id) do
        nil -> nil
        %{pid: session} -> Session.remote_key(session)
      end

    {:reply, remote_key, state}
  end

  def handle_call({:encrypt, peer_id, plaintext, aad}, _from, state) do
    result =
      with {:ok, session} <- fetch_established_session(state, peer_id),
           {:ok, ciphertext} <- Session.encrypt(session, plaintext, aad) do
        {:ok, IO.iodata_to_binary(ciphertext)}
      end

    {:reply, result, state}
  end

  def handle_call({:decrypt, peer_id, ciphertext, aad}, _from, state) do
    result =
      with {:ok, session} <- fetch_established_session(state, peer_id),
           {:ok, plaintext} <- Session.decrypt(session, ciphertext, aad) do
        {:ok, IO.iodata_to_binary(plaintext)}
      end

    {:reply, result, state}
  end

  def handle_call({:drop, peer_id}, _from, state) do
    case Map.pop(state, peer_id) do
      {nil, state} ->
        {:reply, :ok, state}

      {%{pid: session, role: role}, state} ->
        Session.close(session)
        Supervisor.terminate_session(session)

        Telemetry.execute([:noise, :session, :dropped], %{count: 1}, %{
          peer_id: peer_id,
          role: role
        })

        {:reply, :ok, state}
    end
  end

  def handle_call(:reset, _from, state) do
    state
    |> Map.values()
    |> Enum.each(fn %{pid: pid} ->
      Session.close(pid)
      Supervisor.terminate_session(pid)
    end)

    {:reply, :ok, %{}}
  end

  defp ensure_responder_session(peer_id, state) do
    case Map.get(state, peer_id) do
      nil ->
        with {:ok, session} <- start_session(:responder) do
          {:ok, %{pid: session, role: :responder}, state}
        end

      session_entry ->
        {:ok, session_entry, state}
    end
  end

  defp advance_handshake(%{pid: session, role: :initiator}, msg) do
    with :ok <- Session.handshake_recv(session, msg),
         {:ok, reply} <- Session.handshake_send(session) do
      {:ok, IO.iodata_to_binary(reply), Session.established?(session)}
    end
  end

  defp advance_handshake(%{pid: session, role: :responder}, msg) do
    with :ok <- Session.handshake_recv(session, msg) do
      if Session.established?(session) do
        {:ok, nil, true}
      else
        with {:ok, reply} <- Session.handshake_send(session) do
          {:ok, IO.iodata_to_binary(reply), Session.established?(session)}
        end
      end
    end
  end

  defp fetch_established_session(state, peer_id) do
    case Map.get(state, peer_id) do
      nil ->
        {:error, :session_not_found}

      %{pid: session} ->
        if Session.established?(session),
          do: {:ok, session},
          else: {:error, :session_not_established}
    end
  end

  defp start_session(role) do
    with {:ok, keys} <- Identity.static_keys(),
         {:ok, session} <- Supervisor.start_session(role: role, keys: keys) do
      Telemetry.execute([:noise, :session, :started], %{count: 1}, %{role: role})
      {:ok, session}
    end
  end

  defp maybe_authorize_peer(_peer_id, _session_entry, false), do: :ok

  defp maybe_authorize_peer(peer_id, %{pid: session}, true) do
    case Session.remote_key(session) do
      nil -> {:error, :remote_key_unavailable}
      public_key -> Trust.authorize(peer_id, public_key)
    end
  end
end
