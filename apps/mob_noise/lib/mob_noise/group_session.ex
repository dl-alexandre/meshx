defmodule Mob.Noise.GroupSession do
  @moduledoc """
  Per-channel group messaging state for one member, built on sender keys.

  A session holds:

    * one **sending chain** (this member's own `Mob.Noise.SenderKey`), and
    * a **receiving chain per remote sender id** it has been told about.

  It is a **pure data structure** — every operation takes a session and
  returns an updated session. No process, no transport. The owning
  GenServer (group-key manager) persists and distributes; this module
  just does the ratchet bookkeeping and AEAD via `Mob.Noise.GroupCipher`.

  ## Out-of-order delivery

  BLE mesh delivery is unordered and lossy, so a receiver may see
  generation `5` before generation `3`. When decrypting generation `g`
  on a receiving chain currently at generation `c`:

    * `g == c` — derive, decrypt, advance to `c + 1` (the common case).
    * `g > c`  — ratchet forward, **caching** the skipped message keys
      for generations `c..g-1` so they can still be used when those
      messages arrive later, then decrypt `g`. Bounded by `:max_skip`
      to cap work/memory from a forged far-future generation.
    * `g < c`  — look in the skipped-key cache. Found → use it once and
      drop it (so it cannot be replayed). Absent → `:duplicate_or_old`
      (already consumed, or evicted).

  This gives both out-of-order tolerance and replay protection: a
  message key is usable exactly once.
  """

  alias Mob.Noise.{GroupCipher, SenderKey}

  @default_max_skip 2_000

  @enforce_keys [:sending, :receiving, :max_skip]
  defstruct sending: nil, receiving: %{}, max_skip: @default_max_skip

  @type sender_id :: binary()

  @type receiving_chain :: %{
          chain: SenderKey.t(),
          skipped: %{optional(non_neg_integer()) => binary()}
        }

  @type t :: %__MODULE__{
          sending: SenderKey.t() | nil,
          receiving: %{optional(sender_id()) => receiving_chain()},
          max_skip: pos_integer()
        }

  @doc """
  Creates an empty session with no chains.

  Options:
    * `:max_skip` — max generations a single decrypt may ratchet past
      (default `#{@default_max_skip}`); caps work from a forged future
      generation.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      sending: nil,
      receiving: %{},
      max_skip: Keyword.get(opts, :max_skip, @default_max_skip)
    }
  end

  @doc """
  Ensures the session has a sending chain, creating a fresh one if absent.

  Returns `{session, distribution}` where `distribution` is the SKDM
  binary (via `Mob.Noise.SenderKeyDistribution`) to hand to peers so they
  can read this member's messages. When a sending chain already exists
  the SKDM reflects its **current** generation, so a peer installing it
  starts in sync rather than replaying already-sent generations.
  """
  @spec ensure_sending(t()) :: {t(), binary()}
  def ensure_sending(%__MODULE__{sending: nil} = session) do
    sending = SenderKey.create()
    {%{session | sending: sending}, Mob.Noise.SenderKeyDistribution.encode(sending)}
  end

  def ensure_sending(%__MODULE__{sending: %SenderKey{} = sending} = session) do
    {session, Mob.Noise.SenderKeyDistribution.encode(sending)}
  end

  @doc """
  Rotates this member's sending chain to a brand-new random chain at
  generation 0. Returns `{session, new_distribution}`.

  Use when the local member wants forward secrecy from this point (e.g.
  app policy / future membership-change handling). Peers must receive the
  new SKDM to keep reading.
  """
  @spec rotate_sending(t()) :: {t(), binary()}
  def rotate_sending(%__MODULE__{} = session) do
    sending = SenderKey.create()
    {%{session | sending: sending}, Mob.Noise.SenderKeyDistribution.encode(sending)}
  end

  @doc """
  Installs (or replaces) the receiving chain for `sender_id` from a
  decoded SKDM `%{chain_key, generation}`.

  Replacing resets the skipped-key cache for that sender — a rotation is
  a clean break, and stale skipped keys from the old chain are
  meaningless against the new one.

  Returns `{:ok, session}` or `{:error, reason}` from `SenderKey.from/2`.
  """
  @spec install_sender_key(t(), sender_id(), %{
          chain_key: binary(),
          generation: non_neg_integer()
        }) :: {:ok, t()} | {:error, atom()}
  def install_sender_key(%__MODULE__{} = session, sender_id, %{
        chain_key: chain_key,
        generation: generation
      })
      when is_binary(sender_id) do
    case SenderKey.from(chain_key, generation) do
      {:ok, chain} ->
        receiving = Map.put(session.receiving, sender_id, %{chain: chain, skipped: %{}})
        {:ok, %{session | receiving: receiving}}

      {:error, _} = err ->
        err
    end
  end

  @doc "Returns true if a receiving chain for `sender_id` is installed."
  @spec has_sender?(t(), sender_id()) :: boolean()
  def has_sender?(%__MODULE__{receiving: receiving}, sender_id),
    do: Map.has_key?(receiving, sender_id)

  @doc """
  Encrypts `plaintext` on the sending chain, binding `aad`.

  Returns `{:ok, session, generation, blob}` where `generation` is the
  ratchet generation the receiver needs to decrypt and `blob` is the
  sealed `ciphertext <> tag`. Returns `{:error, :no_sending_chain}` if
  `ensure_sending/1` was never called.
  """
  @spec encrypt(t(), binary(), binary()) ::
          {:ok, t(), non_neg_integer(), binary()} | {:error, :no_sending_chain}
  def encrypt(%__MODULE__{sending: nil}, _plaintext, _aad), do: {:error, :no_sending_chain}

  def encrypt(%__MODULE__{sending: %SenderKey{} = sending} = session, plaintext, aad)
      when is_binary(plaintext) and is_binary(aad) do
    {%{generation: generation, message_key: message_key}, next} = SenderKey.advance(sending)
    blob = GroupCipher.seal(message_key, plaintext, aad)
    {:ok, %{session | sending: next}, generation, blob}
  end

  @doc """
  Decrypts `blob` claimed to be from `sender_id` at `generation`, with
  `aad`.

  Returns `{:ok, session, plaintext}` or `{:error, reason}`:

    * `:no_sender` — no receiving chain installed for `sender_id`
      (caller should request its SKDM).
    * `:duplicate_or_old` — generation already consumed or evicted.
    * `:too_far_ahead` — generation exceeds `max_skip` past the chain
      (likely forged); chain is left untouched.
    * `:auth_failed` — derived key did not authenticate the blob.
  """
  @spec decrypt(t(), sender_id(), non_neg_integer(), binary(), binary()) ::
          {:ok, t(), binary()}
          | {:error, :no_sender | :duplicate_or_old | :too_far_ahead | :auth_failed | :malformed}
  def decrypt(%__MODULE__{} = session, sender_id, generation, blob, aad)
      when is_integer(generation) and generation >= 0 and is_binary(blob) and is_binary(aad) do
    case Map.fetch(session.receiving, sender_id) do
      :error ->
        {:error, :no_sender}

      {:ok, entry} ->
        if generation < entry.chain.generation do
          decrypt_from_cache(session, sender_id, entry, generation, blob, aad)
        else
          decrypt_by_ratchet(session, sender_id, entry, generation, blob, aad)
        end
    end
  end

  # generation already passed — only the skipped cache can serve it.
  defp decrypt_from_cache(session, sender_id, entry, generation, blob, aad) do
    case Map.fetch(entry.skipped, generation) do
      :error ->
        {:error, :duplicate_or_old}

      {:ok, message_key} ->
        case GroupCipher.open(message_key, blob, aad) do
          {:ok, plaintext} ->
            entry = %{entry | skipped: Map.delete(entry.skipped, generation)}
            {:ok, put_receiving(session, sender_id, entry), plaintext}

          {:error, _} = err ->
            err
        end
    end
  end

  # generation >= chain generation — ratchet forward, caching skipped keys.
  defp decrypt_by_ratchet(session, sender_id, entry, generation, blob, aad) do
    %{chain: chain} = entry
    skip = generation - chain.generation

    if skip > session.max_skip do
      {:error, :too_far_ahead}
    else
      {message_key, advanced_chain, skipped} = ratchet_to(chain, generation, entry.skipped)

      case GroupCipher.open(message_key, blob, aad) do
        {:ok, plaintext} ->
          entry = %{entry | chain: advanced_chain, skipped: skipped}
          {:ok, put_receiving(session, sender_id, entry), plaintext}

        {:error, _} = err ->
          # Authentication failed: do NOT advance the chain or persist
          # skipped keys for what is very likely a forged/corrupt frame.
          err
      end
    end
  end

  # Ratchets `chain` from its current generation up to and including
  # `target`, returning the message key for `target`, the chain at
  # `target + 1`, and the skipped-key cache populated for the gap.
  defp ratchet_to(chain, target, skipped) do
    if chain.generation < target do
      {%{generation: g, message_key: mk}, next} = SenderKey.advance(chain)
      ratchet_to(next, target, Map.put(skipped, g, mk))
    else
      {%{message_key: mk}, next} = SenderKey.advance(chain)
      {mk, next, skipped}
    end
  end

  defp put_receiving(session, sender_id, entry) do
    %{session | receiving: Map.put(session.receiving, sender_id, entry)}
  end
end
