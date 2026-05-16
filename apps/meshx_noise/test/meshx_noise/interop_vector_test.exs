defmodule MeshxNoise.InteropVectorTest do
  @moduledoc """
  Pinned `Noise_XX_25519_ChaChaPoly_BLAKE2s` handshake vector.

  This file is the **shared source of truth** for the wire format the
  Elixir Decibel-backed `MeshxNoise.Session` and the Swift
  `MeshxMobile/Noise.swift` implementation must both produce when given
  the same key material. The hex strings below were captured from one
  successful Decibel handshake run with all four key inputs fixed
  (initiator + responder static & ephemeral). Any change to either
  implementation that alters the wire bytes for these inputs is either:

    * an intentional protocol bump (update the vector and the Swift
      mirror at the same time), or
    * silent drift (this test fails, no shipping).

  ## Mirroring this on the Swift side

  When/if a parallel Swift test is added under
  `meshx_mobile/Tests/MeshxMobileTests/`, it should consume the same
  hex constants below (or load them from a shared fixture file). The
  same handshake hash must be produced bit-for-bit from the same key
  material — that's the cross-implementation guarantee.

  See project memory `[[ios-ble-bridge-architecture]]` for the
  two-Noise-impl architecture context.
  """

  use ExUnit.Case, async: true

  alias MeshxNoise.Session

  # All keys are 32-byte X25519 values.
  # NOTE: these are TEST VECTORS ONLY — do not reuse anywhere real.
  @ini_s_priv Base.decode16!("1111111111111111111111111111111111111111111111111111111111111111")
  @ini_e_priv Base.decode16!("2222222222222222222222222222222222222222222222222222222222222222")
  @rsp_s_priv Base.decode16!("3333333333333333333333333333333333333333333333333333333333333333")
  @rsp_e_priv Base.decode16!("4444444444444444444444444444444444444444444444444444444444444444")

  @protocol "Noise_XX_25519_ChaChaPoly_BLAKE2s"

  # Expected wire bytes — captured from one successful Decibel run with
  # the keys above. Cross-implementation contract: a Swift Noise.swift
  # test consuming the same key material MUST produce these exact bytes.
  @expected_msg1 Base.decode16!(
                   "0faa684ed28867b97f4a6a2dee5df8ce974e76b7018e3f22a1c4cf2678570f20",
                   case: :lower
                 )
  @expected_msg2 Base.decode16!(
                   "ff2ee45601ec1b67310c7790404585ae697331eee1c1f8cf2419731c1fff3e6b" <>
                     "34844ab378b06d2634652a1eb7d2b6c67c2082af188b41dd5e7da57cf64439f3" <>
                     "9e4164252dece86e03665b2c8170e73626758372b95363977f16178df5b07cf6",
                   case: :lower
                 )
  @expected_msg3 Base.decode16!(
                   "75537efbe989fb8406a0dcce52dbec0f832fd70f3c37a8f6efb0d8b74afcc1a5" <>
                     "7f070028f97b2774865619e7e95635798a0f66f1a7bf1a0524d7a6d60143eda0",
                   case: :lower
                 )
  @expected_hash Base.decode16!(
                   "d8c98117de2824856612c13cda9c2dd1785d92bea9ec0d22eeaf930554676b3b",
                   case: :lower
                 )
  # Transport ciphertext for plaintext "test-vector-001", sent by
  # initiator immediately after handshake completion (uses the
  # initiator-→-responder cipherstate, nonce 0).
  @expected_ct_n0 Base.decode16!(
                    "015b6953682e76b486b21405cabb87c4e1a17a37f259823a5e471f9fa5e08c",
                    case: :lower
                  )
  @expected_ini_s_pub Base.decode16!(
                        "7b4e909bbe7ffe44c465a220037d608ee35897d31ef972f07f74892cb0f73f13",
                        case: :lower
                      )
  @expected_rsp_s_pub Base.decode16!(
                        "7b0d47d93427f8311160781c7c733fd89f88970aef490d8aa0ee19a4cb8a1b14",
                        case: :lower
                      )

  defp keypair_from_priv(priv) do
    {pub, _} = :crypto.generate_key(:eddh, :x25519, priv)
    {pub, priv}
  end

  defp init_initiator do
    {:ok, pid} =
      Session.start_link(
        role: :initiator,
        protocol: @protocol,
        keys: %{
          s: keypair_from_priv(@ini_s_priv),
          e: keypair_from_priv(@ini_e_priv)
        }
      )

    pid
  end

  defp init_responder do
    {:ok, pid} =
      Session.start_link(
        role: :responder,
        protocol: @protocol,
        keys: %{
          s: keypair_from_priv(@rsp_s_priv),
          e: keypair_from_priv(@rsp_e_priv)
        }
      )

    pid
  end

  test "XX handshake with fixed keys produces the pinned wire bytes" do
    ini = init_initiator()
    rsp = init_responder()

    # Each handshake message must match the pinned byte-for-byte. This
    # is the cross-implementation contract — a Swift impl running the
    # same protocol with the same keys MUST produce these exact bytes
    # (and is the basis of interop with non-Decibel peers).
    {:ok, msg1} = Session.handshake_send(ini)
    assert IO.iodata_to_binary(msg1) == @expected_msg1
    :ok = Session.handshake_recv(rsp, IO.iodata_to_binary(msg1))

    {:ok, msg2} = Session.handshake_send(rsp)
    assert IO.iodata_to_binary(msg2) == @expected_msg2
    :ok = Session.handshake_recv(ini, IO.iodata_to_binary(msg2))

    {:ok, msg3} = Session.handshake_send(ini)
    assert IO.iodata_to_binary(msg3) == @expected_msg3
    :ok = Session.handshake_recv(rsp, IO.iodata_to_binary(msg3))

    assert Session.established?(ini)
    assert Session.established?(rsp)

    # Channel-binding hash agreement is the fundamental Noise guarantee.
    assert Session.handshake_hash(ini) == @expected_hash
    assert Session.handshake_hash(rsp) == @expected_hash

    # Recovered remote static keys must match the pinned values.
    assert Session.remote_key(ini) == @expected_rsp_s_pub
    assert Session.remote_key(rsp) == @expected_ini_s_pub
  end

  test "post-handshake transport ciphertext at nonce 0 matches pinned bytes" do
    ini = init_initiator()
    rsp = init_responder()

    {:ok, m1} = Session.handshake_send(ini)
    :ok = Session.handshake_recv(rsp, IO.iodata_to_binary(m1))
    {:ok, m2} = Session.handshake_send(rsp)
    :ok = Session.handshake_recv(ini, IO.iodata_to_binary(m2))
    {:ok, m3} = Session.handshake_send(ini)
    :ok = Session.handshake_recv(rsp, IO.iodata_to_binary(m3))

    # First initiator → responder transport message after handshake
    # completion. Pinned byte-for-byte so any change in cipherstate
    # initialization, nonce handling, or ChaChaPoly framing surfaces
    # here.
    {:ok, ct} = Session.encrypt(ini, "test-vector-001")
    assert IO.iodata_to_binary(ct) == @expected_ct_n0

    # Round-trip: responder decrypts to the original plaintext.
    {:ok, decoded} = Session.decrypt(rsp, IO.iodata_to_binary(ct))
    assert IO.iodata_to_binary(decoded) == "test-vector-001"

    # Reverse direction round-trip (no pinned bytes — nonce 0 on the
    # responder cipherstate, separate value; covered for round-trip
    # symmetry only).
    {:ok, ct_back} = Session.encrypt(rsp, "ack-from-responder")
    {:ok, decoded_back} = Session.decrypt(ini, IO.iodata_to_binary(ct_back))
    assert IO.iodata_to_binary(decoded_back) == "ack-from-responder"
  end

  test "wire bytes are stable across runs given the same key material" do
    # Run the handshake twice, byte-comparing each message. Any source
    # of non-determinism Decibel might introduce (extra randomness,
    # timestamp inclusion, dict-order serialization quirks) shows up
    # here. Catches drift earlier than a Swift-side cross-impl test
    # would.
    transcript_1 = capture_transcript()
    transcript_2 = capture_transcript()
    assert transcript_1 == transcript_2

    # Sanity: each handshake message has non-trivial length. Pins
    # against an accidental no-op handshake (e.g. empty payloads).
    assert byte_size(elem(transcript_1, 0)) > 0
    assert byte_size(elem(transcript_1, 1)) > 0
    assert byte_size(elem(transcript_1, 2)) > 0
    assert byte_size(elem(transcript_1, 3)) == 32
  end

  defp capture_transcript do
    ini = init_initiator()
    rsp = init_responder()

    {:ok, m1} = Session.handshake_send(ini)
    :ok = Session.handshake_recv(rsp, IO.iodata_to_binary(m1))
    {:ok, m2} = Session.handshake_send(rsp)
    :ok = Session.handshake_recv(ini, IO.iodata_to_binary(m2))
    {:ok, m3} = Session.handshake_send(ini)
    :ok = Session.handshake_recv(rsp, IO.iodata_to_binary(m3))

    {
      IO.iodata_to_binary(m1),
      IO.iodata_to_binary(m2),
      IO.iodata_to_binary(m3),
      Session.handshake_hash(ini)
    }
  end
end
