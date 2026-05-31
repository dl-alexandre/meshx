defmodule Mob.Node.BLE.LocalSecurityReplayProtection do
  @moduledoc """
  Pure bounded replay guard for authenticated full-envelope observations.

  The guard records proof fingerprints for full `MessageEnvelope` values
  inside an in-memory bounded window. It can reject expired envelopes and
  duplicate proofs after authorship/identity verification has succeeded.
  It does not verify signatures, manage keys, persist replay state, trust
  peers, authenticate beacon refs, fetch, route, ACK, retry, encrypt, or run
  background work.
  """

  alias Mob.Node.BLE.MessageEnvelope
  alias Mob.Node.BLE.LocalSecurityAuthorshipProof.Proof

  defmodule State do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :window_ms,
               :max_entries,
               :seen
             ]}
    @enforce_keys [:window_ms, :max_entries, :seen]
    defstruct @enforce_keys

    @type seen_entry :: %{
            required(:fingerprint) => binary(),
            required(:message_id) => binary(),
            required(:key_id) => binary(),
            required(:sender_peer_id) => binary(),
            required(:first_seen_at) => non_neg_integer()
          }

    @type t :: %__MODULE__{
            window_ms: pos_integer(),
            max_entries: pos_integer(),
            seen: [seen_entry()]
          }
  end

  @default_window_ms 300_000
  @default_max_entries 256

  @type accept_error ::
          :invalid_window
          | :invalid_max_entries
          | :invalid_observed_at
          | :invalid_envelope
          | :invalid_proof
          | :expired_envelope
          | :duplicate_proof

  @spec new(keyword()) :: {:ok, State.t()} | {:error, accept_error()}
  def new(opts \\ []) do
    window_ms = Keyword.get(opts, :window_ms, @default_window_ms)
    max_entries = Keyword.get(opts, :max_entries, @default_max_entries)

    with :ok <- validate_window(window_ms),
         :ok <- validate_max_entries(max_entries) do
      {:ok, %State{window_ms: window_ms, max_entries: max_entries, seen: []}}
    end
  end

  @spec accept(State.t(), MessageEnvelope.t(), Proof.t(), keyword()) ::
          {:ok, State.t(), map()} | {:error, accept_error(), State.t()}
  def accept(state, envelope, proof, opts \\ [])

  def accept(%State{} = state, %MessageEnvelope{} = envelope, %Proof{} = proof, opts) do
    observed_at = Keyword.get(opts, :observed_at)

    with :ok <- validate_observed_at(observed_at),
         :ok <- validate_envelope(envelope),
         :ok <- validate_proof(proof),
         :ok <- validate_fresh(envelope, observed_at, state.window_ms) do
      pruned = prune(state, observed_at)
      fingerprint = fingerprint(envelope, proof)

      if Enum.any?(pruned.seen, &(&1.fingerprint == fingerprint)) do
        {:error, :duplicate_proof, pruned}
      else
        entry = %{
          fingerprint: fingerprint,
          message_id: envelope.message_id,
          key_id: proof.key_id,
          sender_peer_id: envelope.sender_peer_id,
          first_seen_at: observed_at
        }

        next = %{pruned | seen: [entry | pruned.seen] |> Enum.take(pruned.max_entries)}

        {:ok, next,
         %{
           replay_protection?: true,
           replay_decision: :accepted,
           window_ms: next.window_ms,
           fingerprint: fingerprint,
           message_id: envelope.message_id,
           key_id: proof.key_id,
           sender_peer_id: envelope.sender_peer_id,
           observed_at: observed_at,
           expires_at: envelope.created_at + next.window_ms
         }}
      end
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  def accept(%State{} = state, _envelope, _proof, _opts), do: {:error, :invalid_envelope, state}

  @spec prune(State.t(), non_neg_integer()) :: State.t()
  def prune(%State{} = state, observed_at) when is_integer(observed_at) and observed_at >= 0 do
    kept =
      Enum.filter(state.seen, fn entry ->
        observed_at - entry.first_seen_at <= state.window_ms
      end)

    %{state | seen: kept}
  end

  @spec fingerprint(MessageEnvelope.t(), Proof.t()) :: binary()
  def fingerprint(%MessageEnvelope{} = envelope, %Proof{} = proof) do
    :crypto.hash(:sha256, [
      "mob-replay-proof-v1",
      MessageEnvelope.encode(envelope),
      proof.key_id,
      proof.signature
    ])
  end

  defp validate_window(window_ms) when is_integer(window_ms) and window_ms > 0, do: :ok
  defp validate_window(_), do: {:error, :invalid_window}

  defp validate_max_entries(max_entries) when is_integer(max_entries) and max_entries > 0,
    do: :ok

  defp validate_max_entries(_), do: {:error, :invalid_max_entries}

  defp validate_observed_at(observed_at) when is_integer(observed_at) and observed_at >= 0,
    do: :ok

  defp validate_observed_at(_), do: {:error, :invalid_observed_at}

  defp validate_envelope(%MessageEnvelope{} = envelope) do
    envelope
    |> MessageEnvelope.encode()
    |> MessageEnvelope.parse()
    |> case do
      {:ok, ^envelope} -> :ok
      {:ok, _} -> {:error, :invalid_envelope}
      {:error, _} -> {:error, :invalid_envelope}
    end
  end

  defp validate_proof(%Proof{key_id: key_id, signature: signature})
       when is_binary(key_id) and byte_size(key_id) > 0 and
              is_binary(signature) and byte_size(signature) == 64,
       do: :ok

  defp validate_proof(_), do: {:error, :invalid_proof}

  defp validate_fresh(%MessageEnvelope{created_at: created_at}, observed_at, window_ms)
       when observed_at >= created_at and observed_at - created_at <= window_ms,
       do: :ok

  defp validate_fresh(_envelope, _observed_at, _window_ms), do: {:error, :expired_envelope}
end
