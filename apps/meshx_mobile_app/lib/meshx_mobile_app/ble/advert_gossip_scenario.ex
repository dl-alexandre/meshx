defmodule MeshxMobileApp.BLE.AdvertGossipScenario do
  @moduledoc """
  JSON-fixture runner for replay-only advert gossip scenarios.

  Scenario fixtures are small JSON files that name nodes, topology links,
  simulator policy, and expected delivery/inbox counts. They are an
  auditable layer over `AdvertGossipSimulator`; no live BLE, routing,
  persistence, retries, ACKs, crypto, or fragmentation is involved.
  """

  alias MeshxMobileApp.BLE.{
    AdvertGossipPolicy,
    AdvertGossipSimulator,
    LocalInbox,
    Replay
  }

  defmodule Report do
    @moduledoc false
    @enforce_keys [:scenario, :passed, :summary, :failures]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            scenario: binary(),
            passed: boolean(),
            summary: map(),
            failures: [binary()]
          }
  end

  @spec run_file!(Path.t()) :: Report.t()
  def run_file!(path) do
    scenario =
      path
      |> File.read!()
      |> :json.decode()

    scenario_dir = Path.dirname(path)
    run!(scenario, scenario_dir)
  end

  @spec run!(map(), Path.t()) :: Report.t()
  def run!(%{} = scenario, scenario_dir) do
    result =
      scenario
      |> nodes(scenario_dir)
      |> AdvertGossipSimulator.run(links(scenario), simulator_opts(scenario))

    summary = summarize(result)
    failures = compare(summary, Map.get(scenario, "expected", %{}))

    %Report{
      scenario: Map.fetch!(scenario, "name"),
      passed: failures == [],
      summary: summary,
      failures: failures
    }
  end

  defp nodes(%{"nodes" => nodes}, scenario_dir) when is_list(nodes) do
    Enum.map(nodes, fn %{"id" => id} = spec ->
      AdvertGossipSimulator.node(id, inbox(spec, scenario_dir))
    end)
  end

  defp inbox(%{"capture" => capture}, scenario_dir) do
    scenario_dir
    |> Path.join(capture)
    |> Path.expand()
    |> Replay.load!()
    |> then(&LocalInbox.ingest_many(LocalInbox.new(), &1))
  end

  defp inbox(_spec, _scenario_dir), do: LocalInbox.new()

  defp links(%{"links" => links}) when is_map(links), do: links
  defp links(_scenario), do: %{}

  defp simulator_opts(%{} = scenario) do
    policy = policy(Map.get(scenario, "policy", %{}))

    [
      rounds: Map.fetch!(scenario, "rounds"),
      ttl: Map.get(scenario, "ttl", policy.default_ttl),
      now: Map.get(scenario, "now", 0),
      round_interval_ms: Map.get(scenario, "round_interval_ms", 1_000),
      policy: policy
    ]
  end

  defp policy(%{} = attrs) do
    {:ok, policy} =
      AdvertGossipPolicy.new(
        min_interval_ms: Map.get(attrs, "min_interval_ms", 30_000),
        max_intents: Map.get(attrs, "max_intents", 16),
        default_ttl: Map.get(attrs, "default_ttl", 2),
        max_hops: Map.get(attrs, "max_hops", 4),
        neighbor_cooldown_ms: Map.get(attrs, "neighbor_cooldown_ms", 30_000)
      )

    policy
  end

  defp summarize(%AdvertGossipSimulator.Result{} = result) do
    %{
      "rounds" => result.rounds,
      "errors" => Enum.map(result.errors, &inspect/1),
      "delivery_counts" => delivery_counts(result.deliveries),
      "node_beacon_counts" => node_beacon_counts(result.nodes),
      "delivered_paths" => delivered_paths(result.deliveries)
    }
  end

  defp delivery_counts(deliveries) do
    deliveries
    |> Enum.frequencies_by(&Atom.to_string(&1.kind))
    |> Enum.sort()
    |> Map.new()
  end

  defp node_beacon_counts(nodes) do
    nodes
    |> Enum.map(fn {node_id, node} ->
      snapshot = LocalInbox.snapshot(node.inbox)
      {node_id, length(snapshot.unresolved_beacon_refs)}
    end)
    |> Enum.sort()
    |> Map.new()
  end

  defp delivered_paths(deliveries) do
    deliveries
    |> Enum.filter(&(&1.kind == :delivered))
    |> Enum.map(fn delivery ->
      %{
        "from" => delivery.from_node_id,
        "to" => delivery.to_node_id,
        "path" => delivery.path,
        "hop_count" => delivery.hop_count
      }
    end)
  end

  defp compare(summary, expected) do
    []
    |> compare_field(summary, expected, "delivery_counts")
    |> compare_field(summary, expected, "node_beacon_counts")
    |> compare_field(summary, expected, "delivered_paths")
  end

  defp compare_field(failures, summary, expected, field) do
    if Map.has_key?(expected, field) and Map.get(summary, field) != Map.fetch!(expected, field) do
      [
        "#{field} mismatch: expected #{inspect(Map.fetch!(expected, field))}, got #{inspect(Map.get(summary, field))}"
        | failures
      ]
    else
      failures
    end
  end
end
