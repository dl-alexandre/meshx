defmodule MeshxNoise.Session do
  @moduledoc """
  GenServer wrapper around a Decibel Noise Protocol session.

  Each session runs in its own process so that Decibel's `Process.put/get`
  state is isolated. The module exposes a simple state-machine API:

    * `start_link/1` — create a new initiator or responder session.
    * `handshake_send/1` — produce the next outbound handshake message.
    * `handshake_recv/2` — process an inbound handshake message.
    * `established?/1` — check whether the handshake is complete.
    * `encrypt/3` — encrypt transport data (requires established session).
    * `decrypt/3` — decrypt transport data (requires established session).

  ## Example

      # Initiator
      {:ok, pid} = MeshxNoise.Session.start_link(role: :initiator)
      {:ok, msg1} = MeshxNoise.Session.handshake_send(pid)
      # …send msg1 to responder, receive msg2…
      :ok = MeshxNoise.Session.handshake_recv(pid, msg2)
      {:ok, msg3} = MeshxNoise.Session.handshake_send(pid)
      # …send msg3 to responder…
      true = MeshxNoise.Session.established?(pid)
      {:ok, ciphertext} = MeshxNoise.Session.encrypt(pid, "hello")

      # Responder
      {:ok, pid} = MeshxNoise.Session.start_link(role: :responder)
      :ok = MeshxNoise.Session.handshake_recv(pid, msg1)
      {:ok, msg2} = MeshxNoise.Session.handshake_send(pid)
      :ok = MeshxNoise.Session.handshake_recv(pid, msg3)
      true = MeshxNoise.Session.established?(pid)
      {:ok, plaintext} = MeshxNoise.Session.decrypt(pid, ciphertext)
  """

  use GenServer

  require Logger

  @default_protocol "Noise_XX_25519_ChaChaPoly_BLAKE2s"

  # --- Client API ---

  @doc """
  Starts a new Noise session.

  ## Options

    * `:role` — `:initiator` or `:responder` (required).
    * `:protocol` — protocol name string (default: `#{@default_protocol}`).
    * `:keys` — map of pre-message keys passed to `Decibel.new/4`.
    * `:opts` — extra options passed to `Decibel.new/4`.
    * `:auto_generate_static` — boolean. When `true` and `:keys` does not
      already contain `:s`, an ephemeral X25519 static keypair is
      generated and added before passing `:keys` to Decibel. Default:
      `true` when `:protocol` is the default
      `#{@default_protocol}` (ergonomic for tests and doc examples),
      `false` otherwise. Production callers should pass `:keys` from a
      durable identity (e.g. `MeshxStore.Identity.static_keys/0`); the
      auto-generation path produces a fresh per-session identity which
      is rarely what you want.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Produces the next outbound handshake message.

  Returns `{:ok, message}` or `{:error, :handshake_complete}` if the handshake
  is already finished.
  """
  @spec handshake_send(pid()) :: {:ok, iodata()} | {:error, atom()}
  def handshake_send(pid) do
    GenServer.call(pid, :handshake_send)
  end

  @doc """
  Processes an inbound handshake message.

  Returns `:ok` or `{:error, reason}` on decryption failure.
  """
  @spec handshake_recv(pid(), iodata()) :: :ok | {:error, atom() | String.t()}
  def handshake_recv(pid, message) do
    GenServer.call(pid, {:handshake_recv, message})
  end

  @doc "Returns `true` if the secure channel is established."
  @spec established?(pid()) :: boolean()
  def established?(pid) do
    GenServer.call(pid, :established)
  end

  @doc """
  Encrypts plaintext using the established session.

  Returns `{:ok, ciphertext}` or `{:error, :not_established}`.
  Optional `aad` provides associated authenticated data.
  """
  @spec encrypt(pid(), iodata(), iodata()) :: {:ok, iodata()} | {:error, atom()}
  def encrypt(pid, plaintext, aad \\ []) do
    GenServer.call(pid, {:encrypt, plaintext, aad})
  end

  @doc """
  Decrypts ciphertext using the established session.

  Returns `{:ok, plaintext}` or `{:error, reason}`.
  Optional `aad` provides associated authenticated data.
  """
  @spec decrypt(pid(), iodata(), iodata()) :: {:ok, iodata()} | {:error, atom() | String.t()}
  def decrypt(pid, ciphertext, aad \\ []) do
    GenServer.call(pid, {:decrypt, ciphertext, aad})
  end

  @doc """
  Returns the 32-byte handshake hash for channel-binding, or `nil` if the
  handshake is incomplete.
  """
  @spec handshake_hash(pid()) :: binary() | nil
  def handshake_hash(pid) do
    GenServer.call(pid, :handshake_hash)
  end

  @doc """
  Returns the remote static public key if available, `nil` otherwise.
  """
  @spec remote_key(pid()) :: binary() | nil
  def remote_key(pid) do
    GenServer.call(pid, :remote_key)
  end

  @doc "Closes the session and frees Decibel resources."
  @spec close(pid()) :: :ok
  def close(pid) do
    GenServer.call(pid, :close)
  end

  # --- Server callbacks ---

  @impl true
  def init(opts) do
    role = Keyword.fetch!(opts, :role)
    protocol = Keyword.get(opts, :protocol, @default_protocol)
    keys = Keyword.get(opts, :keys, %{})
    decibel_opts = Keyword.get(opts, :opts, [])
    auto_generate_static = Keyword.get(opts, :auto_generate_static, protocol == @default_protocol)

    decibel_role =
      case role do
        :initiator -> :ini
        :responder -> :rsp
      end

    keys =
      if auto_generate_static and not Map.has_key?(keys, :s) do
        {pub, priv} = :crypto.generate_key(:ecdh, :x25519)
        Map.put(keys, :s, {pub, priv})
      else
        keys
      end

    ref = Decibel.new(protocol, decibel_role, keys, decibel_opts)
    state = %{ref: ref, role: role, protocol: protocol}
    {:ok, state}
  end

  @impl true
  def handle_call(:handshake_send, _from, %{ref: ref} = state) do
    if Decibel.is_handshake_complete?(ref) do
      {:reply, {:error, :handshake_complete}, state}
    else
      msg = Decibel.handshake_encrypt(ref)
      {:reply, {:ok, msg}, state}
    end
  end

  def handle_call({:handshake_recv, msg}, _from, %{ref: ref} = state) do
    try do
      Decibel.handshake_decrypt(ref, msg)
      {:reply, :ok, state}
    rescue
      e in Decibel.DecryptionError ->
        Logger.warning("Noise handshake decrypt failed: #{inspect(e)}")
        {:reply, {:error, :decryption_failed}, state}

      e in MatchError ->
        # Decibel raises MatchError from Handshake.read_step/2 when the
        # input bytes don't have the shape its handshake state machine
        # expects (e.g. truncated / corrupted handshake messages). This
        # is an API quirk — Decibel uses pattern matching as its parser,
        # so malformed input surfaces as MatchError rather than a typed
        # error. Mapping it to :decryption_failed keeps the wrapper's
        # contract that handshake_recv never crashes the GenServer.
        Logger.warning("Noise handshake decode failed (malformed input): #{inspect(e)}")
        {:reply, {:error, :decryption_failed}, state}
    end
  end

  def handle_call(:established, _from, %{ref: ref} = state) do
    {:reply, Decibel.is_handshake_complete?(ref), state}
  end

  def handle_call({:encrypt, plaintext, aad}, _from, %{ref: ref} = state) do
    if Decibel.is_handshake_complete?(ref) do
      ciphertext = Decibel.encrypt(ref, plaintext, aad)
      {:reply, {:ok, ciphertext}, state}
    else
      {:reply, {:error, :not_established}, state}
    end
  end

  def handle_call({:decrypt, ciphertext, aad}, _from, %{ref: ref} = state) do
    if Decibel.is_handshake_complete?(ref) do
      try do
        plaintext = Decibel.decrypt(ref, ciphertext, aad)
        {:reply, {:ok, plaintext}, state}
      rescue
        e in Decibel.DecryptionError ->
          Logger.warning("Noise decrypt failed: #{inspect(e)}")
          {:reply, {:error, :decryption_failed}, state}
      end
    else
      {:reply, {:error, :not_established}, state}
    end
  end

  def handle_call(:handshake_hash, _from, %{ref: ref} = state) do
    {:reply, Decibel.get_handshake_hash(ref), state}
  end

  def handle_call(:remote_key, _from, %{ref: ref} = state) do
    {:reply, Decibel.get_remote_key(ref), state}
  end

  def handle_call(:close, _from, %{ref: ref} = state) do
    Decibel.close(ref)
    {:reply, :ok, state}
  end

  @impl true
  def terminate(_reason, %{ref: ref}) do
    Decibel.close(ref)
  end
end
