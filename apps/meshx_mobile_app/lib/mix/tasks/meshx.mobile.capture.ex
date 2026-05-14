defmodule Mix.Tasks.Meshx.Mobile.Capture do
  @moduledoc """
  Capture BLE v1 events to a newline-delimited JSON file.

  Reads `adb logcat` output (or any text stream) from STDIN, strips
  the logcat prefix, and writes the trailing JSON payloads to a
  timestamped capture file. One event per line. No transformation
  beyond prefix-stripping — captured payloads are preserved verbatim.

  ## Usage

      adb -s <serial> logcat -s MeshxBle:I | mix meshx.mobile.capture
      mix meshx.mobile.capture < existing-logcat.txt
      mix meshx.mobile.capture --output captures/run-42.jsonl

  ## Options

    * `--output <path>` — explicit output path. Default:
      `priv/captures/<UTC-timestamp>.jsonl`.
    * `--quiet` — suppress per-line stderr progress markers.
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.Capture

  @shortdoc "Captures BLE v1 logcat output to a JSONL file"

  @impl Mix.Task
  def run(argv) do
    {opts, _argv} =
      OptionParser.parse!(argv,
        strict: [output: :string, quiet: :boolean]
      )

    path = opts[:output] || default_output_path()
    File.mkdir_p!(Path.dirname(path))

    quiet? = opts[:quiet] || false
    Mix.shell().info("capturing → #{path}")

    {count, errors} =
      :stdio
      |> IO.stream(:line)
      |> Stream.map(&Capture.from_logcat_line/1)
      |> Stream.reject(&is_nil/1)
      |> Enum.reduce({0, 0}, fn json, {ok, err} ->
        case validate(json) do
          :ok ->
            File.write!(path, json <> "\n", [:append])
            unless quiet?, do: IO.write(:stderr, ".")
            {ok + 1, err}

          {:error, _reason} ->
            unless quiet?, do: IO.write(:stderr, "x")
            {ok, err + 1}
        end
      end)

    unless quiet?, do: IO.write(:stderr, "\n")
    Mix.shell().info("wrote #{count} events (#{errors} malformed lines skipped) to #{path}")
  end

  defp default_output_path do
    Path.join(["priv", "captures", Capture.timestamped_filename()])
  end

  # Validate that the line at least parses as JSON. Schema validation
  # happens later, in `Replay.load!/1` via `BridgeProtocol.decode/1`.
  # Keeping this lax here means a single bad line doesn't poison a long
  # capture session.
  defp validate(json) do
    _ = :json.decode(json)
    :ok
  rescue
    _ -> {:error, :invalid_json}
  end
end
