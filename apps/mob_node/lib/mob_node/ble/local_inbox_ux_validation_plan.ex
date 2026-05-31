defmodule Mob.Node.BLE.LocalInboxUxValidationPlan do
  @moduledoc """
  On-device validation plan for the Nearby Messages surface.

  The pure read model and UX acceptance gates are necessary evidence, but
  production UX still needs target-device validation. This module defines the
  exact validation bundle expected before the `product_ux` readiness item can
  close. It does not render UI, drive devices, scan, advertise, fetch, route,
  persist, ACK, retry, encrypt, or run background work.
  """

  defmodule Gate do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :status,
               :required_evidence,
               :acceptance_criteria,
               :blocked_claims,
               :notes
             ]}
    @enforce_keys [
      :id,
      :status,
      :required_evidence,
      :acceptance_criteria,
      :blocked_claims,
      :notes
    ]
    defstruct @enforce_keys
  end

  @blocked_claims [:production_nearby_messages_ux, :delivery, :trusted_delivery, :routing]

  @gates [
    %{
      id: :target_device_matrix,
      status: :open,
      required_evidence: [
        "Device model, OS/API version, screen size class, and app build identifier.",
        "At least one small/older Android target and one current target if product release needs both."
      ],
      acceptance_criteria: [
        "Every attached screenshot or note names the target device and build.",
        "Unsupported targets remain explicit instead of being folded into a production UX claim."
      ],
      blocked_claims: [:production_nearby_messages_ux],
      notes: ["The current pure gates are not device screenshots or operator notes."]
    },
    %{
      id: :state_coverage_screenshots,
      status: :open,
      required_evidence: [
        "State evidence entries with evidence_kind screenshot or operator_note for full message, unresolved ref, gossiped ref, and stale ref rows.",
        "Evidence that All and per-state filters are usable with those rows present."
      ],
      acceptance_criteria: [
        "Each state is visible without ambiguous copy.",
        "Beacon refs remain visually distinct from full messages."
      ],
      blocked_claims: [:production_nearby_messages_ux, :trusted_delivery],
      notes: ["State coverage preserves the advert-only local mesh wording boundary."]
    },
    %{
      id: :interaction_coverage,
      status: :open,
      required_evidence: [
        "Interaction evidence entries with evidence_kind screenshot or operator_note for filter changes, sort changes, row selection, and detail panel.",
        "Evidence that detail panels expose limitation and next-action copy."
      ],
      acceptance_criteria: [
        "Controls do not hide blocked-claim warnings.",
        "Selection and detail text remain usable at target screen density."
      ],
      blocked_claims: [:production_nearby_messages_ux],
      notes: ["Interaction evidence is presentation evidence only, not transport evidence."]
    },
    %{
      id: :blocked_claim_copy_review,
      status: :open,
      required_evidence: [
        "Copy review entry with evidence_kind screenshot or operator_note confirming visible copy does not claim delivery, routing, trusted delivery, or background behavior.",
        "Screenshot or operator-note text capture of warnings, selected detail limitations, detail next actions, filter/sort summaries, and per-state blocked-claim copy."
      ],
      acceptance_criteria: [
        "Visible copy uses nearby/observed/ref wording.",
        "Visible copy never presents beacon refs as delivered messages.",
        "Control summaries and per-state blocked-claim copy remain visible in the reviewed target-device evidence."
      ],
      blocked_claims: [:delivery, :trusted_delivery, :routing],
      notes: ["Copy review protects product UX from overclaiming protocol state."]
    },
    %{
      id: :visual_density_review,
      status: :open,
      required_evidence: [
        "Visual density review entry with evidence_kind operator_note for row truncation, wrapping, tap target comfort, and detail panel readability.",
        "Visual density review entry with evidence_kind screenshot for the densest fixture state on target hardware."
      ],
      acceptance_criteria: [
        "State badges, titles, metadata, and warnings remain readable.",
        "No critical row or warning text overlaps or disappears."
      ],
      blocked_claims: [:production_nearby_messages_ux],
      notes: ["The current code has pure copy/row models, not visual QA evidence."]
    }
  ]

  @spec gates() :: [Gate.t()]
  def gates, do: Enum.map(@gates, &struct!(Gate, &1))

  @spec snapshot() :: map()
  def snapshot do
    gates = gates()

    %{
      plan_version: 1,
      boundary: :nearby_messages_on_device_ux_validation,
      gates: gates,
      open_gate_count: length(gates),
      satisfied_gate_count: 0,
      production_ux_claim_allowed?: false,
      blocked_claims: @blocked_claims,
      notes: [
        "Pure read-model tests are not on-device UX validation.",
        "Production Nearby Messages UX remains blocked until operator evidence is attached.",
        "UX validation does not add delivery, routing, trust, or background claims."
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
