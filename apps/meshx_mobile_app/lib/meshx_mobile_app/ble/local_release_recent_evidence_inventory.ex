defmodule MeshxMobileApp.BLE.LocalReleaseRecentEvidenceInventory do
  @moduledoc """
  Recent local evidence inventory for release-candidate review.

  This collects the latest no-new-hardware evidence slices that can support
  advert-only release traceability while keeping completion, delivery, trust,
  routing, background, iOS parity, and full-resolution claims blocked. It is
  release-planning data only: it does not inspect hardware, scan, advertise,
  fetch, route, persist, ACK, retry, encrypt, authenticate, or run background
  work.
  """

  defmodule Item do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :status,
               :source,
               :supports,
               :does_not_support,
               :required_review
             ]}
    @enforce_keys [:id, :status, :source, :supports, :does_not_support, :required_review]
    defstruct @enforce_keys
  end

  @items [
    %{
      id: :nearby_messages_selected_detail_copy,
      status: :implemented_needs_operator_evidence,
      source: "LocalInboxProductSurface.selected_detail_summary",
      supports: [:nearby_messages_state_copy],
      does_not_support: [:production_ux_approval, :delivery, :trusted_delivery],
      required_review: :nearby_messages_ux_review
    },
    %{
      id: :durable_snapshot_schema_policy,
      status: :implemented_policy_evidence,
      source: "LocalInboxDurableSnapshotSchemaPolicy",
      supports: [:json_decoded_v1_snapshot_restore_policy],
      does_not_support: [:default_app_persistence, :migration_complete, :delivery_record],
      required_review: :production_persistence_review
    },
    %{
      id: :beacon_reference_security_risk,
      status: :implemented_negative_evidence,
      source: "LocalSecurityBeaconReferenceRisk",
      supports: [:hash_reference_boundary],
      does_not_support: [:authenticated_peer_identity, :authenticated_message, :trusted_message],
      required_review: :security_release_review
    },
    %{
      id: :local_routing_dry_run,
      status: :implemented_dry_run_evidence,
      source: "LocalRoutingDryRun",
      supports: [:route_candidate_dry_run_evidence],
      does_not_support: [:route_selection_available, :live_forwarding_service, :routed_delivery],
      required_review: :production_routing_review
    },
    %{
      id: :foreground_manual_lifecycle_session,
      status: :implemented_foreground_evidence,
      source: "LocalLifecycleManualSession",
      supports: [:foreground_manual_lifecycle_evidence],
      does_not_support: [
        :android_foreground_service_ble,
        :background_ble_operation,
        :automatic_ble_restart
      ],
      required_review: :mobile_lifecycle_hardware_review
    },
    %{
      id: :ios_native_source_inventory,
      status: :implemented_source_inventory,
      source: "LocalIOSNativeSourceInventory",
      supports: [:ios_foreground_observe_source_inventory],
      does_not_support: [
        :ios_hardware_participation,
        :ios_legacy_beacon_gossip,
        :ios_parity_claim
      ],
      required_review: :ios_parity_hardware_review
    }
  ]

  @blocked_claims [
    :whole_project_complete,
    :message_delivery,
    :trusted_delivery,
    :routed_delivery,
    :background_operation,
    :ios_parity,
    :full_message_resolution
  ]

  @spec items() :: [Item.t()]
  def items, do: Enum.map(@items, &struct!(Item, &1))

  @spec snapshot() :: map()
  def snapshot do
    items = items()

    %{
      inventory_version: 1,
      boundary: :local_release_recent_evidence_inventory,
      release_candidate_complete?: false,
      item_count: length(items),
      items: items,
      required_reviews: items |> Enum.map(& &1.required_review) |> Enum.uniq() |> Enum.sort(),
      blocked_claims: @blocked_claims,
      notes: [
        "Recent evidence slices improve release review traceability but do not close operator evidence gates.",
        "Every listed item must still flow through its objective-specific review before release wording changes.",
        "Hardware-blocked objectives remain blocked by the completion audit."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end
end
