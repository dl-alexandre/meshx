defmodule Mix.Tasks.Meshx.Mobile.Replay do
  @moduledoc """
  Replay a captured BLE v1 JSONL file into a fresh `MeshxMobileApp.Session`.

  Useful for manual debugging of session reactions to known captures
  without standing up hardware. Every line is decoded through
  `MeshxMobileApp.BLE.BridgeProtocol.decode/1` — the same path the
  Android/iOS adapters use in production.

  ## Usage

      mix meshx.mobile.replay test/fixtures/captures/cross_platform_discovery.jsonl

  Exits with status 0 on success, 1 on any decode failure. The session
  snapshot is printed to stdout once replay completes.
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.Replay
  alias MeshxMobileApp.Session

  @shortdoc "Replay a captured BLE v1 JSONL file into a fresh Session"

  @impl Mix.Task
  def run([path]) do
    unless File.exists?(path) do
      Mix.raise("capture file not found: #{path}")
    end

    {:ok, session} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)

    count =
      try do
        Replay.into(session, path)
      rescue
        e -> Mix.raise("replay failed: " <> Exception.message(e))
      end

    # snapshot/1 is a GenServer.call, which drains the mailbox up to the
    # call — by the time it returns, every replayed event has been
    # handled by Session.
    snapshot = Session.snapshot(session)

    Mix.shell().info("replayed #{count} events from #{path}")
    Mix.shell().info("status: #{snapshot.status}")
    Mix.shell().info("peer_id: #{inspect(snapshot.peer_id)}")
    Mix.shell().info("event log (most recent first):")

    Enum.each(snapshot.events, fn e ->
      Mix.shell().info("  [#{DateTime.to_iso8601(e.at)}] #{e.title} — #{e.detail}")
    end)
  end

  def run(_) do
    Mix.raise("Usage: mix meshx.mobile.replay <capture-file.jsonl>")
  end
end
