defmodule MeshxRuntime.TCPProcessSmokeTest do
  use ExUnit.Case

  @moduletag capture_log: true
  @moduletag timeout: 30_000
  @repo_root Path.expand("../../../..", __DIR__)

  test "two BEAM runtime processes exchange a packet over TCP" do
    dir = Path.join(System.tmp_dir!(), "meshx_tcp_process_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    ready_file = Path.join(dir, "receiver.port")
    payload_file = Path.join(dir, "payload.term")
    receiver_store = Path.join(dir, "receiver_store")
    sender_store = Path.join(dir, "sender_store")

    receiver_task =
      Task.async(fn ->
        run_mix_script(Path.join(@repo_root, "scripts/tcp_receiver.exs"), %{
          "MESHX_NODE_ID" => "receiver",
          "MESHX_READY_FILE" => ready_file,
          "MESHX_PAYLOAD_FILE" => payload_file,
          "MESHX_STORE_DATA_DIR" => receiver_store,
          "MESHX_TIMEOUT_MS" => "15000"
        })
      end)

    on_exit(fn ->
      File.rm_rf(dir)
    end)

    receiver_port = wait_for_port_file!(ready_file)

    assert {_sender_output, 0} =
             run_mix_script(Path.join(@repo_root, "scripts/tcp_sender.exs"), %{
               "MESHX_NODE_ID" => "sender",
               "MESHX_RECEIVER_ID" => "receiver",
               "MESHX_RECEIVER_PORT" => Integer.to_string(receiver_port),
               "MESHX_PAYLOAD" => "hello from another BEAM",
               "MESHX_STORE_DATA_DIR" => sender_store,
               "MESHX_TIMEOUT_MS" => "15000"
             })

    assert {_receiver_output, 0} = Task.await(receiver_task, 20_000)

    assert {"sender", _msg_id, "hello from another BEAM"} =
             payload_file |> File.read!() |> :erlang.binary_to_term()
  end

  defp run_mix_script(script, env) do
    env =
      [{"MIX_ENV", "test"} | Enum.to_list(env)]
      |> Enum.map(fn {key, value} -> {to_string(key), to_string(value)} end)

    System.cmd("mix", ["run", "--no-compile", script],
      cd: @repo_root,
      env: env,
      stderr_to_stdout: true
    )
  end

  defp wait_for_port_file!(path, attempts \\ 150)

  defp wait_for_port_file!(path, attempts) when attempts > 0 do
    case File.read(path) do
      {:ok, port} ->
        case Integer.parse(String.trim(port)) do
          {port, ""} ->
            port

          _not_ready ->
            Process.sleep(100)
            wait_for_port_file!(path, attempts - 1)
        end

      {:error, :enoent} ->
        Process.sleep(100)
        wait_for_port_file!(path, attempts - 1)
    end
  end

  defp wait_for_port_file!(path, 0) do
    flunk("receiver did not write ready file #{path}")
  end
end
