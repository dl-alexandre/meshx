defmodule Mob.Noise.SenderKeyDistribution do
  @moduledoc """
  Wire format for a **sender-key distribution message** (SKDM).

  When a member wants peers to be able to read its channel messages, it
  sends them its current sending chain — the `{chain_key, generation}`
  pair — as an SKDM. Peers feed it to `Mob.Noise.GroupSession` to build
  the matching receiving chain.

  An SKDM is secret-bearing (it contains a live chain key), so it must
  only ever travel inside an already-authenticated, encrypted pairwise
  Noise session — never in the clear and never over the broadcast path.
  This module is just the serialization; the transport guarantee is the
  caller's (see the group-key distribution manager).

  ## v1 wire format

  Big-endian, fixed length 40 bytes:

      "SKD"            3 bytes  magic
      version          1 byte   currently 1
      generation       4 bytes  uint32
      chain_key       32 bytes
  """

  alias Mob.Noise.SenderKey

  @magic "SKD"
  @version 1
  @chain_key_size 32
  @encoded_size 3 + 1 + 4 + @chain_key_size

  @type t :: %{generation: non_neg_integer(), chain_key: binary()}

  @doc "Fixed encoded size of an SKDM in bytes (40)."
  @spec encoded_size() :: pos_integer()
  def encoded_size, do: @encoded_size

  @doc """
  Encodes a `SenderKey` chain into its SKDM wire bytes.
  """
  @spec encode(SenderKey.t()) :: binary()
  def encode(%SenderKey{chain_key: chain_key, generation: generation})
      when is_binary(chain_key) and byte_size(chain_key) == @chain_key_size and
             generation >= 0 and generation <= 0xFFFFFFFF do
    <<@magic, @version, generation::32-big-unsigned, chain_key::binary-size(@chain_key_size)>>
  end

  @doc """
  Decodes SKDM wire bytes into a `%{generation, chain_key}` map.

  Returns `{:error, :missing_magic}`, `{:error, :unsupported_version}`,
  or `{:error, :malformed}` on bad input — never raises.
  """
  @spec decode(binary()) :: {:ok, t()} | {:error, atom()}
  def decode(
        <<@magic, @version, generation::32-big-unsigned, chain_key::binary-size(@chain_key_size)>>
      ) do
    {:ok, %{generation: generation, chain_key: chain_key}}
  end

  def decode(<<@magic, version, _rest::binary>>) when version != @version do
    {:error, :unsupported_version}
  end

  def decode(<<@magic, _rest::binary>>), do: {:error, :malformed}
  def decode(bin) when is_binary(bin), do: {:error, :missing_magic}
end
