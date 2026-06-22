defmodule Mob.Runtime.GroupKeyManager do
  @moduledoc """
  Owns per-channel group (sender-key) state for the local node.

  Bridges the pure `Mob.Noise.GroupSession` ratchet to durable storage
  (`Mob.Store.GroupKeys`) and exposes the operations the chat path needs:

    * `ensure_channel/2` — enable encryption on a channel; returns this
      node's sender-key distribution (SKDM) to hand to peers.
    * `encrypt/3` — seal a channel message on the local sending chain.
    * `install_remote/4` — install a peer's sender key from an SKDM.
    * `decrypt/5` — open a channel message from a known sender.
    * `handle_control/2` — ingest a `Mob.Runtime.GroupKeyControl` message
      (a distribution to install, or a request to answer).

  ## Single-writer model

  All operations run through this one GenServer, so the load-modify-store
  of a ratchet step is serialized — no `get_and_update` gymnastics
  needed. State held in the process is only configuration; the source of
  truth is the store, so a crash/restart resumes from persisted chains.

  ## AAD binding

  Every message is sealed with associated data `channel_id <> sender_id`,
  binding the ciphertext to both its channel and its claimed sender. A
  blob can therefore not be replayed into another channel or
  re-attributed to a different sender without failing authentication.

  ## Security note (accepted MVP limitation)

  Sender keys are symmetric: a member holding another member's *received*
  chain could forge messages attributed to that sender. This matches the
  chosen "confidential to current key-holders" threat model. Per-message
  signatures (a versioned SKDM upgrade) would close it later.
  """

  use GenServer

  alias Mob.Noise.{GroupSession, SenderKey, SenderKeyDistribution}
  alias Mob.Runtime.GroupKeyControl

  @type channel :: binary()
  @type sender_id :: binary()

  # ── client API ────────────────────────────────────────────────────────────

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Enables encryption on `channel`, creating this node's sending chain if
  absent. Returns `{:ok, skdm}` where `skdm` is the distribution bytes to
  send to peers (over a secure pairwise channel).
  """
  @spec ensure_channel(GenServer.server(), channel()) :: {:ok, binary()}
  def ensure_channel(server \\ __MODULE__, channel),
    do: GenServer.call(server, {:ensure_channel, channel})

  @doc "Returns true if `channel` has encryption enabled locally."
  @spec encrypted?(GenServer.server(), channel()) :: boolean()
  def encrypted?(server \\ __MODULE__, channel),
    do: GenServer.call(server, {:encrypted?, channel})

  @doc """
  Seals `plaintext` for `channel`. Returns `{:ok, generation, blob}` or
  `{:error, reason}`. Requires `ensure_channel/2` first.
  """
  @spec encrypt(GenServer.server(), channel(), binary()) ::
          {:ok, non_neg_integer(), binary()} | {:error, term()}
  def encrypt(server \\ __MODULE__, channel, plaintext),
    do: GenServer.call(server, {:encrypt, channel, plaintext})

  @doc "Installs `sender_id`'s sender key on `channel` from raw SKDM bytes."
  @spec install_remote(GenServer.server(), channel(), sender_id(), binary()) ::
          :ok | {:error, term()}
  def install_remote(server \\ __MODULE__, channel, sender_id, skdm),
    do: GenServer.call(server, {:install_remote, channel, sender_id, skdm})

  @doc """
  Opens `blob` claimed to be from `sender_id` at `generation` on
  `channel`. Returns `{:ok, plaintext}` or `{:error, reason}` — notably
  `{:error, :no_sender}` when the sender's key has not been installed
  (the caller should request it).
  """
  @spec decrypt(GenServer.server(), channel(), sender_id(), non_neg_integer(), binary()) ::
          {:ok, binary()} | {:error, term()}
  def decrypt(server \\ __MODULE__, channel, sender_id, generation, blob),
    do: GenServer.call(server, {:decrypt, channel, sender_id, generation, blob})

  @doc """
  Handles an inbound `Mob.Runtime.GroupKeyControl` message decoded from a
  peer. For a `:distribution`, installs the sender key and returns `:ok`.
  For a `:request`, returns `{:reply, skdm}` with this node's SKDM for the
  channel when it has one (so the caller can send it back over the secure
  channel), or `:ok` when there is nothing to share.

  `from_sender_id` is the authenticated peer the control message came
  from — used as the receiving-chain key for a distribution.
  """
  @spec handle_control(GenServer.server(), {GroupKeyControl.t(), sender_id()}) ::
          :ok | {:reply, binary()} | {:error, term()}
  def handle_control(server \\ __MODULE__, {control, from_sender_id}),
    do: GenServer.call(server, {:handle_control, control, from_sender_id})

  # ── server ────────────────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    state = %{
      store: Keyword.get(opts, :store, Mob.Store.GroupKeys),
      # Resolved lazily on first use so the manager starts even before the
      # identity store is up; injectable in tests.
      local_sender_id: Keyword.get(opts, :local_sender_id),
      max_skip: Keyword.get(opts, :max_skip, 2_000)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:ensure_channel, channel}, _from, state) do
    session = load(state, channel)
    {session, skdm} = GroupSession.ensure_sending(session)
    store(state, channel, session)
    {:reply, {:ok, skdm}, state}
  end

  def handle_call({:encrypted?, channel}, _from, state) do
    encrypted? =
      case state.store.get(channel) do
        %GroupSession{sending: %SenderKey{}} -> true
        _ -> false
      end

    {:reply, encrypted?, state}
  end

  def handle_call({:encrypt, channel, plaintext}, _from, state) do
    {local_sender_id, state} = local_id(state)
    session = load(state, channel)
    {session, _skdm} = GroupSession.ensure_sending(session)

    case GroupSession.encrypt(session, plaintext, aad(channel, local_sender_id)) do
      {:ok, session, generation, blob} ->
        store(state, channel, session)
        {:reply, {:ok, generation, blob}, state}

      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  def handle_call({:install_remote, channel, sender_id, skdm}, _from, state) do
    {:reply, do_install(state, channel, sender_id, skdm), state}
  end

  def handle_call({:decrypt, channel, sender_id, generation, blob}, _from, state) do
    case state.store.get(channel) do
      nil ->
        {:reply, {:error, :no_sender}, state}

      %GroupSession{} = session ->
        aad = aad(channel, sender_id)

        case GroupSession.decrypt(session, sender_id, generation, blob, aad) do
          {:ok, session, plaintext} ->
            store(state, channel, session)
            {:reply, {:ok, plaintext}, state}

          {:error, _} = err ->
            {:reply, err, state}
        end
    end
  end

  def handle_call({:handle_control, {:distribution, channel, skdm}, from_sender_id}, _from, state) do
    {:reply, do_install(state, channel, from_sender_id, skdm), state}
  end

  def handle_call(
        {:handle_control, {:request, channel, sender_id}, _from_sender_id},
        _from,
        state
      ) do
    {local_sender_id, state} = local_id(state)

    reply =
      if sender_id == local_sender_id do
        case state.store.get(channel) do
          %GroupSession{sending: %SenderKey{} = sending} ->
            {:reply, SenderKeyDistribution.encode(sending)}

          _ ->
            :ok
        end
      else
        # A request for someone else's key; we are not the authority for it.
        :ok
      end

    {:reply, reply, state}
  end

  # ── helpers ─────────────────────────────────────────────────────────────────

  defp do_install(state, channel, sender_id, skdm) do
    with {:ok, decoded} <- SenderKeyDistribution.decode(skdm),
         session = load(state, channel),
         {:ok, session} <- GroupSession.install_sender_key(session, sender_id, decoded) do
      store(state, channel, session)
      :ok
    end
  end

  defp load(state, channel) do
    case state.store.get(channel) do
      %GroupSession{} = session -> session
      _ -> GroupSession.new(max_skip: state.max_skip)
    end
  end

  defp store(state, channel, session), do: state.store.put(channel, session)

  defp aad(channel, sender_id), do: channel <> sender_id

  # Local sender id is the raw 32-byte static public key — the same bytes
  # chat uses as `wire_peer_id` and the envelope's `sender_peer_id`.
  # Resolved once, then cached in state.
  defp local_id(%{local_sender_id: id} = state) when is_binary(id), do: {id, state}

  defp local_id(state) do
    {:ok, %{public_key: pk}} = Mob.Store.Identity.ensure_local()
    {pk, %{state | local_sender_id: pk}}
  end
end
