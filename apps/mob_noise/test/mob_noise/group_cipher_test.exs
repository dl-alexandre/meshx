defmodule Mob.Noise.GroupCipherTest do
  use ExUnit.Case, async: true

  alias Mob.Noise.GroupCipher

  defp message_key, do: :crypto.strong_rand_bytes(32)

  test "seal/open round-trips with matching key and aad" do
    mk = message_key()
    blob = GroupCipher.seal(mk, "hello channel", "aad")
    assert {:ok, "hello channel"} = GroupCipher.open(mk, blob, "aad")
  end

  test "seal output is ciphertext plus a 16-byte tag" do
    blob = GroupCipher.seal(message_key(), "hi", "")
    assert byte_size(blob) == byte_size("hi") + GroupCipher.tag_size()
  end

  test "empty plaintext round-trips" do
    mk = message_key()
    blob = GroupCipher.seal(mk, "", "aad")
    assert {:ok, ""} = GroupCipher.open(mk, blob, "aad")
  end

  test "wrong message key fails authentication" do
    blob = GroupCipher.seal(message_key(), "secret", "aad")
    assert {:error, :auth_failed} = GroupCipher.open(message_key(), blob, "aad")
  end

  test "wrong aad fails authentication (binds context)" do
    mk = message_key()
    blob = GroupCipher.seal(mk, "secret", "channel-a")
    assert {:error, :auth_failed} = GroupCipher.open(mk, blob, "channel-b")
  end

  test "tampered ciphertext fails authentication" do
    mk = message_key()
    blob = GroupCipher.seal(mk, "secret", "aad")
    <<first, rest::binary>> = blob
    tampered = <<Bitwise.bxor(first, 0xFF), rest::binary>>
    assert {:error, :auth_failed} = GroupCipher.open(mk, tampered, "aad")
  end

  test "blob shorter than the tag is malformed" do
    assert {:error, :malformed} = GroupCipher.open(message_key(), <<1, 2, 3>>, "aad")
  end

  test "deterministic nonce: same key + plaintext + aad yields identical bytes" do
    # Safe because the ratchet never reuses a message key; verifies the
    # nonce derivation is a pure function of the message key.
    mk = message_key()
    assert GroupCipher.seal(mk, "x", "a") == GroupCipher.seal(mk, "x", "a")
  end
end
