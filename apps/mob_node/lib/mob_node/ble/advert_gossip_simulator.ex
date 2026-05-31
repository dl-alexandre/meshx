defmodule Mob.Node.BLE.AdvertGossipSimulator do
  @moduledoc """
  Replay-only multi-hop advertisement gossip simulator.

  The simulator feeds canonical `received_message_beacon` events into
  `LocalInbox` instances while keeping gossip TTL, hop count, and path
  provenance in simulation state. It does not send BLE advertisements,
  route live traffic, persist state, retry, ACK, encrypt, fragment, or
  claim message delivery.
  """

  alias Mob.Node.BLE.{
    AdvertGossipLedger,
    AdvertGossipPlanner,
    AdvertGossipPolicy,
    BeaconInbox,
    BeaconRef,
    FullEnvelopeInbox,
    LocalInbox
  }

  alias Mob.Node.BLE.Events.ReceivedMessageBeacon

  defmodule Node do
    @moduledoc false
    @enforce_keys [:node_id]
    defstruct node_id: nil,
              inbox: LocalInbox.new(),
              ledger: AdvertGossipLedger.new(),
              provenance: %{},
              neighbor_last_sent_at: %{}

    @type t :: %__MODULE__{
            node_id: binary(),
            inbox: LocalInbox.t(),
            ledger: AdvertGossipLedger.t(),
            provenance: %{
              {binary(), binary()} => %{
                origin_node_id: binary(),
                hop_count: non_neg_integer(),
                ttl_remaining: non_neg_integer(),
                path: [binary()]
              }
            },
            neighbor_last_sent_at: %{{{binary(), binary()}, binary()} => integer()}
          }
  end

  defmodule Delivery do
    @moduledoc false
    @enforce_keys [
      :round,
      :kind,
      :from_node_id,
      :to_node_id,
      :message_id_hash,
      :sender_peer_hash,
      :hop_count,
      :ttl_remaining,
      :path
    ]
    defstruct @enforce_keys

    @type kind ::
            :delivered
            | :suppressed_seen
            | :suppressed_loop
            | :suppressed_neighbor_cooldown
            | :ttl_expired
            | :max_hops_exceeded
            | :invalid_provenance

    @type t :: %__MODULE__{
            round: pos_integer(),
            kind: kind(),
            from_node_id: binary(),
            to_node_id: binary(),
            message_id_hash: binary(),
            sender_peer_hash: binary(),
            hop_count: non_neg_integer(),
            ttl_remaining: non_neg_integer(),
            path: [binary()]
          }
  end

  defmodule Result do
    @moduledoc false
    defstruct nodes: %{}, deliveries: [], rounds: 0, errors: []

    @type t :: %__MODULE__{
            nodes: %{binary() => Node.t()},
            deliveries: [Delivery.t()],
            rounds: non_neg_integer(),
            errors: [term()]
          }
  end

  @type key :: {binary(), binary()}

  @type provenance :: %{
          origin_node_id: binary(),
          hop_count: non_neg_integer(),
          ttl_remaining: non_neg_integer(),
          path: [binary()]
        }

  @type opts :: [
          rounds: pos_integer(),
          ttl: pos_integer(),
          now: integer(),
          round_interval_ms: pos_integer(),
          policy: AdvertGossipPolicy.t()
        ]

  @spec node(binary(), LocalInbox.t()) :: Node.t()
  def node(node_id, %LocalInbox{} = inbox), do: %Node{node_id: node_id, inbox: inbox}

  @spec run([Node.t()], %{binary() => [binary()]}, opts()) :: Result.t()
  def run(nodes, links, opts) when is_list(nodes) and is_map(links) do
    rounds = Keyword.fetch!(opts, :rounds)
    now = Keyword.get(opts, :now, 0)
    round_interval_ms = Keyword.get(opts, :round_interval_ms, 1_000)
    policy = Keyword.get(opts, :policy, AdvertGossipPolicy.default())
    ttl = Keyword.get(opts, :ttl, policy.default_ttl)

    with :ok <- AdvertGossipPolicy.validate(policy),
         :ok <- validate_run_opts(rounds, ttl, round_interval_ms, policy) do
      do_run(nodes, links, rounds, ttl, now, round_interval_ms, policy)
    else
      {:error, reason} ->
        %Result{
          nodes: Map.new(nodes, fn %Node{node_id: node_id} = node -> {node_id, node} end),
          deliveries: [],
          rounds: 0,
          errors: [reason]
        }
    end
  end

  defp do_run(nodes, links, rounds, ttl, now, round_interval_ms, policy) do
    initial_nodes =
      nodes
      |> Map.new(fn %Node{node_id: node_id} = node -> {node_id, seed_provenance(node, ttl)} end)

    {final_nodes, deliveries} =
      Enum.reduce(1..rounds, {initial_nodes, []}, fn round, {node_map, acc} ->
        round_now = now + (round - 1) * round_interval_ms
        {next_nodes, round_deliveries} = simulate_round(node_map, links, policy, round, round_now)
        {next_nodes, acc ++ round_deliveries}
      end)

    %Result{nodes: final_nodes, deliveries: deliveries, rounds: rounds}
  end

  defp validate_run_opts(rounds, ttl, round_interval_ms, %AdvertGossipPolicy{} = policy) do
    cond do
      not is_integer(rounds) or rounds < 1 ->
        {:error, :invalid_rounds}

      not is_integer(ttl) or ttl < 1 ->
        {:error, :invalid_ttl}

      ttl > policy.max_hops ->
        {:error, :ttl_exceeds_max_hops}

      not is_integer(round_interval_ms) or round_interval_ms < 1 ->
        {:error, :invalid_round_interval_ms}

      true ->
        :ok
    end
  end

  defp seed_provenance(%Node{} = node, ttl) do
    snapshot = LocalInbox.snapshot(node.inbox)

    provenance =
      snapshot
      |> seed_full_messages(node.node_id, ttl, node.provenance)
      |> then(&seed_beacon_refs(snapshot, node.node_id, ttl, &1))

    %{node | provenance: provenance}
  end

  defp seed_full_messages(snapshot, node_id, ttl, provenance) do
    Enum.reduce(snapshot.full_messages, provenance, fn %FullEnvelopeInbox.Entry{} = entry, acc ->
      key =
        {BeaconRef.message_id_hash(entry.envelope), BeaconRef.sender_peer_hash(entry.envelope)}

      Map.put_new(acc, key, origin(node_id, ttl))
    end)
  end

  defp seed_beacon_refs(snapshot, node_id, ttl, provenance) do
    Enum.reduce(snapshot.unresolved_beacon_refs, provenance, fn %BeaconInbox.Entry{} = entry,
                                                                acc ->
      key = {entry.message_id_hash, entry.sender_peer_hash}
      Map.put_new(acc, key, origin(node_id, ttl))
    end)
  end

  defp origin(node_id, ttl) do
    %{origin_node_id: node_id, hop_count: 0, ttl_remaining: ttl, path: [node_id]}
  end

  defp simulate_round(node_map, links, policy, round, now) do
    start_nodes = node_map

    start_nodes
    |> Map.keys()
    |> Enum.sort()
    |> Enum.reduce({node_map, []}, fn node_id, {next_nodes, acc} ->
      node = Map.fetch!(start_nodes, node_id)
      snapshot = LocalInbox.snapshot(node.inbox)

      intents =
        AdvertGossipPlanner.plan(snapshot,
          now: now,
          policy: policy,
          ledger: node.ledger,
          id_fun: fn index -> "#{node_id}-round-#{round}-#{index}" end
        )

      node = %{node | ledger: AdvertGossipLedger.record(node.ledger, intents)}
      next_nodes = Map.update!(next_nodes, node_id, &%{&1 | ledger: node.ledger})

      {updated_nodes, deliveries} =
        intents
        |> Enum.filter(&(&1.advertise_as == :legacy_beacon_advert))
        |> Enum.reduce({next_nodes, []}, fn intent, {inner_nodes, inner_acc} ->
          neighbors = links |> Map.get(node_id, []) |> Enum.sort()

          Enum.reduce(neighbors, {inner_nodes, inner_acc}, fn neighbor_id,
                                                              {neighbor_nodes, neighbor_acc} ->
            deliver(intent, node, neighbor_id, neighbor_nodes, policy, round, now, neighbor_acc)
          end)
        end)

      {updated_nodes, acc ++ deliveries}
    end)
  end

  defp deliver(intent, from_node, to_node_id, nodes, policy, round, now, deliveries) do
    key = {intent.message_id_hash, intent.sender_peer_hash}
    from_node_id = from_node.node_id
    to_node = Map.fetch!(nodes, to_node_id)
    provenance = Map.get(from_node.provenance, key)

    cond do
      not valid_provenance?(provenance, from_node_id, policy) ->
        {nodes,
         deliveries ++
           [delivery(:invalid_provenance, intent, from_node_id, to_node_id, provenance, round)]}

      provenance.ttl_remaining <= 0 ->
        {nodes,
         deliveries ++
           [delivery(:ttl_expired, intent, from_node_id, to_node_id, provenance, round)]}

      provenance.hop_count >= policy.max_hops ->
        {nodes,
         deliveries ++
           [delivery(:max_hops_exceeded, intent, from_node_id, to_node_id, provenance, round)]}

      to_node_id in provenance.path ->
        {nodes,
         deliveries ++
           [delivery(:suppressed_loop, intent, from_node_id, to_node_id, provenance, round)]}

      neighbor_suppressed?(from_node, key, to_node_id, now, policy.neighbor_cooldown_ms) ->
        {nodes,
         deliveries ++
           [
             delivery(
               :suppressed_neighbor_cooldown,
               intent,
               from_node_id,
               to_node_id,
               provenance,
               round
             )
           ]}

      Map.has_key?(to_node.provenance, key) ->
        {nodes,
         deliveries ++
           [delivery(:suppressed_seen, intent, from_node_id, to_node_id, provenance, round)]}

      true ->
        received_provenance = %{
          origin_node_id: provenance.origin_node_id,
          hop_count: provenance.hop_count + 1,
          ttl_remaining: provenance.ttl_remaining - 1,
          path: provenance.path ++ [to_node_id]
        }

        event = beacon_event(intent, from_node_id, to_node_id, now, received_provenance)

        updated_to_node = %{
          to_node
          | inbox: LocalInbox.ingest(to_node.inbox, event),
            provenance: Map.put(to_node.provenance, key, received_provenance)
        }

        updated_nodes = Map.put(nodes, to_node_id, updated_to_node)
        updated_nodes = record_neighbor_send(updated_nodes, from_node_id, key, to_node_id, now)

        {updated_nodes,
         deliveries ++
           [delivery(:delivered, intent, from_node_id, to_node_id, received_provenance, round)]}
    end
  end

  defp valid_provenance?(provenance, node_id, %AdvertGossipPolicy{} = policy) do
    is_map(provenance) and
      is_binary(provenance[:origin_node_id]) and
      is_integer(provenance[:hop_count]) and
      provenance[:hop_count] >= 0 and
      provenance[:hop_count] <= policy.max_hops and
      is_integer(provenance[:ttl_remaining]) and
      provenance[:ttl_remaining] >= 0 and
      is_list(provenance[:path]) and
      provenance[:path] != [] and
      Enum.all?(provenance[:path], &is_binary/1) and
      List.last(provenance[:path]) == node_id and
      length(provenance[:path]) == provenance[:hop_count] + 1 and
      hd(provenance[:path]) == provenance[:origin_node_id]
  end

  defp neighbor_suppressed?(_node, _key, _to_node_id, _now, 0), do: false

  defp neighbor_suppressed?(%Node{} = node, key, to_node_id, now, cooldown_ms) do
    case Map.get(node.neighbor_last_sent_at, {key, to_node_id}) do
      nil -> false
      sent_at -> now - sent_at < cooldown_ms
    end
  end

  defp record_neighbor_send(nodes, from_node_id, key, to_node_id, now) do
    Map.update!(nodes, from_node_id, fn %Node{} = node ->
      %{
        node
        | neighbor_last_sent_at: Map.put(node.neighbor_last_sent_at, {key, to_node_id}, now)
      }
    end)
  end

  defp beacon_event(intent, from_node_id, to_node_id, now, provenance) do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: intent.envelope_version,
      payload_kind: intent.payload_kind,
      message_id_hash: intent.message_id_hash,
      sender_peer_id_hash: intent.sender_peer_hash,
      received_device_id: from_node_id,
      received_at: now,
      rssi: -60,
      raw_transport_metadata: %{
        transport: :advert_gossip_simulation,
        source_event: :received_message_beacon,
        received_device_id: from_node_id,
        simulated_receiver_node_id: to_node_id,
        gossip_origin_node_id: provenance.origin_node_id,
        gossip_hop_count: provenance.hop_count,
        gossip_ttl_remaining: provenance.ttl_remaining,
        gossip_path: provenance.path
      }
    }
  end

  defp delivery(kind, intent, from_node_id, to_node_id, provenance, round) do
    %Delivery{
      round: round,
      kind: kind,
      from_node_id: from_node_id,
      to_node_id: to_node_id,
      message_id_hash: intent.message_id_hash,
      sender_peer_hash: intent.sender_peer_hash,
      hop_count: provenance_field(provenance, :hop_count, 0),
      ttl_remaining: provenance_field(provenance, :ttl_remaining, 0),
      path: provenance_field(provenance, :path, [])
    }
  end

  defp provenance_field(provenance, key, default) when is_map(provenance),
    do: Map.get(provenance, key, default)

  defp provenance_field(_provenance, _key, default), do: default
end
