defmodule Mob.Node.BLE.AdvertGossipSimulatorTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    AdvertGossipPolicy,
    AdvertGossipSimulator,
    LocalInbox,
    Replay
  }

  @fixture_dir Path.expand("../../fixtures/captures", __DIR__)

  defp fixture(name), do: Path.join(@fixture_dir, name)

  defp inbox_from_fixture(name) do
    LocalInbox.new()
    |> LocalInbox.ingest_many(Replay.load!(fixture(name)))
  end

  defp sim_node(id, inbox \\ LocalInbox.new()), do: AdvertGossipSimulator.node(id, inbox)

  defp beacon_key(inbox) do
    %{unresolved_beacon_refs: [entry]} = LocalInbox.snapshot(inbox)
    {entry.message_id_hash, entry.sender_peer_hash}
  end

  test "replay-only simulation carries a beacon across two hops" do
    source = sim_node("A", inbox_from_fixture("legacy_beacon_advertisement.jsonl"))

    result =
      AdvertGossipSimulator.run(
        [source, sim_node("B"), sim_node("C")],
        %{"A" => ["B"], "B" => ["A", "C"], "C" => ["B"]},
        rounds: 3,
        ttl: 2,
        now: 1_000,
        policy: %AdvertGossipPolicy{min_interval_ms: 10_000, max_intents: 16}
      )

    assert [
             %{kind: :delivered, from_node_id: "A", to_node_id: "B", hop_count: 1},
             %{kind: :suppressed_loop, from_node_id: "B", to_node_id: "A"},
             %{kind: :delivered, from_node_id: "B", to_node_id: "C", hop_count: 2},
             %{kind: :ttl_expired, from_node_id: "C", to_node_id: "B"}
           ] = result.deliveries

    assert %{unresolved_beacon_refs: [_]} =
             result.nodes |> Map.fetch!("C") |> Map.fetch!(:inbox) |> LocalInbox.snapshot()
  end

  test "ttl stops propagation before the next hop" do
    source = sim_node("A", inbox_from_fixture("legacy_beacon_advertisement.jsonl"))

    result =
      AdvertGossipSimulator.run(
        [source, sim_node("B"), sim_node("C")],
        %{"A" => ["B"], "B" => ["A", "C"], "C" => ["B"]},
        rounds: 3,
        ttl: 1,
        now: 1_000,
        policy: %AdvertGossipPolicy{min_interval_ms: 0, max_intents: 16}
      )

    assert Enum.any?(result.deliveries, &match?(%{kind: :ttl_expired, from_node_id: "B"}, &1))

    assert %{unresolved_beacon_refs: []} =
             result.nodes |> Map.fetch!("C") |> Map.fetch!(:inbox) |> LocalInbox.snapshot()
  end

  test "policy default ttl is used when ttl option is omitted" do
    source = sim_node("A", inbox_from_fixture("legacy_beacon_advertisement.jsonl"))

    result =
      AdvertGossipSimulator.run(
        [source, sim_node("B"), sim_node("C")],
        %{"A" => ["B"], "B" => ["A", "C"], "C" => ["B"]},
        rounds: 3,
        now: 1_000,
        policy: %AdvertGossipPolicy{
          min_interval_ms: 10_000,
          max_intents: 16,
          default_ttl: 1,
          max_hops: 3,
          neighbor_cooldown_ms: 0
        }
      )

    assert Enum.any?(result.deliveries, &match?(%{kind: :ttl_expired, from_node_id: "B"}, &1))
  end

  test "neighbor cooldown suppresses repeat delivery attempts before duplicate checks" do
    source = sim_node("A", inbox_from_fixture("legacy_beacon_advertisement.jsonl"))

    result =
      AdvertGossipSimulator.run(
        [source, sim_node("B")],
        %{"A" => ["B"], "B" => ["A"]},
        rounds: 2,
        ttl: 2,
        now: 1_000,
        round_interval_ms: 100,
        policy: %AdvertGossipPolicy{
          min_interval_ms: 0,
          max_intents: 16,
          default_ttl: 2,
          max_hops: 4,
          neighbor_cooldown_ms: 1_000
        }
      )

    assert [
             %{kind: :delivered, from_node_id: "A", to_node_id: "B"},
             %{kind: :suppressed_neighbor_cooldown, from_node_id: "A", to_node_id: "B"},
             %{kind: :suppressed_loop, from_node_id: "B", to_node_id: "A"}
           ] = result.deliveries
  end

  test "malformed provenance is rejected and not forwarded" do
    inbox = inbox_from_fixture("legacy_beacon_advertisement.jsonl")
    key = beacon_key(inbox)

    source = %{
      sim_node("A", inbox)
      | provenance: %{
          key => %{
            origin_node_id: "A",
            hop_count: 3,
            ttl_remaining: 2,
            path: ["A"]
          }
        }
    }

    result =
      AdvertGossipSimulator.run(
        [source, sim_node("B")],
        %{"A" => ["B"]},
        rounds: 1,
        ttl: 2,
        now: 1_000,
        policy: %AdvertGossipPolicy{min_interval_ms: 0, max_intents: 16}
      )

    assert [%{kind: :invalid_provenance, from_node_id: "A", to_node_id: "B"}] =
             result.deliveries

    assert %{unresolved_beacon_refs: []} =
             result.nodes |> Map.fetch!("B") |> Map.fetch!(:inbox) |> LocalInbox.snapshot()
  end

  test "partitioned topology keeps unreachable nodes empty" do
    source = sim_node("A", inbox_from_fixture("legacy_beacon_advertisement.jsonl"))

    result =
      AdvertGossipSimulator.run(
        [source, sim_node("B"), sim_node("C"), sim_node("D")],
        %{"A" => ["B"], "B" => ["A"], "C" => ["D"], "D" => ["C"]},
        rounds: 3,
        ttl: 3,
        now: 1_000,
        policy: %AdvertGossipPolicy{min_interval_ms: 10_000, max_intents: 16}
      )

    assert Enum.any?(result.deliveries, &match?(%{kind: :delivered, to_node_id: "B"}, &1))

    assert %{unresolved_beacon_refs: []} =
             result.nodes |> Map.fetch!("C") |> Map.fetch!(:inbox) |> LocalInbox.snapshot()

    assert %{unresolved_beacon_refs: []} =
             result.nodes |> Map.fetch!("D") |> Map.fetch!(:inbox) |> LocalInbox.snapshot()
  end

  test "triangle topology suppresses duplicate loop observations deterministically" do
    source = sim_node("A", inbox_from_fixture("legacy_beacon_advertisement.jsonl"))

    result =
      AdvertGossipSimulator.run(
        [source, sim_node("B"), sim_node("C")],
        %{"A" => ["B", "C"], "B" => ["A", "C"], "C" => ["A", "B"]},
        rounds: 2,
        ttl: 2,
        now: 1_000,
        policy: %AdvertGossipPolicy{min_interval_ms: 0, max_intents: 16}
      )

    delivered_pairs =
      result.deliveries
      |> Enum.filter(&(&1.kind == :delivered))
      |> Enum.map(&{&1.from_node_id, &1.to_node_id})

    assert delivered_pairs == [{"A", "B"}, {"A", "C"}]
    assert Enum.any?(result.deliveries, &match?(%{kind: :suppressed_seen}, &1))
    assert Enum.any?(result.deliveries, &match?(%{kind: :suppressed_loop}, &1))
  end

  test "same inputs produce identical delivery ledger" do
    source = sim_node("A", inbox_from_fixture("legacy_beacon_advertisement.jsonl"))
    nodes = [source, sim_node("B"), sim_node("C")]
    links = %{"A" => ["B"], "B" => ["A", "C"], "C" => ["B"]}

    opts = [
      rounds: 3,
      ttl: 2,
      now: 1_000,
      policy: %AdvertGossipPolicy{min_interval_ms: 0, max_intents: 16}
    ]

    assert AdvertGossipSimulator.run(nodes, links, opts).deliveries ==
             AdvertGossipSimulator.run(nodes, links, opts).deliveries
  end
end
