defmodule MeshxMobileApp.BLE.RT01LogAnalyzer do
  @moduledoc """
  Analyzes RT-01 locked-phone direct delivery logs.

  Input may be raw `adb logcat` / Xcode console lines or already-stripped
  JSON lines. `MeshxAppEvent:` entries carry wall-clock `at_unix_ms`
  values and can prove whether receive/persistence evidence happened
  before the operator-recorded unlock time.
  """

  alias MeshxMobileApp.BLE.Capture

  @locked_evidence_events MapSet.new([
                            {"receive", "authenticated_payload_received"},
                            {"receive", "mesh_message_received"},
                            {"receive", "mesh_message_beacon_received"},
                            {"store", "local_inbox_snapshot_saved"}
                          ])

  @type analysis :: %{
          status: :pass | :fail | :inconclusive,
          run_ids: [binary()],
          total_lines: non_neg_integer(),
          parsed_events: non_neg_integer(),
          app_events: non_neg_integer(),
          native_events: non_neg_integer(),
          malformed_events: non_neg_integer(),
          locked_from_ms: integer() | nil,
          unlock_at_ms: integer() | nil,
          locked_persistence_evidence: [map()],
          missing: [binary()]
        }

  @spec analyze_file(Path.t(), keyword()) :: analysis()
  def analyze_file(path, opts \\ []) do
    path
    |> File.stream!([], :line)
    |> analyze_lines(opts)
  end

  @spec analyze_lines(Enumerable.t(), keyword()) :: analysis()
  def analyze_lines(lines, opts \\ []) do
    locked_from_ms = parse_time_ms(Keyword.get(opts, :locked_from_ms))
    unlock_at_ms = parse_time_ms(Keyword.get(opts, :unlock_at_ms))

    parsed =
      lines
      |> Enum.with_index(1)
      |> Enum.reduce(empty_parse(), fn {line, line_no}, acc -> parse_line(line, line_no, acc) end)

    app_events = Enum.reverse(parsed.app_events)
    native_events = Enum.reverse(parsed.native_events)

    evidence_events = Enum.filter(app_events, &persistence_evidence_event?/1)

    evidence =
      evidence_events
      |> Enum.filter(&locked_persistence_evidence?(&1, locked_from_ms, unlock_at_ms))
      |> Enum.map(&evidence_summary/1)

    missing = missing_requirements(app_events, unlock_at_ms)

    %{
      status: status(missing, evidence, evidence_events),
      run_ids: run_ids(app_events),
      total_lines: parsed.total_lines,
      parsed_events: length(app_events) + length(native_events),
      app_events: length(app_events),
      native_events: length(native_events),
      malformed_events: parsed.malformed_events,
      locked_from_ms: locked_from_ms,
      unlock_at_ms: unlock_at_ms,
      locked_persistence_evidence: evidence,
      missing: missing
    }
  end

  @spec parse_time_ms(nil | integer() | binary()) :: integer() | nil
  def parse_time_ms(nil), do: nil
  def parse_time_ms(value) when is_integer(value), do: value

  def parse_time_ms(value) when is_binary(value) do
    value = String.trim(value)

    case Integer.parse(value) do
      {ms, ""} ->
        ms

      _other ->
        case DateTime.from_iso8601(value) do
          {:ok, dt, _offset} -> DateTime.to_unix(dt, :millisecond)
          _error -> nil
        end
    end
  end

  defp parse_line(line, line_no, acc) do
    acc = %{acc | total_lines: acc.total_lines + 1}

    case Capture.from_logcat_line(line) do
      nil ->
        acc

      json ->
        case decode(json) do
          {:ok, %{"schema" => "meshx_rt_event.v1"} = event} ->
            %{acc | app_events: [put_line(event, line_no) | acc.app_events]}

          {:ok, %{} = event} ->
            %{acc | native_events: [put_line(event, line_no) | acc.native_events]}

          {:error, _reason} ->
            %{acc | malformed_events: acc.malformed_events + 1}
        end
    end
  end

  defp decode(json) do
    {:ok, :json.decode(json)}
  rescue
    error -> {:error, error}
  end

  defp put_line(event, line_no), do: Map.put(event, "_line", line_no)

  defp locked_persistence_evidence?(event, locked_from_ms, unlock_at_ms) do
    at_ms = event["at_unix_ms"]

    persistence_evidence_event?(event) and is_integer(at_ms) and
      before_unlock?(at_ms, unlock_at_ms) and after_lock_start?(at_ms, locked_from_ms)
  end

  defp persistence_evidence_event?(event) do
    MapSet.member?(@locked_evidence_events, {event["phase"], event["event"]})
  end

  defp before_unlock?(_at_ms, nil), do: false
  defp before_unlock?(at_ms, unlock_at_ms), do: at_ms < unlock_at_ms

  defp after_lock_start?(_at_ms, nil), do: true
  defp after_lock_start?(at_ms, locked_from_ms), do: at_ms >= locked_from_ms

  defp evidence_summary(event) do
    %{
      line: event["_line"],
      at_unix_ms: event["at_unix_ms"],
      phase: event["phase"],
      event: event["event"],
      run_id: event["run_id"],
      metadata: Map.get(event, "metadata", %{})
    }
  end

  defp missing_requirements(app_events, unlock_at_ms) do
    []
    |> maybe_missing(unlock_at_ms == nil, "unlock_at_ms")
    |> maybe_missing(app_events == [], "MeshxAppEvent lines")
  end

  defp maybe_missing(missing, true, requirement), do: [requirement | missing]
  defp maybe_missing(missing, false, _requirement), do: missing

  defp status([], [_ | _], _evidence_events), do: :pass
  defp status([], [], [_ | _]), do: :fail
  defp status(_missing, _evidence, _evidence_events), do: :inconclusive

  defp run_ids(app_events) do
    app_events
    |> Enum.map(& &1["run_id"])
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp empty_parse do
    %{
      total_lines: 0,
      app_events: [],
      native_events: [],
      malformed_events: 0
    }
  end
end
