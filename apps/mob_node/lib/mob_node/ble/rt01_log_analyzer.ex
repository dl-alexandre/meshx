defmodule Mob.Node.BLE.RT01LogAnalyzer do
  @moduledoc """
  Analyzes RT-01 locked-phone direct delivery logs.

  Input may be raw `adb logcat` / Xcode console lines or already-stripped
  JSON lines. `MobAppEvent:` entries carry wall-clock `at_unix_ms`
  values and can prove whether receive/persistence evidence happened
  before the operator-recorded unlock time.
  """

  alias Mob.Node.BLE.Capture

  @locked_evidence_events MapSet.new([
                            {"receive", "authenticated_payload_received"},
                            {"receive", "mesh_message_received"},
                            {"receive", "mesh_message_beacon_received"},
                            {"store", "local_inbox_snapshot_saved"}
                          ])

  @post_unlock_resume_window_ms 10_000

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
          sustained_after_ms: integer() | nil,
          locked_persistence_evidence: [map()],
          capture_first_event_at_ms: integer() | nil,
          capture_last_event_at_ms: integer() | nil,
          capture_covers_window?: boolean() | nil,
          receive_events_in_window: non_neg_integer(),
          unique_message_hashes_in_window: non_neg_integer(),
          first_receive_delta_ms: integer() | nil,
          last_receive_delta_ms: integer() | nil,
          receive_events_after_60s: non_neg_integer(),
          receive_events_after_5m: non_neg_integer(),
          unique_after_60s: non_neg_integer(),
          unique_after_5m: non_neg_integer(),
          post_unlock_resume_window_ms: non_neg_integer(),
          post_unlock_receive_events: non_neg_integer(),
          post_unlock_unique_message_hashes: non_neg_integer(),
          first_post_unlock_receive_delta_ms: integer() | nil,
          last_post_unlock_receive_delta_ms: integer() | nil,
          missing: [binary()]
        }

  @spec analyze_file(Path.t(), keyword()) :: analysis()
  def analyze_file(path, opts \\ []) do
    path
    |> File.stream!(:line)
    |> analyze_lines(opts)
  end

  @spec analyze_lines(Enumerable.t(), keyword()) :: analysis()
  def analyze_lines(lines, opts \\ []) do
    locked_from_ms = parse_time_ms(Keyword.get(opts, :locked_from_ms))
    unlock_at_ms = parse_time_ms(Keyword.get(opts, :unlock_at_ms))
    sustained_after_ms = normalize_sustained(Keyword.get(opts, :sustained_after_ms))

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

    # Strict gating only applies when both the lock-start reference and a
    # sustained threshold are known; otherwise the analyzer keeps the legacy
    # "any in-window evidence" gate so callers without those inputs are unchanged.
    strict? = is_integer(sustained_after_ms) and is_integer(locked_from_ms)
    span = capture_span(app_events)
    coverage = capture_coverage(span, locked_from_ms, unlock_at_ms)
    window = window_metrics(evidence, locked_from_ms)

    sustained =
      if strict?, do: sustained_evidence(evidence, locked_from_ms, sustained_after_ms), else: []

    post_unlock = post_unlock_resume_metrics(evidence_events, unlock_at_ms)

    missing = missing_requirements(app_events, unlock_at_ms, strict?, coverage)

    %{
      status: status(missing, evidence, evidence_events, sustained, strict?),
      run_ids: run_ids(app_events),
      total_lines: parsed.total_lines,
      parsed_events: length(app_events) + length(native_events),
      app_events: length(app_events),
      native_events: length(native_events),
      malformed_events: parsed.malformed_events,
      locked_from_ms: locked_from_ms,
      unlock_at_ms: unlock_at_ms,
      sustained_after_ms: sustained_after_ms,
      capture_first_event_at_ms: span.first,
      capture_last_event_at_ms: span.last,
      capture_covers_window?: coverage,
      locked_persistence_evidence: evidence,
      receive_events_in_window: window.count,
      unique_message_hashes_in_window: window.unique,
      first_receive_delta_ms: window.first_delta,
      last_receive_delta_ms: window.last_delta,
      receive_events_after_60s: window.after_60s,
      receive_events_after_5m: window.after_5m,
      unique_after_60s: window.unique_after_60s,
      unique_after_5m: window.unique_after_5m,
      post_unlock_resume_window_ms: @post_unlock_resume_window_ms,
      post_unlock_receive_events: post_unlock.count,
      post_unlock_unique_message_hashes: post_unlock.unique,
      first_post_unlock_receive_delta_ms: post_unlock.first_delta,
      last_post_unlock_receive_delta_ms: post_unlock.last_delta,
      missing: missing
    }
  end

  defp normalize_sustained(nil), do: nil
  defp normalize_sustained(ms) when is_integer(ms) and ms <= 0, do: nil
  defp normalize_sustained(ms) when is_integer(ms), do: ms

  defp normalize_sustained(value) when is_binary(value),
    do: value |> parse_time_ms() |> normalize_sustained()

  defp normalize_sustained(_other), do: nil

  # Receive evidence that landed at least `after_ms` into the locked window —
  # the signal that the scan/receive path is still alive deep into screen-off,
  # not just an opening burst before Android suspends background scans.
  defp sustained_evidence(evidence, locked_from_ms, after_ms) do
    Enum.filter(evidence, fn ev ->
      case delta_ms(ev, locked_from_ms) do
        nil -> false
        delta -> delta >= after_ms
      end
    end)
  end

  defp window_metrics(evidence, locked_from_ms) do
    deltas =
      evidence
      |> Enum.map(&delta_ms(&1, locked_from_ms))
      |> Enum.reject(&is_nil/1)

    %{
      count: length(evidence),
      unique:
        evidence |> Enum.map(&message_hash/1) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> length(),
      first_delta: Enum.min(deltas, fn -> nil end),
      last_delta: Enum.max(deltas, fn -> nil end),
      after_60s: count_after(evidence, locked_from_ms, 60_000),
      after_5m: count_after(evidence, locked_from_ms, 300_000),
      unique_after_60s: unique_after(evidence, locked_from_ms, 60_000),
      unique_after_5m: unique_after(evidence, locked_from_ms, 300_000)
    }
  end

  defp count_after(evidence, locked_from_ms, after_ms),
    do: evidence |> sustained_evidence(locked_from_ms, after_ms) |> length()

  defp unique_after(evidence, locked_from_ms, after_ms) do
    evidence
    |> sustained_evidence(locked_from_ms, after_ms)
    |> Enum.map(&message_hash/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> length()
  end

  defp capture_span(app_events) do
    timestamps =
      app_events
      |> Enum.map(& &1["at_unix_ms"])
      |> Enum.filter(&is_integer/1)

    %{
      first: Enum.min(timestamps, fn -> nil end),
      last: Enum.max(timestamps, fn -> nil end)
    }
  end

  defp capture_coverage(_span, nil, _unlock_at_ms), do: nil
  defp capture_coverage(_span, _locked_from_ms, nil), do: nil
  defp capture_coverage(%{first: nil}, _locked_from_ms, _unlock_at_ms), do: false

  defp capture_coverage(%{first: first, last: last}, locked_from_ms, unlock_at_ms) do
    first <= locked_from_ms and last >= unlock_at_ms
  end

  defp post_unlock_resume_metrics(_evidence_events, nil), do: empty_post_unlock_metrics()

  defp post_unlock_resume_metrics(evidence_events, unlock_at_ms) do
    resume =
      Enum.filter(evidence_events, fn event ->
        at = event["at_unix_ms"]

        is_integer(at) and at >= unlock_at_ms and
          at <= unlock_at_ms + @post_unlock_resume_window_ms
      end)

    deltas =
      resume
      |> Enum.map(&(&1["at_unix_ms"] - unlock_at_ms))
      |> Enum.reject(&is_nil/1)

    %{
      count: length(resume),
      unique:
        resume |> Enum.map(&message_hash/1) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> length(),
      first_delta: Enum.min(deltas, fn -> nil end),
      last_delta: Enum.max(deltas, fn -> nil end)
    }
  end

  defp empty_post_unlock_metrics do
    %{
      count: 0,
      unique: 0,
      first_delta: nil,
      last_delta: nil
    }
  end

  defp delta_ms(%{at_unix_ms: at} = _ev, locked_from_ms)
       when is_integer(at) and is_integer(locked_from_ms),
       do: at - locked_from_ms

  defp delta_ms(_ev, _locked_from_ms), do: nil

  defp message_hash(%{metadata: md}) when is_map(md), do: message_hash(md)
  defp message_hash(%{"metadata" => md}) when is_map(md), do: message_hash(md)
  defp message_hash(md) when is_map(md), do: md["message_id_hash"] || md["message_id"]

  defp message_hash(_ev), do: nil

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
          {:ok, %{"schema" => "mob_rt_event.v1"} = event} ->
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

  defp missing_requirements(app_events, unlock_at_ms, strict?, coverage) do
    []
    |> maybe_missing(unlock_at_ms == nil, "unlock_at_ms")
    |> maybe_missing(app_events == [], "MobAppEvent lines")
    |> maybe_missing(strict? and coverage == false, "capture_coverage")
  end

  defp maybe_missing(missing, true, requirement), do: [requirement | missing]
  defp maybe_missing(missing, false, _requirement), do: missing

  # Missing prerequisites always wins.
  defp status(missing, _evidence, _evidence_events, _sustained, _strict?) when missing != [],
    do: :inconclusive

  # Strict RT-01 gate: a pass requires receive evidence sustained into the locked
  # window. An opening burst that then goes silent (the background-scan-freeze
  # signature) is a fail, not a pass.
  defp status([], evidence, evidence_events, sustained, true) do
    cond do
      sustained != [] -> :pass
      evidence != [] -> :fail
      evidence_events != [] -> :fail
      true -> :inconclusive
    end
  end

  # Legacy gate (no sustained threshold / lock reference): any in-window evidence passes.
  defp status([], [_ | _], _evidence_events, _sustained, false), do: :pass
  defp status([], [], [_ | _], _sustained, false), do: :fail
  defp status([], [], [], _sustained, false), do: :inconclusive

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
