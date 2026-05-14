defmodule MeshxMobileApp.BLE.BeaconFetchRequestTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.Events.ReceivedMessageBeacon
  alias MeshxMobileApp.BLE.{BeaconFetchRequest, BeaconRef, BeaconResolver, MessageEnvelope}

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
    event = %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: envelope.envelope_version,
      payload_kind: envelope.payload_type,
      message_id_hash: BeaconRef.message_id_hash(envelope),
      sender_peer_id_hash: BeaconRef.sender_peer_hash(envelope),
      received_device_id: "AA:BB:CC",
      received_at: 12_345,
      rssi: -58,
      raw_transport_metadata: %{}
    }

    {:ok, ref} = BeaconRef.from_event(event)
    ref
  end

  test "known envelope does not produce a fetch request" do
    envelope = envelope()
    resolver_result = BeaconResolver.resolve(ref_for(envelope), [envelope])

    assert {:error, :not_needed} =
             BeaconFetchRequest.from_resolver_result(resolver_result,
               now: 20_000,
               ttl_ms: 1_000
             )
  end

  test "unknown beacon becomes a deterministic auditable fetch intent" do
    envelope = envelope()
    resolver_result = BeaconResolver.resolve(ref_for(envelope), [])

    assert {:ok, request} =
             BeaconFetchRequest.from_resolver_result(resolver_result,
               now: 20_000,
               ttl_ms: 5_000,
               requesting_peer_id: "meshx-local",
               candidate_source_peer_ids: ["meshx-alpha", "meshx-relay"],
               id_fun: fn request ->
                 "fetch-#{Base.encode16(request.message_id_hash, case: :lower)}"
               end
             )

    assert request.request_id == "fetch-7c3ccd10bb7ec37b"
    assert request.message_id_hash == BeaconRef.message_id_hash(envelope)
    assert request.sender_peer_hash == BeaconRef.sender_peer_hash(envelope)
    assert request.requesting_peer_id == "meshx-local"
    assert request.candidate_source_peer_ids == ["meshx-alpha", "meshx-relay"]
    assert request.observed_at == 12_345
    assert request.expires_at == 25_000
    assert request.reason == :legacy_beacon_ref
  end

  test "empty candidate source list is allowed but explicit" do
    resolver_result = BeaconResolver.resolve(ref_for(envelope()), [])

    assert {:ok, request} =
             BeaconFetchRequest.from_resolver_result(resolver_result,
               now: 20_000,
               ttl_ms: 1_000,
               candidate_source_peer_ids: [],
               id_fun: fn _ -> "fetch-empty-candidates" end
             )

    assert request.candidate_source_peer_ids == []
  end

  test "malformed beacon does not produce a fetch request" do
    resolver_result =
      BeaconResolver.resolve(
        BeaconRef.new(
          envelope_version: 1,
          payload_kind: "TX",
          message_id_hash: <<1, 2>>,
          sender_peer_hash: <<0::64>>,
          observed_at: 1,
          received_device_id: "AA",
          rssi: -50
        ),
        []
      )

    assert {:error, :unresolvable_beacon} =
             BeaconFetchRequest.from_resolver_result(resolver_result,
               now: 20_000,
               ttl_ms: 1_000
             )
  end

  test "expired request validates as expired" do
    request = %BeaconFetchRequest{
      request_id: "fetch-1",
      message_id_hash: <<1::64>>,
      sender_peer_hash: <<2::64>>,
      requesting_peer_id: nil,
      candidate_source_peer_ids: [],
      observed_at: 12_345,
      expires_at: 20_000,
      reason: :legacy_beacon_ref
    }

    assert {:error, :expired} = BeaconFetchRequest.validate(request, now: 20_000)
  end

  test "ttl is bounded" do
    resolver_result = BeaconResolver.resolve(ref_for(envelope()), [])

    assert {:error, :ttl_too_large} =
             BeaconFetchRequest.from_resolver_result(resolver_result,
               now: 20_000,
               ttl_ms: BeaconFetchRequest.max_ttl_ms() + 1
             )
  end
end
