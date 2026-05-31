defmodule Mob.Node.BLE.Replay do
  @moduledoc """
  Deterministic replay of captured v1 BLE events into any process that
  understands `Mob.Node.BLE.Adapter` event messages (today: `Session`).

  ## Why

  Capture/replay decouples Session-level testing from physical hardware.
  Every replayed line enters the runtime through the same path a live
  Android or iOS adapter uses — `Mob.Node.BLE.Adapter.event_message/1`,
  which routes through `Mob.Node.BLE.BridgeProtocol.decode/1`. The
  decode contract is therefore exercised end-to-end on every replay; no
  separate "test path" exists.

  ## File format

  Newline-delimited JSON. One v1 wire-format event per line. Blank lines
  and lines starting with `#` are ignored so curated fixtures can carry
  inline annotations. Binary fields (`advertisement`, `payload`) are
  base64-encoded — this module handles the base64 → binary step
  uniformly so `BridgeProtocol.decode/1` sees the same shape it sees
  when the future NIF transport delivers raw binaries.

  ## What this is not

  No persistence beyond the capture file. No mesh routing, no peer
  graph, no crypto. Adapters remain dumb; this module never calls them.
  """

  alias Mob.Node.BLE.Adapter

  @binary_fields [
    "advertisement",
    "payload",
    "envelope",
    "message_id",
    "message_id_hash",
    "sender_peer_id_hash"
  ]
  @metadata_binary_fields [
    "advertisement",
    "message_payload",
    "manufacturer_data",
    "beacon_payload"
  ]

  @type raw :: map()

  @doc """
  Lazily streams raw v1 payloads from a capture file.

  Each emitted value is a string-keyed map with binary fields already
  base64-decoded into Elixir binaries — ready to feed into
  `Adapter.event_message/1`.
  """
  @spec stream_raw(Path.t()) :: Enumerable.t()
  def stream_raw(path) do
    path
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&skip_line?/1)
    |> Stream.map(&decode_json_line/1)
  end

  @doc """
  Eagerly loads a capture file into a list of canonical event structs.

  Decodes each line through `BridgeProtocol.decode/1`. Any line that
  fails to decode raises — capture files are checked into the repo and
  must round-trip cleanly. Use `stream_raw/1` if you need to tolerate
  malformed lines.
  """
  @spec load!(Path.t()) :: [Mob.Node.BLE.Event.t()]
  def load!(path) do
    path
    |> stream_raw()
    |> Enum.map(fn raw ->
      case Mob.Node.BLE.BridgeProtocol.decode(raw) do
        {:ok, event} -> event
        {:error, reason} -> raise "replay decode failed at #{path}: #{inspect(reason)}"
      end
    end)
  end

  @doc """
  Replays a capture file (or pre-loaded raw stream) into a target
  process by sending canonical `Mob.Node.BLE.Adapter` messages.

  The target process must implement the standard adapter event message
  handler — `Session` does. Sends are synchronous from the caller's
  perspective; the target's `handle_info` runs asynchronously, so test
  code should synchronize with the target (e.g. `Session.snapshot/1`,
  which is a `GenServer.call` and therefore drains the mailbox to that
  point) before asserting.
  """
  @spec into(pid() | atom(), Path.t() | Enumerable.t()) :: non_neg_integer()
  def into(target, path) when is_binary(path) do
    into(target, stream_raw(path))
  end

  def into(target, stream) do
    Enum.reduce(stream, 0, fn raw, count ->
      send(target, Adapter.event_message(raw))
      count + 1
    end)
  end

  # ── helpers ────────────────────────────────────────────────────────────────

  defp skip_line?(""), do: true
  defp skip_line?("#" <> _), do: true
  defp skip_line?(_), do: false

  defp decode_json_line(line) do
    line
    |> :json.decode()
    |> base64_binary_fields()
  end

  # Walks the top-level map and base64-decodes any well-known binary
  # field. Keeps unknown fields untouched so future contract additions
  # don't require code changes here.
  defp base64_binary_fields(%{} = map) do
    map
    |> decode_top_level_binary_fields()
    |> decode_raw_transport_metadata()
  end

  defp decode_top_level_binary_fields(map) do
    Enum.reduce(@binary_fields, map, fn key, acc ->
      case Map.get(acc, key) do
        s when is_binary(s) -> Map.put(acc, key, Base.decode64!(s))
        _ -> acc
      end
    end)
  end

  defp decode_raw_transport_metadata(%{"raw_transport_metadata" => %{} = metadata} = map) do
    decoded =
      Enum.reduce(@metadata_binary_fields, metadata, fn key, acc ->
        case Map.get(acc, key) do
          s when is_binary(s) -> Map.put(acc, key, Base.decode64!(s))
          _ -> acc
        end
      end)

    Map.put(map, "raw_transport_metadata", decoded)
  end

  defp decode_raw_transport_metadata(map), do: map
end
