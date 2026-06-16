defmodule Mob.Noise.GroupCipher do
  @moduledoc """
  Authenticated encryption for a single group (sender-key) message.

  Given a 32-byte message key produced by `Mob.Noise.SenderKey.advance/1`,
  this module derives a ChaCha20-Poly1305 key + nonce and seals/opens a
  payload. It is **pure** — the message key is supplied by the caller and
  the same key is never used twice because the ratchet produces a fresh
  message key for every generation.

  ## Nonce safety

  ChaCha20-Poly1305 is catastrophic under nonce reuse, so the nonce must
  be unique per `(key, nonce)` pair. Here the **key itself is unique per
  message** (one message key per ratchet generation), so a deterministic
  nonce derived from that key is safe: distinct message keys yield
  distinct `(key, nonce)` pairs. Both the AEAD key and the nonce are
  derived from the message key via domain-separated HMAC-SHA256, so the
  AEAD key is independent of the nonce.

      aead_key = HMAC-SHA256(message_key, "mx-group-key/1")          (32 bytes)
      nonce    = HMAC-SHA256(message_key, "mx-group-nonce/1")[0..11]  (12 bytes)

  ## Wire shape

  `seal/3` returns `ciphertext <> tag` (the 16-byte Poly1305 tag is
  appended). `open/3` expects that same layout.
  """

  @aead_cipher :chacha20_poly1305
  @key_size 32
  @nonce_size 12
  @tag_size 16

  @key_info "mx-group-key/1"
  @nonce_info "mx-group-nonce/1"

  @doc "Size in bytes of the appended authentication tag (16)."
  @spec tag_size() :: pos_integer()
  def tag_size, do: @tag_size

  @doc """
  Encrypts `plaintext` under `message_key`, binding `aad` (associated
  data — not encrypted but authenticated). Returns `ciphertext <> tag`.

  Raises `ArgumentError` only if `message_key` is not a 32-byte binary,
  which is a caller bug (the ratchet always yields 32 bytes).
  """
  @spec seal(binary(), binary(), binary()) :: binary()
  def seal(message_key, plaintext, aad)
      when is_binary(message_key) and byte_size(message_key) == @key_size and
             is_binary(plaintext) and is_binary(aad) do
    {key, nonce} = derive(message_key)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(@aead_cipher, key, nonce, plaintext, aad, @tag_size, true)

    ciphertext <> tag
  end

  @doc """
  Decrypts a `ciphertext <> tag` blob produced by `seal/3` under
  `message_key`, verifying `aad`.

  Returns `{:ok, plaintext}` on success, `{:error, :auth_failed}` if the
  tag does not verify (wrong key, tampered bytes, or wrong `aad`), and
  `{:error, :malformed}` if the blob is too short to contain a tag.
  """
  @spec open(binary(), binary(), binary()) ::
          {:ok, binary()} | {:error, :auth_failed | :malformed}
  def open(message_key, blob, aad)
      when is_binary(message_key) and byte_size(message_key) == @key_size and
             is_binary(blob) and is_binary(aad) do
    if byte_size(blob) < @tag_size do
      {:error, :malformed}
    else
      ciphertext_size = byte_size(blob) - @tag_size
      <<ciphertext::binary-size(ciphertext_size), tag::binary-size(@tag_size)>> = blob
      {key, nonce} = derive(message_key)

      case :crypto.crypto_one_time_aead(@aead_cipher, key, nonce, ciphertext, aad, tag, false) do
        :error -> {:error, :auth_failed}
        plaintext when is_binary(plaintext) -> {:ok, plaintext}
      end
    end
  end

  defp derive(message_key) do
    key = :crypto.mac(:hmac, :sha256, message_key, @key_info)

    <<nonce::binary-size(@nonce_size), _::binary>> =
      :crypto.mac(:hmac, :sha256, message_key, @nonce_info)

    {key, nonce}
  end
end
