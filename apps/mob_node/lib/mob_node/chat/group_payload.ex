defmodule Mob.Node.Chat.GroupPayload do
  @moduledoc """
  Codec for the body of an **encrypted** chat message.

  When a channel is encrypted, the `MessageEnvelope`'s `payload_type` is
  `"CHATG"` and its `payload` is this structure rather than raw text:

      "G1"          2 bytes  magic
      generation    4 bytes  uint32 (big-endian) — sender ratchet generation
      blob          n bytes  Mob.Noise.GroupCipher sealed `ciphertext <> tag`

  The envelope still carries `sender_peer_id` and the packet still carries
  `channel_id` in the clear, so a receiver knows *which* sender chain and
  *which* channel to decrypt with (and they form the AEAD associated
  data) — only the message text is confidential.

  Pure serialization; never raises.
  """

  @magic "G1"

  @doc "Encodes a ratchet `generation` + sealed `blob` into a chat payload."
  @spec encode(non_neg_integer(), binary()) :: binary()
  def encode(generation, blob)
      when is_integer(generation) and generation >= 0 and generation <= 0xFFFFFFFF and
             is_binary(blob) do
    <<@magic, generation::32-big-unsigned, blob::binary>>
  end

  @doc """
  Decodes a chat payload into `{:ok, generation, blob}`.

  Returns `{:error, :not_group_payload}` for bytes without the magic (so
  a receiver can fall back to treating it as cleartext) or
  `{:error, :malformed}` for a truncated header.
  """
  @spec decode(binary()) ::
          {:ok, non_neg_integer(), binary()} | {:error, :not_group_payload | :malformed}
  def decode(<<@magic, generation::32-big-unsigned, blob::binary>>), do: {:ok, generation, blob}
  def decode(<<@magic, _rest::binary>>), do: {:error, :malformed}
  def decode(bin) when is_binary(bin), do: {:error, :not_group_payload}
end
