defmodule Mob.Noise.SwiftInteropTest do
  @moduledoc """
  Cross-process interop tests for `Noise_XX_25519_ChaChaPoly_BLAKE2s`.

  These tests drive the Decibel-backed `Mob.Noise.Session` directly from
  ExUnit and use the Swift package executable `MeshxNoiseInteropCLI` as the
  opposite peer. The Swift peer uses fixed test-only static and ephemeral keys
  so each process invocation can deterministically replay the same side of the
  handshake while Decibel supplies the live counterparty messages.
  """

  use ExUnit.Case, async: false

  @moduletag :requires_swift

  alias Mob.Noise.Session

  @protocol "Noise_XX_25519_ChaChaPoly_BLAKE2s"
  @swift_dir Path.expand("../../../../meshx_mobile", __DIR__)
  @swift_peer Path.join([@swift_dir, ".build", "debug", "MeshxNoiseInteropCLI"])

  @ini_s_priv Base.decode16!("1111111111111111111111111111111111111111111111111111111111111111")
  @ini_e_priv Base.decode16!("2222222222222222222222222222222222222222222222222222222222222222")
  @rsp_s_priv Base.decode16!("3333333333333333333333333333333333333333333333333333333333333333")
  @rsp_e_priv Base.decode16!("4444444444444444444444444444444444444444444444444444444444444444")

  setup_all do
    {cmd, args} =
      case System.find_executable("xcrun") do
        nil -> {"swift", ["build", "--product", "MeshxNoiseInteropCLI"]}
        _ -> {"xcrun", ["swift", "build", "--product", "MeshxNoiseInteropCLI"]}
      end

    {output, status} = System.cmd(cmd, args, cd: @swift_dir, stderr_to_stdout: true)
    assert status == 0, output
    assert File.exists?(@swift_peer)

    :ok
  end

  test "Swift initiator completes XX handshake with Decibel responder" do
    swift_m1 = swift_peer!("initiator-message1")
    decibel = init_responder()

    :ok = Session.handshake_recv(decibel, hex_to_bin(swift_m1["message1"]))
    {:ok, decibel_m2} = Session.handshake_send(decibel)

    swift_final =
      swift_peer!("initiator", ["--responder-message2", bin_to_hex(decibel_m2)])

    assert swift_final["established"]
    assert swift_final["message1"] == swift_m1["message1"]

    :ok = Session.handshake_recv(decibel, hex_to_bin(swift_final["message3"]))
    assert Session.established?(decibel)

    assert swift_final["handshakeHash"] ==
             Base.encode16(Session.handshake_hash(decibel), case: :lower)

    assert Session.remote_key(decibel) == hex_to_bin(swift_final["localStaticKey"])

    assert swift_final["remoteStaticKey"] ==
             Base.encode16(local_public(@rsp_s_priv), case: :lower)

    {:ok, decoded} = Session.decrypt(decibel, hex_to_bin(swift_final["ciphertextToResponder"]))
    assert IO.iodata_to_binary(decoded) == "swift-to-decibel"

    {:ok, decibel_ct} = Session.encrypt(decibel, "decibel-to-swift")

    swift_after_reply =
      swift_peer!(
        "initiator",
        [
          "--responder-message2",
          bin_to_hex(decibel_m2),
          "--responder-ciphertext",
          bin_to_hex(decibel_ct)
        ]
      )

    assert swift_after_reply["decryptedFromResponder"] == "decibel-to-swift"
  end

  test "Decibel initiator completes XX handshake with Swift responder" do
    decibel = init_initiator()
    {:ok, decibel_m1} = Session.handshake_send(decibel)

    swift_m2 =
      swift_peer!("responder-message2", ["--message1", bin_to_hex(decibel_m1)])

    :ok = Session.handshake_recv(decibel, hex_to_bin(swift_m2["message2"]))
    {:ok, decibel_m3} = Session.handshake_send(decibel)

    assert Session.established?(decibel)

    {:ok, decibel_ct} = Session.encrypt(decibel, "decibel-to-swift")

    swift_final =
      swift_peer!(
        "responder",
        [
          "--message1",
          bin_to_hex(decibel_m1),
          "--message3",
          bin_to_hex(decibel_m3),
          "--initiator-ciphertext",
          bin_to_hex(decibel_ct)
        ]
      )

    assert swift_final["established"]
    assert swift_final["message2"] == swift_m2["message2"]

    assert swift_final["handshakeHash"] ==
             Base.encode16(Session.handshake_hash(decibel), case: :lower)

    assert Session.remote_key(decibel) == hex_to_bin(swift_final["localStaticKey"])

    assert swift_final["remoteStaticKey"] ==
             Base.encode16(local_public(@ini_s_priv), case: :lower)

    assert swift_final["decryptedFromInitiator"] == "decibel-to-swift"

    {:ok, decoded} = Session.decrypt(decibel, hex_to_bin(swift_final["ciphertextToInitiator"]))
    assert IO.iodata_to_binary(decoded) == "swift-to-decibel"
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

  defp keypair_from_priv(priv) do
    {pub, _} = :crypto.generate_key(:eddh, :x25519, priv)
    {pub, priv}
  end

  defp local_public(priv) do
    {pub, _} = keypair_from_priv(priv)
    pub
  end

  defp swift_peer!(mode, args \\ []) do
    args = List.wrap(args)

    {output, status} =
      System.cmd(@swift_peer, [mode | args], cd: @swift_dir, stderr_to_stdout: true)

    assert status == 0, output

    :json.decode(output)
  end

  defp hex_to_bin(hex) do
    Base.decode16!(hex, case: :lower)
  end

  defp bin_to_hex(iodata) do
    iodata
    |> IO.iodata_to_binary()
    |> Base.encode16(case: :lower)
  end
end
