defmodule Mob.Node.BLE.LocalLifecycleNegativeValidation do
  @moduledoc """
  Negative validation matrix for mobile BLE lifecycle claims.

  The current validated lifecycle is foreground/manual. This module records
  cases that must remain blocked from background, restart, scheduled retry,
  or background gossip claims. It does not start services, request background
  modes, schedule work, scan, advertise, route, persist, ACK, retry, fetch,
  encrypt, or run background work.
  """

  defmodule Case do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :input,
               :blocked_claims,
               :expected_decision,
               :required_before_allowed,
               :notes
             ]}
    @enforce_keys [
      :id,
      :input,
      :blocked_claims,
      :expected_decision,
      :required_before_allowed,
      :notes
    ]
    defstruct @enforce_keys
  end

  @cases [
    %{
      id: :manual_foreground_scan_as_background,
      input: :foreground_manual_scan_or_advertise,
      blocked_claims: [
        :android_foreground_service_ble,
        :background_ble_operation,
        :background_delivery
      ],
      expected_decision: :foreground_only,
      required_before_allowed: [
        :android_manifest_service_declaration,
        :foreground_service_permission,
        :notification_policy,
        :hardware_backgrounding_evidence
      ],
      notes: [
        "Manual foreground start/stop is not Android foreground-service behavior.",
        "Foreground validation does not prove app-backgrounding behavior."
      ]
    },
    %{
      id: :android_background_without_os_evidence,
      input: :android_background_ble_claim,
      blocked_claims: [
        :android_background_scan,
        :android_background_advertise,
        :os_throttling_safe_behavior
      ],
      expected_decision: :background_claim_rejected,
      required_before_allowed: [
        :background_scan_policy,
        :background_advertise_policy,
        :permission_and_notification_policy,
        :battery_and_throttling_bounds,
        :hardware_logs
      ],
      notes: [
        "No Android background BLE policy or hardware logs exist.",
        "OS throttling, battery, and permission behavior are unproven."
      ]
    },
    %{
      id: :ios_bridge_shell_as_background,
      input: :ios_bridge_contract_only,
      blocked_claims: [
        :ios_background_scan,
        :ios_background_advertise,
        :ios_parity_background
      ],
      expected_decision: :platform_blocked,
      required_before_allowed: [
        :ios_background_capability_selection,
        :core_bluetooth_background_policy,
        :ios_bridge_background_events,
        :replay_normalized_hardware_capture
      ],
      notes: [
        "The iOS bridge shell is not iOS background BLE behavior.",
        "iOS background claims require real capability and hardware evidence."
      ]
    },
    %{
      id: :manual_restart_as_automatic_restart,
      input: :manual_stop_start,
      blocked_claims: [
        :automatic_ble_restart,
        :operator_invisible_restart,
        :retry_backed_delivery
      ],
      expected_decision: :manual_only,
      required_before_allowed: [
        :restart_trigger_policy,
        :cancellation_policy,
        :backoff_without_delivery_claims,
        :operator_visible_restart_status,
        :failure_surface
      ],
      notes: [
        "Manual stop/start is not automatic restart.",
        "Restart behavior must not imply retry-backed delivery."
      ]
    },
    %{
      id: :fetch_request_intent_as_scheduled_retry,
      input: :beacon_fetch_request_or_failed_transport_intent,
      blocked_claims: [
        :scheduled_retry,
        :retry_backed_delivery,
        :background_ble_operation,
        :background_delivery
      ],
      expected_decision: :fetch_intent_only,
      required_before_allowed: [
        :scheduled_work_policy,
        :retry_backoff_policy,
        :cancellation_policy,
        :operator_visible_retry_status,
        :hardware_lifecycle_logs
      ],
      notes: [
        "Beacon fetch requests and failed transport attempts are one-shot intents, not scheduled retry work.",
        "Retry or delivery wording requires explicit lifecycle policy, scheduling evidence, and hardware logs."
      ]
    },
    %{
      id: :foreground_gossip_as_background_gossip,
      input: :foreground_one_hop_advert_gossip,
      blocked_claims: [
        :background_gossip,
        :background_forwarding,
        :background_delivery
      ],
      expected_decision: :foreground_gossip_only,
      required_before_allowed: [
        :background_gossip_rate_limits,
        :ttl_and_loop_policy,
        :battery_budget,
        :platform_background_constraints,
        :hardware_validation_without_delivery_claims
      ],
      notes: [
        "Foreground one-hop advert gossip does not prove background gossip.",
        "Background gossip requires rate, battery, OS, and hardware evidence."
      ]
    }
  ]

  @spec cases() :: [Case.t()]
  def cases, do: Enum.map(@cases, &struct!(Case, &1))

  @spec snapshot() :: map()
  def snapshot do
    cases = cases()

    %{
      validation_version: 1,
      boundary: :current_foreground_manual_lifecycle,
      cases: cases,
      case_count: length(cases),
      blocked_claims: blocked_claims(cases),
      background_claims_allowed?: false,
      restart_claims_allowed?: false,
      scheduled_retry_claims_allowed?: false,
      notes: [
        "Foreground/manual BLE remains the only validated mobile lifecycle mode.",
        "Negative validation cases protect against promoting foreground harness or fetch-intent evidence into background, restart, retry, or delivery claims.",
        "Future lifecycle work must add implementation evidence and keep these negative cases covered."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp blocked_claims(cases) do
    cases
    |> Enum.flat_map(& &1.blocked_claims)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
