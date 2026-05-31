defmodule Mob.Node.BLE.Capture do
  @moduledoc """
  Capture-file format helpers for BLE v1 events.

  A capture file is **newline-delimited JSON**: one v1 wire-format event
  per line, exactly as emitted by `dev.mob.mob.ble.BleEvent.toJsonObject()`
  on Android (and, in the future, by the iOS bridge once its NIF emits
  v1 directly). Binary fields are carried as base64 strings — same as
  the static fixtures under `test/fixtures/android_wire_v1/`.

  Two helpers:

    * `from_logcat_line/1` strips the `adb logcat` prefix (timestamp,
      pid, level, tag) and returns the trailing JSON payload, or nil
      if the line isn't a `MobBle:` native event or a
      `MobAppEvent:` reliability event.
    * `timestamped_filename/1` returns a stable, sortable filename for
      a fresh capture session.

  Persistence beyond writing the capture file itself is out of scope —
  no database, no replication. The mix task uses these helpers and
  appends to a single file.
  """

  @logcat_markers ["MobBle: ", "MobAppEvent: "]

  @doc """
  Extracts the JSON payload from an `adb logcat -s MobBle:I` line.

  Returns the trailing JSON binary, or `nil` for non-MobBle lines.
  Idempotent: a line that's already a bare JSON payload passes through
  unchanged so that running this on already-stripped input is safe.
  """
  @spec from_logcat_line(String.t()) :: String.t() | nil
  def from_logcat_line(line) when is_binary(line) do
    trimmed = String.trim(line)

    cond do
      trimmed == "" ->
        nil

      String.starts_with?(trimmed, "{") ->
        trimmed

      marker = Enum.find(@logcat_markers, &String.contains?(trimmed, &1)) ->
        trailing_json(trimmed, marker)

      true ->
        nil
    end
  end

  defp trailing_json(line, marker) do
    [_, payload] = String.split(line, marker, parts: 2)

    payload
    |> String.trim()
    |> case do
      "" -> nil
      s -> s
    end
  end

  @doc """
  Sortable UTC capture filename, e.g. `20260511T214700Z.jsonl`.
  """
  @spec timestamped_filename(DateTime.t()) :: String.t()
  def timestamped_filename(%DateTime{} = at \\ DateTime.utc_now()) do
    at
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601(:basic)
    |> Kernel.<>(".jsonl")
  end
end
