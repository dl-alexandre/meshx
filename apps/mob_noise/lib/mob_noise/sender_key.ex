defmodule Mob.Noise.SenderKey do
  @moduledoc """
  A Signal-style sender-key symmetric ratchet for group (channel) messaging.

  A sender key is a `{chain_key, generation}` pair. Each member of a
  channel holds **one sending chain of its own** and **one receiving
  chain per other sender** it has been told about. The chain advances
  forward only: deriving the message key for generation `g` also
  produces the chain key for generation `g + 1`, and the generation-`g`
  chain key is then discarded. That one-way derivation is what gives the
  scheme forward secrecy — a captured chain at generation `g` cannot
  recover the message keys for any generation `< g`.

  This module is **pure ratchet math** — no process, no transport, no
  AEAD. `Mob.Noise.GroupCipher` turns a derived message key into a
  sealed payload; `Mob.Noise.GroupSession` manages the collection of
  sending/receiving chains and out-of-order delivery.

  ## Derivation

      message_key      = HMAC-SHA256(chain_key, <<0x01>>)
      next_chain_key   = HMAC-SHA256(chain_key, <<0x02>>)

  Both outputs are 32 bytes. The two distinct one-byte messages domain-
  separate the message-key leg from the chain-advance leg so that
  knowing a message key never reveals the next chain key.
  """

  @chain_key_size 32
  @message_key_size 32

  @message_key_constant <<0x01>>
  @chain_key_constant <<0x02>>

  @enforce_keys [:chain_key, :generation]
  defstruct [:chain_key, :generation]

  @type t :: %__MODULE__{
          chain_key: <<_::256>>,
          generation: non_neg_integer()
        }

  @doc "Size in bytes of a chain key (32)."
  @spec chain_key_size() :: pos_integer()
  def chain_key_size, do: @chain_key_size

  @doc "Size in bytes of a derived message key (32)."
  @spec message_key_size() :: pos_integer()
  def message_key_size, do: @message_key_size

  @doc """
  Creates a fresh sending chain seeded with a random 32-byte chain key
  at generation 0.

  The resulting chain (its `chain_key` + `generation`) is exactly what a
  member distributes to its peers as a sender-key distribution message
  (`Mob.Noise.SenderKeyDistribution`) so they can build the matching
  receiving chain.
  """
  @spec create() :: t()
  def create do
    %__MODULE__{chain_key: :crypto.strong_rand_bytes(@chain_key_size), generation: 0}
  end

  @doc """
  Rebuilds a chain from a known `chain_key` and `generation`. Used by a
  receiver installing a distributed sender key, and by persistence.

  Returns `{:error, :invalid_chain_key}` for a non-32-byte key and
  `{:error, :invalid_generation}` for a negative generation.
  """
  @spec from(binary(), non_neg_integer()) :: {:ok, t()} | {:error, atom()}
  def from(chain_key, generation \\ 0)

  def from(chain_key, generation)
      when is_binary(chain_key) and byte_size(chain_key) == @chain_key_size and
             is_integer(generation) and generation >= 0 do
    {:ok, %__MODULE__{chain_key: chain_key, generation: generation}}
  end

  def from(chain_key, _generation)
      when not is_binary(chain_key) or byte_size(chain_key) != @chain_key_size do
    {:error, :invalid_chain_key}
  end

  def from(_chain_key, _generation), do: {:error, :invalid_generation}

  @doc """
  Advances the chain by one step.

  Returns `{%{generation: g, message_key: mk}, next_chain}` where `g` is
  the generation the message key belongs to (the chain's generation
  *before* this call) and `next_chain` is the chain positioned at
  `g + 1`. The current chain key is consumed and never reproduced.
  """
  @spec advance(t()) :: {%{generation: non_neg_integer(), message_key: binary()}, t()}
  def advance(%__MODULE__{chain_key: chain_key, generation: generation}) do
    message_key = hmac(chain_key, @message_key_constant)
    next_chain_key = hmac(chain_key, @chain_key_constant)

    {%{generation: generation, message_key: message_key},
     %__MODULE__{chain_key: next_chain_key, generation: generation + 1}}
  end

  defp hmac(key, message), do: :crypto.mac(:hmac, :sha256, key, message)
end
