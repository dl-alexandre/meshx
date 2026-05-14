defmodule Mix.Tasks.Meshx.Mobile.LocalReadiness.Audit do
  @moduledoc """
  Audits local BLE mesh project readiness.

      mix meshx.mobile.local_readiness.audit
      mix meshx.mobile.local_readiness.audit --allow-open
      mix meshx.mobile.local_readiness.audit --allow-open --json
      mix meshx.mobile.local_readiness.audit --allow-open --out tmp/readiness.json

  By default this task exits nonzero while any project readiness item
  remains open. Use `--allow-open` for development/status reporting.
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.LocalProjectReadiness

  @shortdoc "Audit local BLE mesh project readiness"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)

    snapshot = LocalProjectReadiness.snapshot()
    json = snapshot |> json_snapshot() |> JSON.encode!()

    maybe_write_json(json, opts.out_path)
    print_snapshot(snapshot, json, opts.json?)

    if snapshot.open_item_count > 0 and not opts.allow_open? do
      Mix.raise("local BLE mesh project readiness has #{snapshot.open_item_count} open items")
    end
  end

  defp parse_args(args) do
    parse_args(args, %{allow_open?: false, json?: false, out_path: nil})
  end

  defp parse_args([], opts), do: opts

  defp parse_args(["--allow-open" | rest], opts),
    do: parse_args(rest, %{opts | allow_open?: true})

  defp parse_args(["--json" | rest], opts), do: parse_args(rest, %{opts | json?: true})

  defp parse_args(["--out", path | rest], opts) when is_binary(path) and path != "",
    do: parse_args(rest, %{opts | out_path: path})

  defp parse_args(["--out"], _opts), do: Mix.raise("missing path for --out")
  defp parse_args([unknown | _rest], _opts), do: Mix.raise("unknown option(s): #{unknown}")

  defp maybe_write_json(_json, nil), do: :ok

  defp maybe_write_json(json, path) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(path, json <> "\n")
  end

  defp print_snapshot(_snapshot, json, true), do: Mix.shell().info(json)

  defp print_snapshot(snapshot, _json, false) do
    Mix.shell().info(
      "OPEN #{snapshot.open_item_count} blocked #{snapshot.blocked_item_count} partial #{snapshot.partial_item_count} not_started #{snapshot.not_started_item_count}"
    )

    Enum.each(snapshot.open_items, fn item ->
      Mix.shell().info("#{String.upcase(to_string(item.status))} #{item.id}")

      Enum.each(item.remaining_work, fn work ->
        Mix.shell().info("  need: #{work}")
      end)
    end)
  end

  defp json_snapshot(snapshot) do
    %{
      open_item_count: snapshot.open_item_count,
      blocked_item_count: snapshot.blocked_item_count,
      partial_item_count: snapshot.partial_item_count,
      not_started_item_count: snapshot.not_started_item_count,
      notes: snapshot.notes,
      open_items: Enum.map(snapshot.open_items, &json_item/1)
    }
  end

  defp json_item(item) do
    %{
      id: item.id,
      status: item.status,
      current_evidence: item.current_evidence,
      remaining_work: item.remaining_work,
      notes: item.notes
    }
  end
end
