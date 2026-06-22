defmodule Mob.Runtime.GroupKeyControl do
  @moduledoc """
  Wire codec for group-key control messages exchanged between members.

  Two message kinds, both carried **inside an already-encrypted pairwise
  channel** (a secure unicast packet over the peer's Noise session) —
  never over the cleartext broadcast path, because a distribution
  message carries a live sender chain key:

    * **distribution** (`"MXG1"`) — "here is my sender key for this
      channel", wrapping a `Mob.Noise.SenderKeyDistribution` SKDM.
    * **request** (`"MXGR"`) — "I received a message I can't read; please
      send me `sender_id`'s sender key for this channel". Carries no
      secret, so it is safe even if a transport leaks it.

  Both are framed with a length-prefixed channel id so a single control
  envelope is self-describing. This module is **pure** serialization.
  """

  @distribution_tag "MXG1"
  @request_tag "MXGR"

  @type distribution :: {:distribution, channel :: binary(), skdm :: binary()}
  @type request :: {:request, channel :: binary(), sender_id :: binary()}
  @type t :: distribution() | request()

  @doc """
  Encodes a sender-key distribution for `channel` wrapping `skdm` bytes.
  """
  @spec distribution(binary(), binary()) :: binary()
  def distribution(channel, skdm)
      when is_binary(channel) and byte_size(channel) <= 255 and is_binary(skdm) do
    <<@distribution_tag, byte_size(channel)::8, channel::binary, skdm::binary>>
  end

  @doc """
  Encodes a request for `sender_id`'s sender key on `channel`.
  """
  @spec request(binary(), binary()) :: binary()
  def request(channel, sender_id)
      when is_binary(channel) and byte_size(channel) <= 255 and
             is_binary(sender_id) and byte_size(sender_id) <= 255 do
    <<@request_tag, byte_size(channel)::8, channel::binary, byte_size(sender_id)::8,
      sender_id::binary>>
  end

  @doc """
  Decodes a control payload into a tagged tuple.

  Returns `{:ok, t()}`, or `{:error, :unknown}` for a payload that is not
  a group-key control message (so a caller can fall through to other
  handlers), or `{:error, :malformed}` for a recognised-but-corrupt one.
  """
  @spec decode(binary()) :: {:ok, t()} | {:error, :unknown | :malformed}
  def decode(
        <<@distribution_tag, channel_len::8, channel::binary-size(channel_len), skdm::binary>>
      )
      when skdm != <<>> do
    {:ok, {:distribution, channel, skdm}}
  end

  def decode(<<@request_tag, channel_len::8, channel::binary-size(channel_len), rest::binary>>) do
    case rest do
      <<sender_len::8, sender_id::binary-size(sender_len)>> ->
        {:ok, {:request, channel, sender_id}}

      _ ->
        {:error, :malformed}
    end
  end

  def decode(<<@distribution_tag, _::binary>>), do: {:error, :malformed}
  def decode(<<@request_tag, _::binary>>), do: {:error, :malformed}
  def decode(bin) when is_binary(bin), do: {:error, :unknown}
end
