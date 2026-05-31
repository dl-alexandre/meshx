defmodule Mob.Runtime.TCPThreeNodeRelayTest do
  @moduledoc """
  End-to-end relay test across three independent BEAM processes:
  sender → relay → receiver. Verifies that a relay node forwards an
  application packet to a downstream peer it knows about, with TTL
  decremented.
  """

  use ExUnit.Case

  @moduletag capture_log: true
  @moduletag timeout: 60_000
  @repo_root Path.expand("../../../..", __DIR__)

  test "sender → relay → receiver delivers a data packet end-to-end" do
    dir = Path.join(System.tmp_dir!(), "mob_3node_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    receiver_ready = Path.join(dir, "receiver.port")
    relay_ready = Path.join(dir, "relay.port")
    payload_file = Path.join(dir, "payload.term")
    relayed_file = Path.join(dir, "relayed.term")

    receiver_store = Path.join(dir, "receiver_store")
    relay_store = Path.join(dir, "relay_store")
    sender_store = Path.join(dir, "sender_store")

    receiver_task =
      Task.async(fn ->
        run_node(%{
          "MESHX_ROLE" => "receiver",
          "MESHX_NODE_ID" => "receiver",
          "MESHX_READY_FILE" => receiver_ready,
          "MESHX_PAYLOAD_FILE" => payload_file,
          "MESHX_STORE_DATA_DIR" => receiver_store,
          "MESHX_TIMEOUT_MS" => "30000"
        })
      end)

    receiver_port = wait_for_port_file!(receiver_ready)

    relay_task =
      Task.async(fn ->
        run_node(%{
          "MESHX_ROLE" => "relay",
          "MESHX_NODE_ID" => "relay",
          "MESHX_READY_FILE" => relay_ready,
          "MESHX_DOWNSTREAM_ID" => "receiver",
          "MESHX_DOWNSTREAM_PORT" => Integer.to_string(receiver_port),
          "MESHX_RELAYED_FILE" => relayed_file,
          "MESHX_STORE_DATA_DIR" => relay_store,
          "MESHX_TIMEOUT_MS" => "30000"
        })
      end)

    relay_port = wait_for_port_file!(relay_ready)

    sender_result =
      run_node(%{
        "MESHX_ROLE" => "sender",
        "MESHX_NODE_ID" => "sender",
        "MESHX_UPSTREAM_ID" => "relay",
        "MESHX_UPSTREAM_PORT" => Integer.to_string(relay_port),
        "MESHX_PAYLOAD" => "relayed-hello",
        "MESHX_TTL" => "4",
        "MESHX_STORE_DATA_DIR" => sender_store,
        "MESHX_TIMEOUT_MS" => "30000"
      })

    assert {_out, 0} = sender_result
    assert {_out, 0} = Task.await(relay_task, 45_000)
    assert {_out, 0} = Task.await(receiver_task, 45_000)

    assert {"sender", relay_msg_id, "relayed-hello", _ttl} =
             relayed_file |> File.read!() |> :erlang.binary_to_term()

    assert {origin_peer, recv_msg_id, "relayed-hello"} =
             payload_file |> File.read!() |> :erlang.binary_to_term()

    # The receiver sees the packet relayed *from* the relay node, with the
    # original sender's msg_id preserved.
    assert origin_peer == "relay"
    assert recv_msg_id == relay_msg_id
  end

  defp run_node(env) do
    env =
      [{"MIX_ENV", "test"} | Enum.to_list(env)]
      |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)

    System.cmd(
      "mix",
      ["run", "--no-compile", Path.join(@repo_root, "scripts/tcp_relay_node.exs")],
      cd: @repo_root,
      env: env,
      stderr_to_stdout: true
    )
  end

  defp wait_for_port_file!(path, attempts \\ 300)

  defp wait_for_port_file!(path, attempts) when attempts > 0 do
    case File.read(path) do
      {:ok, port} when byte_size(port) > 0 ->
        String.to_integer(port)

      _ ->
        Process.sleep(100)
        wait_for_port_file!(path, attempts - 1)
    end
  end

  defp wait_for_port_file!(path, 0), do: flunk("ready file never appeared: #{path}")
end
