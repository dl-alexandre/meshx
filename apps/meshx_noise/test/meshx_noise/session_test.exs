defmodule MeshxNoise.SessionTest do
  use ExUnit.Case

  @moduletag capture_log: true

  alias MeshxNoise.{Session, Supervisor}

  test "start_link requires an explicit role" do
    previous = Process.flag(:trap_exit, true)

    try do
      assert {:error, {%KeyError{key: :role}, _stack}} = Session.start_link()
    after
      Process.flag(:trap_exit, previous)
    end
  end

  test "XX handshake round-trip between initiator and responder" do
    {:ok, ini} = Session.start_link(role: :initiator)
    {:ok, rsp} = Session.start_link(role: :responder)

    # -> e
    {:ok, msg1} = Session.handshake_send(ini)

    # <- e, ee, s, es
    :ok = Session.handshake_recv(rsp, msg1)
    {:ok, msg2} = Session.handshake_send(rsp)

    # -> s, se
    :ok = Session.handshake_recv(ini, msg2)
    {:ok, msg3} = Session.handshake_send(ini)

    # final receive
    :ok = Session.handshake_recv(rsp, msg3)

    assert Session.established?(ini)
    assert Session.established?(rsp)

    # Verify handshake hashes match
    assert Session.handshake_hash(ini) == Session.handshake_hash(rsp)
    assert byte_size(Session.handshake_hash(ini)) == 32
    assert byte_size(Session.remote_key(ini)) == 32
    assert byte_size(Session.remote_key(rsp)) == 32

    # Encrypt / decrypt
    plaintext = "hello from initiator"
    {:ok, ciphertext} = Session.encrypt(ini, plaintext)
    {:ok, decrypted} = Session.decrypt(rsp, ciphertext)
    assert decrypted == plaintext

    # Reverse direction
    plaintext2 = "hello from responder"
    {:ok, ciphertext2} = Session.encrypt(rsp, plaintext2)
    {:ok, decrypted2} = Session.decrypt(ini, ciphertext2)
    assert decrypted2 == plaintext2
  end

  test "encrypt fails before handshake completes" do
    {:ok, pid} = Session.start_link(role: :initiator)
    assert {:error, :not_established} = Session.encrypt(pid, "too early")
    assert {:error, :not_established} = Session.decrypt(pid, "too early")
    assert Session.handshake_hash(pid) == nil
    assert Session.remote_key(pid) == nil
  end

  test "sessions can start with caller-provided static keys" do
    keys = %{s: :crypto.generate_key(:ecdh, :x25519)}

    assert {:ok, pid} = Session.start_link(role: :initiator, keys: keys)
    refute Session.established?(pid)
  end

  test "non-static Noise protocols do not require generated static keys" do
    {:ok, ini} =
      Session.start_link(role: :initiator, protocol: "Noise_NN_25519_ChaChaPoly_BLAKE2s")

    {:ok, rsp} =
      Session.start_link(role: :responder, protocol: "Noise_NN_25519_ChaChaPoly_BLAKE2s")

    {:ok, msg1} = Session.handshake_send(ini)
    :ok = Session.handshake_recv(rsp, msg1)
    {:ok, msg2} = Session.handshake_send(rsp)
    :ok = Session.handshake_recv(ini, msg2)

    assert Session.established?(ini)
    assert Session.established?(rsp)
  end

  test "handshake_send returns error when complete" do
    {:ok, ini} = Session.start_link(role: :initiator)
    {:ok, rsp} = Session.start_link(role: :responder)

    # Complete handshake quickly
    {:ok, m1} = Session.handshake_send(ini)
    :ok = Session.handshake_recv(rsp, m1)
    {:ok, m2} = Session.handshake_send(rsp)
    :ok = Session.handshake_recv(ini, m2)
    {:ok, m3} = Session.handshake_send(ini)
    :ok = Session.handshake_recv(rsp, m3)

    assert Session.established?(ini)
    assert {:error, :handshake_complete} = Session.handshake_send(ini)
  end

  test "handshake_recv reports decryption failures" do
    {:ok, pid} = Session.start_link(role: :responder)

    assert {:error, :decryption_failed} = Session.handshake_recv(pid, "not-a-valid-handshake")
  end

  test "decrypt reports decryption failures after handshake" do
    {:ok, ini} = Session.start_link(role: :initiator)
    {:ok, rsp} = Session.start_link(role: :responder)
    complete_handshake(ini, rsp)

    assert {:error, :decryption_failed} = Session.decrypt(rsp, "not-valid-ciphertext")
  end

  test "decrypt reports authentication failures with mismatched aad" do
    {:ok, ini} = Session.start_link(role: :initiator)
    {:ok, rsp} = Session.start_link(role: :responder)
    complete_handshake(ini, rsp)

    {:ok, ciphertext} = Session.encrypt(ini, "authenticated", "aad-a")

    assert {:error, :decryption_failed} = Session.decrypt(rsp, ciphertext, "aad-b")
  end

  test "dynamic supervisor starts and terminates sessions" do
    {:ok, pid} = Supervisor.start_session(role: :initiator)

    assert Process.alive?(pid)
    assert :ok = Supervisor.terminate_session(pid)
    refute Process.alive?(pid)
  end

  test "close frees resources" do
    {:ok, pid} = Session.start_link(role: :initiator)
    assert :ok = Session.close(pid)
  end

  defp complete_handshake(ini, rsp) do
    {:ok, msg1} = Session.handshake_send(ini)
    :ok = Session.handshake_recv(rsp, msg1)
    {:ok, msg2} = Session.handshake_send(rsp)
    :ok = Session.handshake_recv(ini, msg2)
    {:ok, msg3} = Session.handshake_send(ini)
    :ok = Session.handshake_recv(rsp, msg3)
  end
end
