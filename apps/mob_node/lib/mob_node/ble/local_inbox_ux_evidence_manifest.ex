defmodule Mob.Node.BLE.LocalInboxUxEvidenceManifest do
  @moduledoc """
  Machine-readable Nearby Messages UX evidence manifest.

  The manifest packages pure surface coverage and the on-device validation
  plan for the current advertisement-only local mesh UX. It is an artifact
  shape only. It does not render UI, drive devices, scan, advertise, fetch,
  route, persist, ACK, retry, encrypt, or run background work.
  """

  alias Mob.Node.BLE.{
    LocalInbox,
    LocalInboxNativeSurface,
    LocalInboxUxAcceptance,
    LocalInboxUxDecisionScenarioPlan,
    LocalInboxUxOperatorCapturePlan,
    LocalInboxUxTargetDeviceScenarioPlan,
    LocalInboxUxValidationPlan,
    LocalInboxView,
    MessageEnvelope
  }

  alias Mob.Node.BLE.Events.{ReceivedMessage, ReceivedMessageBeacon}

  @fixture_now 100
  @fixture_stale_after_ms 10

  @required_commands [
    "mix mob.node.local_inbox.ux_validation_plan --json --out <path>",
    "mix mob.node.local_inbox.ux_evidence --json --out <path>",
    "mix mob.node.local_inbox.ux_review --template --out <path>",
    "mix mob.node.local_inbox.ux_review --input <path> --json --out <path>",
    "mix test apps/mob_node/test/mob_node/ble/local_inbox_ux_acceptance_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_inbox_ux_decision_scenario_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_inbox_ux_validation_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_inbox_ux_operator_capture_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_inbox_ux_target_device_scenario_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_inbox_query_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_inbox_product_surface_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_inbox_native_surface_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_inbox_presenter_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_inbox_state_copy_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_inbox_resolution_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_inbox_action_summary_test.exs",
    "mix test apps/mob_node/test/mob_node/home_screen_test.exs"
  ]

  @spec snapshot() :: map()
  def snapshot do
    inbox = fixture_snapshot()
    surface = LocalInboxNativeSurface.build(inbox, fixture_freshness_opts())
    acceptance = LocalInboxUxAcceptance.snapshot(inbox, fixture_freshness_opts())
    validation_plan = LocalInboxUxValidationPlan.snapshot()

    %{
      manifest_version: 1,
      boundary: :nearby_messages_ux_evidence_manifest,
      fixture_freshness_policy: fixture_freshness_policy(),
      production_ux_claim_allowed?: false,
      delivery_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      routing_claim_allowed?: false,
      fixture: fixture_summary(inbox),
      surface: surface_summary(surface),
      detail_evidence: detail_evidence(inbox, surface),
      affordance_review: affordance_review(surface),
      ux_decision_scenario_plan: LocalInboxUxDecisionScenarioPlan.snapshot(),
      operator_capture_plan: LocalInboxUxOperatorCapturePlan.snapshot(),
      target_device_scenario_plan: LocalInboxUxTargetDeviceScenarioPlan.snapshot(),
      acceptance: acceptance,
      validation_plan: validation_plan,
      required_commands: @required_commands,
      required_artifacts: required_artifacts(),
      missing_on_device_evidence: missing_on_device_evidence(validation_plan),
      blocked_claims: [
        :production_nearby_messages_ux,
        :delivery,
        :trusted_delivery,
        :routing,
        :background_operation
      ],
      notes: [
        "Pure surface coverage is necessary but not on-device UX evidence.",
        "The fixture covers full message, unresolved ref, gossiped ref, and stale ref states.",
        "Production UX claims remain blocked until operator screenshots or notes with evidence_kind classification satisfy LocalInboxUxValidationPlan."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp fixture_summary(inbox) do
    %{
      nearby_message_count: length(inbox.nearby_messages),
      states: inbox.nearby_messages |> Enum.map(& &1.state) |> Enum.uniq(),
      full_message_count: length(inbox.full_messages),
      unresolved_beacon_ref_count: length(inbox.unresolved_beacon_refs)
    }
  end

  defp surface_summary(surface) do
    %{
      title: surface.title,
      summary_line: surface.summary_line,
      row_count: length(surface.rows),
      states: surface.rows |> Enum.map(& &1.state) |> Enum.uniq(),
      filter_summary: surface.filter_summary,
      sort_summary: surface.sort_summary,
      filter_count: length(surface.state_filters),
      sort_count: length(surface.sort_options),
      sort_descriptions: Enum.map(surface.sort_options, &Map.take(&1, [:sort, :description])),
      sections: section_summary(surface.sections),
      row_blocked_claims: row_blocked_claims(surface.rows),
      row_trust_decisions: row_trust_decisions(surface.rows),
      warning_count: length(surface.warnings),
      detail_status: detail_status(surface.detail),
      empty?: surface.empty?
    }
  end

  defp section_summary(sections) do
    Enum.map(sections, fn section ->
      %{
        state: section.state,
        label: section.label,
        count: section.count,
        empty_label: section.empty_label,
        row_states: Enum.map(section.rows, & &1.state)
      }
    end)
  end

  defp detail_evidence(inbox, surface) do
    Enum.map(surface.rows, fn row ->
      selected =
        LocalInboxNativeSurface.build(
          inbox,
          Keyword.put(fixture_freshness_opts(), :detail_message_key, row.message_key)
        )

      detail = selected.detail

      %{
        state: row.state,
        message_key: row.message_key,
        freshness_policy: fixture_freshness_policy(),
        status: Map.get(detail, :status),
        detail_title: Map.get(detail, :detail_title),
        identifier_lines: identifier_lines(detail),
        observed_via: Map.get(detail, :observed_via, []),
        delivery_claim_allowed?: Map.get(detail, :delivery_claim_allowed?, false),
        blocked_claims: Map.get(detail, :blocked_claims, []),
        limitation_present?: present?(Map.get(detail, :limitation)),
        next_action_present?: present?(Map.get(detail, :next_action))
      }
    end)
  end

  defp affordance_review(surface) do
    detail_states = surface.rows |> Enum.map(& &1.state) |> Enum.uniq() |> Enum.sort()

    %{
      review_version: 1,
      boundary: :nearby_messages_affordance_review,
      # state_filters/sort_options are typed `[map(), ...]` (non-empty list)
      # — the surface always exposes them. Boolean preserved for downstream
      # consumers that key off the contract.
      filter_controls_present?: match?([_ | _], surface.state_filters),
      sort_controls_present?: match?([_ | _], surface.sort_options),
      selected_detail_states: detail_states,
      selected_detail_state_count: length(detail_states),
      selected_detail_all_states_covered?:
        Enum.sort([:full_message, :unresolved_ref, :gossiped_ref, :stale_ref]) == detail_states,
      filter_summary: surface.filter_summary,
      sort_summary: surface.sort_summary,
      blocked_claim_copy_states:
        surface.rows
        |> Enum.filter(&(&1.blocked_claims != []))
        |> Enum.map(& &1.state)
        |> Enum.uniq()
        |> Enum.sort(),
      delivery_claim_allowed?: false,
      production_ux_claim_allowed?: false,
      notes: [
        "Affordance review is pure surface evidence, not target-device UX proof.",
        "Operator evidence still needs screenshots or notes with evidence_kind classification."
      ]
    }
  end

  defp identifier_lines(%{detail_lines: detail_lines}) when is_list(detail_lines) do
    Enum.filter(detail_lines, fn line ->
      String.starts_with?(line, "Message ID:") or
        String.starts_with?(line, "Message hash:") or
        String.starts_with?(line, "Sender:") or
        String.starts_with?(line, "Sender hash:")
    end)
  end

  defp identifier_lines(_detail), do: []

  defp present?(value), do: is_binary(value) and byte_size(value) > 0

  defp fixture_freshness_opts do
    [now: @fixture_now, stale_after_ms: @fixture_stale_after_ms]
  end

  defp fixture_freshness_policy do
    %{
      now: @fixture_now,
      stale_after_ms: @fixture_stale_after_ms,
      purpose: "Classify stale beacon refs consistently across rows and selected details."
    }
  end

  defp row_blocked_claims(rows) do
    rows
    |> Enum.map(fn row ->
      %{
        state: row.state,
        blocked_claims: row.blocked_claims
      }
    end)
  end

  defp row_trust_decisions(rows) do
    rows
    |> Enum.map(fn row ->
      %{
        state: row.state,
        trust_summary: row.trust_summary,
        trusted_message?: row.trusted_message?,
        delivery_claim_allowed?: row.delivery_claim_allowed?
      }
    end)
  end

  defp detail_status(nil), do: :unselected
  defp detail_status(%{status: status}), do: status

  defp missing_on_device_evidence(validation_plan) do
    Enum.map(validation_plan.gates, fn gate ->
      %{
        gate_id: gate.id,
        required_evidence: gate.required_evidence,
        acceptance_criteria: gate.acceptance_criteria,
        blocked_claims: gate.blocked_claims
      }
    end)
  end

  defp required_artifacts do
    [
      %{
        id: :ux_validation_plan,
        command: "mix mob.node.local_inbox.ux_validation_plan --json --out <path>",
        purpose: "Archive the on-device UX validation checklist before operator evidence review."
      },
      %{
        id: :ux_evidence_manifest,
        command: "mix mob.node.local_inbox.ux_evidence --json --out <path>",
        purpose: "Archive Nearby Messages surface coverage and open on-device validation gates."
      },
      %{
        id: :ux_decision_scenario_plan,
        command: "mix mob.node.local_inbox.ux_evidence --json --out <path>",
        source: "LocalInboxUxDecisionScenarioPlan",
        purpose:
          "Archive keep_pure_surface_evidence_only and promote_nearby_messages_production_ux decision scenarios before any production UX wording changes."
      },
      %{
        id: :ux_evidence_template,
        command: "mix mob.node.local_inbox.ux_review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for target-device UX attachments."
      },
      %{
        id: :ux_operator_capture_plan,
        source: "LocalInboxUxOperatorCapturePlan",
        purpose:
          "Archive the target-device capture checklist for states, interactions, selected details, copy review, and visual density before operator evidence is attached."
      },
      %{
        id: :ux_target_device_scenario_plan,
        source: "LocalInboxUxTargetDeviceScenarioPlan",
        purpose:
          "Archive concrete target-device UX scenarios for state rows, filters, sorting, selected details, copy review, and visual density before operator evidence is attached."
      },
      %{
        id: :ux_evidence_review,
        command: "mix mob.node.local_inbox.ux_review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied target-device, state, interaction, selected-detail, copy, and density evidence metadata."
      },
      %{
        id: :target_device_screenshots,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/ux/",
        purpose:
          "Attach target-device screenshots or operator notes for full, unresolved, gossiped, stale, interaction, and selected-detail states, with evidence_kind declared for each state, interaction, and selected-detail artifact."
      },
      %{
        id: :blocked_claim_copy_review,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/ux/copy-review.md",
        purpose:
          "Document that visible Nearby Messages copy does not claim delivery, trust, routing, or background behavior, and captures evidence_kind, control summaries, selected_detail_evidence limitation_copy, next_action_copy, blocked_claim_copy, selected_detail_evidence coverage, and per-state blocked-claim copy."
      }
    ]
  end

  defp fixture_snapshot do
    base =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event())
      |> LocalInbox.ingest(beacon_event())
      |> LocalInbox.ingest(gossiped_beacon_event())
      |> LocalInbox.ingest(stale_beacon_event())
      |> LocalInbox.snapshot()

    Map.put(
      base,
      :nearby_messages,
      LocalInboxView.nearby_messages(base, now: 100, stale_after_ms: 10)
    )
  end

  defp full_event do
    envelope = envelope()

    %ReceivedMessage{
      message_id: envelope.message_id,
      sender_peer_id: envelope.sender_peer_id,
      recipient_peer_id: envelope.recipient_peer_id,
      received_device_id: "AA:01",
      received_at: 100,
      rssi: -60,
      envelope: envelope,
      raw_transport_metadata: %{}
    }
  end

  defp beacon_event do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: 1,
      payload_kind: "TX",
      message_id_hash: <<2, 2, 2, 2, 2, 2, 2, 2>>,
      sender_peer_id_hash: <<3, 3, 3, 3, 3, 3, 3, 3>>,
      received_device_id: "AA:02",
      received_at: 90,
      rssi: -70,
      raw_transport_metadata: %{}
    }
  end

  defp gossiped_beacon_event do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: 1,
      payload_kind: "TX",
      message_id_hash: <<6, 6, 6, 6, 6, 6, 6, 6>>,
      sender_peer_id_hash: <<7, 7, 7, 7, 7, 7, 7, 7>>,
      received_device_id: "AA:04",
      received_at: 95,
      rssi: -50,
      raw_transport_metadata: %{transport: :advert_gossip_simulation}
    }
  end

  defp stale_beacon_event do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: 1,
      payload_kind: "AL",
      message_id_hash: <<4, 4, 4, 4, 4, 4, 4, 4>>,
      sender_peer_id_hash: <<5, 5, 5, 5, 5, 5, 5, 5>>,
      received_device_id: "AA:03",
      received_at: 1,
      rssi: -90,
      raw_transport_metadata: %{}
    }
  end

  defp envelope do
    {:ok, envelope} =
      MessageEnvelope.build(
        message_id: <<1::128>>,
        sender_peer_id: "meshx-alpha",
        recipient_peer_id: "meshx-beta",
        created_at: 1_700_000_000_000,
        ttl: 1,
        payload_type: "TX",
        payload: "hello",
        capability_requirements: 0
      )

    envelope
  end
end
