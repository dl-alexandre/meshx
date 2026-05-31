defmodule Mob.Node.BLE.BeaconFetchTransportTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    BeaconFetchProtocol,
    BeaconFetchRequest,
    BeaconFetchTransport,
    BeaconRef,
    BeaconResolver,
    EnvelopeCache,
    MessageEnvelope
  }

  defp envelope(opts \\ []) do
    {:ok, envelope} =
      MessageEnvelope.build(
        Keyword.merge(
          [
            message_id: <<1::128>>,
            sender_peer_id: "meshx-alpha",
            recipient_peer_id: "meshx-beta",
            created_at: 1_700_000_000_000,
            ttl: 1,
            payload_type: "TX",
            payload: "hi",
            capability_requirements: 0
          ],
          opts
        )
      )

    envelope
  end

  defp ref_for(envelope) do
    {:ok, ref} =
      BeaconRef.new(
        envelope_version: envelope.envelope_version,
        payload_kind: envelope.payload_type,
        message_id_hash: BeaconRef.message_id_hash(envelope),
        sender_peer_hash: BeaconRef.sender_peer_hash(envelope),
        observed_at: 12_345,
        received_device_id: "AA:BB",
        rssi: -57
      )

    ref
  end

  test "fetch request and response round-trip deterministically" do
    envelope = envelope()
    {:needs_fetch, resolver_request} = BeaconResolver.resolve(ref_for(envelope), [])

    {:ok, fetch_request} =
      BeaconFetchRequest.from_resolver_result({:needs_fetch, resolver_request},
        now: 20_000,
        ttl_ms: 5_000,
        requesting_peer_id: "meshx-beta",
        candidate_source_peer_ids: ["meshx-alpha"],
        id_fun: fn _ -> "fetch-1" end
      )

    {:ok, request_message} = BeaconFetchProtocol.request_from_fetch_request(fetch_request)
    wire_request = BeaconFetchProtocol.encode_request(request_message)
    assert {:ok, ^request_message} = BeaconFetchProtocol.decode_request(wire_request)

    {:ok, response} =
      BeaconFetchProtocol.response(
        request_id: "fetch-1",
        message_id_hash: fetch_request.message_id_hash,
        responder_peer_id: "meshx-alpha",
        status: :ok,
        envelope: envelope
      )

    wire_response = BeaconFetchProtocol.encode_response(response)
    assert {:ok, ^response} = BeaconFetchProtocol.decode_response(wire_response)
  end

  test "envelope cache supports insert, hit, miss, expiry, and overwrite" do
    envelope = envelope()
    replacement = envelope(payload: "new")
    hash = BeaconRef.message_id_hash(envelope)

    cache = EnvelopeCache.new(max_entries: 2, ttl_ms: 100)
    assert :miss = EnvelopeCache.get(cache, hash, now: 0)

    cache = EnvelopeCache.put(cache, envelope, now: 10)
    assert {:ok, ^envelope} = EnvelopeCache.get(cache, hash, now: 50)
    assert :expired = EnvelopeCache.get(cache, hash, now: 110)

    cache = EnvelopeCache.put(cache, replacement, now: 120)
    assert {:ok, ^replacement} = EnvelopeCache.get(cache, hash, now: 121)
    assert %{entries: entries} = EnvelopeCache.prune(cache, now: 221)
    assert entries == %{}
  end

  test "fake transport returns envelope from responder cache" do
    envelope = envelope()
    cache = EnvelopeCache.new() |> EnvelopeCache.put(envelope, now: 0)
    {:needs_fetch, resolver_request} = BeaconResolver.resolve(ref_for(envelope), [])

    {:ok, fetch_request} =
      BeaconFetchRequest.from_resolver_result({:needs_fetch, resolver_request},
        now: 1,
        ttl_ms: 1_000,
        id_fun: fn _ -> "fetch-1" end
      )

    {:ok, request_message} = BeaconFetchProtocol.request_from_fetch_request(fetch_request)

    assert {:ok, %{status: :ok, envelope: ^envelope}} =
             BeaconFetchTransport.Fake.exchange(request_message, cache,
               responder_peer_id: "meshx-alpha",
               now: 2
             )
  end

  test "beacon to fetch request to fake response resolves the full envelope" do
    envelope = envelope()
    requester_cache = EnvelopeCache.new()
    responder_cache = EnvelopeCache.new() |> EnvelopeCache.put(envelope, now: 0)

    {:needs_fetch, resolver_request} = BeaconResolver.resolve(ref_for(envelope), [])

    {:ok, fetch_request} =
      BeaconFetchRequest.from_resolver_result({:needs_fetch, resolver_request},
        now: 10,
        ttl_ms: 1_000,
        requesting_peer_id: "meshx-beta",
        candidate_source_peer_ids: ["meshx-alpha"],
        id_fun: fn _ -> "fetch-1" end
      )

    {:ok, request_message} = BeaconFetchProtocol.request_from_fetch_request(fetch_request)

    assert {:ok, response} =
             BeaconFetchTransport.Fake.exchange(request_message, responder_cache,
               responder_peer_id: "meshx-alpha",
               now: 11
             )

    assert response.status == :ok
    assert response.envelope == envelope

    requester_cache = EnvelopeCache.put(requester_cache, response.envelope, now: 12)

    assert {:already_known, ^envelope} =
             BeaconResolver.resolve(ref_for(envelope), [response.envelope])

    assert {:ok, ^envelope} =
             EnvelopeCache.get(requester_cache, fetch_request.message_id_hash, now: 12)
  end

  test "fake transport emits not_found for cache miss" do
    envelope = envelope()
    {:needs_fetch, resolver_request} = BeaconResolver.resolve(ref_for(envelope), [])

    {:ok, fetch_request} =
      BeaconFetchRequest.from_resolver_result({:needs_fetch, resolver_request},
        now: 1,
        ttl_ms: 1_000,
        id_fun: fn _ -> "fetch-1" end
      )

    {:ok, request_message} = BeaconFetchProtocol.request_from_fetch_request(fetch_request)

    assert {:ok, %{status: :not_found, reason: :not_found, envelope: nil}} =
             BeaconFetchTransport.Fake.exchange(request_message, EnvelopeCache.new(),
               responder_peer_id: "meshx-alpha",
               now: 2
             )
  end
end
