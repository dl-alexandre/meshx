defmodule Mob.Node.Chat.Composer do
  @moduledoc """
  Builds an outbound chat packet from user-authored text.

  Pure module — no GenServer, no transport coupling. The caller
  dispatches the returned `%Mob.Protocol.Packet{}` (typically via
  `Mob.Runtime.Router.broadcast_packet/2`) so ack, retry, and
  multi-hop are handled by the runtime exactly the same way as any
  other `:data` packet.

  The chat payload is a `Mob.Node.BLE.MessageEnvelope` whose
  `payload_type` is `"CHAT"` and `payload` is the raw text bytes. The
  envelope's 16-byte `message_id` is returned alongside the packet so
  the caller can correlate inbound acks / receipts to outbound sends.
  The packet's 32-bit `msg_id` is the little-endian first 4 bytes of
  that envelope id (deterministic link, fits the wire framing).
  """

  alias Mob.Node.BLE.MessageEnvelope
  alias Mob.Node.Chat.GroupPayload
  alias Mob.Node.Chat.Identity
  alias Mob.Protocol.Packet

  @default_ttl 8
  @payload_type "CHAT"
  @encrypted_payload_type "CHATG"

  @type encryptor :: (channel :: String.t(), text :: String.t() ->
                        {:ok, non_neg_integer(), binary()} | :cleartext | {:error, term()})

  @type build_opts :: [
          recipient_peer_id: binary() | nil,
          ttl: 1..255,
          identity: Identity.t(),
          now_ms: integer(),
          encryptor: encryptor()
        ]

  @doc """
  Returns the cleartext chat payload-type marker (`"CHAT"`). Receivers
  can filter on this in `MessageEnvelope.payload_type` to distinguish
  chat from other envelope traffic.
  """
  @spec payload_type() :: String.t()
  def payload_type, do: @payload_type

  @doc """
  Returns the encrypted chat payload-type marker (`"CHATG"`). An envelope
  with this type carries a `Mob.Node.Chat.GroupPayload` body, not text.
  """
  @spec encrypted_payload_type() :: String.t()
  def encrypted_payload_type, do: @encrypted_payload_type

  @doc """
  Builds a chat packet for `text` on `channel`.

  Returns `{:ok, packet, message_id}` on success. `message_id` is the
  16-byte envelope id; correlate acks against it.

  Errors:
    * `:invalid_channel` — `channel` must be a non-empty binary
    * `:empty_text`     — `text` must be a non-empty binary
    * `{:error, reason}` from `MessageEnvelope.build/1` for bad opts

  Opts (all optional):
    * `:recipient_peer_id` — `nil` (default) = broadcast to the channel
    * `:ttl`               — 1..255 (default `#{@default_ttl}`)
    * `:identity`          — inject `%Identity.t()` (test seam); otherwise read from store
    * `:now_ms`            — override clock (test seam); otherwise `System.system_time(:millisecond)`
  """
  @spec build_packet(String.t(), String.t(), build_opts()) ::
          {:ok, Packet.t(), binary()} | {:error, term()}
  def build_packet(channel, text, opts \\ [])

  def build_packet(channel, _text, _opts) when not is_binary(channel) or channel == "" do
    {:error, :invalid_channel}
  end

  def build_packet(_channel, text, _opts) when not is_binary(text) or text == "" do
    {:error, :empty_text}
  end

  def build_packet(channel, text, opts) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)

    with {:ok, identity} <- get_identity(opts),
         {:ok, payload_type, body} <- payload_for(channel, text, opts),
         {:ok, envelope} <-
           MessageEnvelope.build(
             sender_peer_id: sender_peer_id(identity),
             recipient_peer_id: Keyword.get(opts, :recipient_peer_id),
             created_at: now_ms(opts),
             payload_type: payload_type,
             ttl: ttl,
             payload: body
           ) do
      packet = %Packet{
        version: Packet.version(),
        type: :data,
        flags: Packet.set_flag(Packet.flag_channel(), Packet.flag_ack_requested()),
        ttl: ttl,
        msg_id: msg_id_from_envelope(envelope.message_id),
        channel_id: channel,
        payload: MessageEnvelope.encode(envelope)
      }

      {:ok, packet, envelope.message_id}
    end
  end

  # Decides cleartext vs encrypted body. The encryptor (injected for
  # tests, defaults to the group-key manager) returns `:cleartext` for
  # an unencrypted channel, or `{:ok, generation, blob}` to seal.
  defp payload_for(channel, text, opts) do
    case encryptor(opts).(channel, text) do
      :cleartext ->
        {:ok, @payload_type, text}

      {:ok, generation, blob} ->
        {:ok, @encrypted_payload_type, GroupPayload.encode(generation, blob)}

      {:error, _} = err ->
        err
    end
  end

  defp encryptor(opts), do: Keyword.get(opts, :encryptor, &default_encryptor/2)

  # When the group-key manager isn't running (unit tests, legacy
  # cleartext nodes), send cleartext rather than crashing the send.
  defp default_encryptor(channel, text) do
    if Process.whereis(Mob.Runtime.GroupKeyManager) &&
         Mob.Runtime.GroupKeyManager.encrypted?(channel) do
      Mob.Runtime.GroupKeyManager.encrypt(channel, text)
    else
      :cleartext
    end
  end

  defp msg_id_from_envelope(<<id::32-little, _rest::binary>>), do: id

  # Prefer the raw 32-byte public key form (wire_peer_id) when the identity
  # carries it, which is the case once Identity.get/0 has resolved against
  # Mob.Store. Unit-test identities pass only :peer_id (short literals like
  # "alice-peer" that already fit @max_peer_id_size); fall back to that.
  defp sender_peer_id(%{wire_peer_id: wpid}) when is_binary(wpid), do: wpid
  defp sender_peer_id(%{peer_id: pid}) when is_binary(pid), do: pid

  defp get_identity(opts) do
    case Keyword.get(opts, :identity) do
      nil -> Identity.get()
      ident when is_map(ident) -> {:ok, ident}
    end
  end

  defp now_ms(opts), do: Keyword.get(opts, :now_ms, System.system_time(:millisecond))
end
