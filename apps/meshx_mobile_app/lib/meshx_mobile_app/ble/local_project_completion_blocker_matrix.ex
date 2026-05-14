defmodule MeshxMobileApp.BLE.LocalProjectCompletionBlockerMatrix do
  @moduledoc """
  Blocker classification for whole-project completion.

  The readiness audit lists what remains open. This matrix classifies the
  remaining work by the kind of action that can unblock it, so release and
  planning surfaces do not treat hardware blockers, product decisions,
  implementation work, and per-release evidence as the same kind of work.

  It does not inspect hardware, scan, advertise, fetch, route, persist, ACK,
  retry, encrypt, authenticate, fragment, or run background work.
  """

  alias MeshxMobileApp.BLE.LocalProjectReadiness

  defmodule Entry do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :objective_id,
               :status,
               :primary_blocker,
               :blocker_categories,
               :can_progress_without_new_hardware?,
               :next_unblock_action,
               :required_evidence
             ]}
    @enforce_keys [
      :objective_id,
      :status,
      :primary_blocker,
      :blocker_categories,
      :can_progress_without_new_hardware?,
      :next_unblock_action,
      :required_evidence
    ]
    defstruct @enforce_keys

    @type category ::
            :hardware_evidence
            | :product_decision
            | :implementation
            | :release_evidence
            | :security_design
            | :transport_selection

    @type t :: %__MODULE__{
            objective_id: atom(),
            status: :blocked | :partial | :not_started,
            primary_blocker: category(),
            blocker_categories: [category()],
            can_progress_without_new_hardware?: boolean(),
            next_unblock_action: binary(),
            required_evidence: [binary()]
          }
  end

  @entries [
    %{
      objective_id: :full_message_resolution,
      primary_blocker: :hardware_evidence,
      blocker_categories: [:hardware_evidence, :transport_selection, :implementation],
      can_progress_without_new_hardware?: false,
      next_unblock_action:
        "Keep fake/offline fetch as contract evidence and validate one real constrained transport that retrieves and replay-parses a full MessageEnvelope from a beacon ref.",
      required_evidence: [
        "Known-good transport evidence review.",
        "Full-resolution transport evidence review.",
        "Canonical replay fixture for the retrieved envelope."
      ]
    },
    %{
      objective_id: :known_good_transport_validation,
      primary_blocker: :transport_selection,
      blocker_categories: [:transport_selection, :hardware_evidence],
      can_progress_without_new_hardware?: false,
      next_unblock_action:
        "Treat SM-T577U/SM-T390 GATT status 133 as blocked, then find a hardware pair that passes standalone GATT or choose and validate a different constrained fetch transport.",
      required_evidence: [
        "Standalone interop evidence.",
        "Transport decision metadata.",
        "Known-good transport review output."
      ]
    },
    %{
      objective_id: :multi_hop_hardware_proof,
      primary_blocker: :hardware_evidence,
      blocker_categories: [:hardware_evidence, :release_evidence],
      can_progress_without_new_hardware?: false,
      next_unblock_action:
        "Preserve replay and one-hop hardware evidence as limited scope, then run origin, relay, and observer roles on three physical participants or an equivalent controlled rig.",
      required_evidence: [
        "Origin/relay/observer hardware logs.",
        "Replay-normalized multi-hop fixture.",
        "Multi-hop hardware evidence review output."
      ]
    },
    %{
      objective_id: :product_ux,
      primary_blocker: :release_evidence,
      blocker_categories: [:release_evidence, :product_decision],
      can_progress_without_new_hardware?: true,
      next_unblock_action:
        "Keep existing Nearby Messages controls/copy as implementation evidence, attach target-device UX evidence with evidence_kind classification and selected-detail limitation_copy, next_action_copy, and blocked_claim_copy, then run the UX evidence review with coverage_summary before product-facing release wording.",
      required_evidence: [
        "State coverage evidence_kind classified as screenshot or operator_note.",
        "Interaction evidence_kind classified as screenshot or operator_note for filters, sorting, rows, selected details, and detail copy.",
        "Selected detail evidence includes limitation_copy, next_action_copy, and blocked_claim_copy for every Nearby Messages state.",
        "Ready LocalInboxUxEvidenceReview output with coverage_summary for target, state, interaction, copy-review, and density-review coverage."
      ]
    },
    %{
      objective_id: :persistence,
      primary_blocker: :product_decision,
      blocker_categories: [:product_decision, :implementation, :release_evidence],
      can_progress_without_new_hardware?: true,
      next_unblock_action:
        "Attach operator/release evidence for the keep-memory-only decision_outcome, or select production-default and validate that lifecycle.",
      required_evidence: [
        "Production persistence lifecycle decision_outcome evidence.",
        "Migration/cleanup/restore evidence if default persistence is selected.",
        "Production persistence evidence review output."
      ]
    },
    %{
      objective_id: :security_identity,
      primary_blocker: :security_design,
      blocker_categories: [:security_design, :implementation, :release_evidence],
      can_progress_without_new_hardware?: true,
      next_unblock_action:
        "Integrate authenticated authorship, peer binding, replay protection, and trust lifecycle evidence before trusted-message wording.",
      required_evidence: [
        "Canonical replay trusted-message fixtures.",
        "Trust lifecycle validation evidence.",
        "Security release evidence review output."
      ]
    },
    %{
      objective_id: :routing,
      primary_blocker: :product_decision,
      blocker_categories: [:product_decision, :implementation, :hardware_evidence],
      can_progress_without_new_hardware?: true,
      next_unblock_action:
        "Attach operator/release evidence for the keep-advert-only routing decision_outcome, or select production routing and validate route selection, forwarding, delivery semantics, and hardware.",
      required_evidence: [
        "Production routing decision_outcome evidence.",
        "Forwarding and delivery negative fixtures.",
        "Routing production evidence review output."
      ]
    },
    %{
      objective_id: :background_mobile_lifecycle,
      primary_blocker: :product_decision,
      blocker_categories: [:product_decision, :implementation, :hardware_evidence],
      can_progress_without_new_hardware?: true,
      next_unblock_action:
        "Attach operator/release evidence for the keep-foreground-manual lifecycle decision_outcome, or select background behavior and hardware-validate OS lifecycle behavior.",
      required_evidence: [
        "Foreground/background lifecycle decision_outcome evidence.",
        "Device logs for background, restart, and scheduled retry if enabled.",
        "Lifecycle hardware evidence review output."
      ]
    },
    %{
      objective_id: :ios_parity,
      primary_blocker: :hardware_evidence,
      blocker_categories: [:hardware_evidence, :implementation, :transport_selection],
      can_progress_without_new_hardware?: false,
      next_unblock_action:
        "Hardware-validate iOS beacon observation, then select and validate an iOS beacon gossip carrier if iOS participation is required.",
      required_evidence: [
        "iOS device capture for received_message_beacon.",
        "Selected iOS emit carrier evidence if gossip is required.",
        "iOS parity hardware review output."
      ]
    },
    %{
      objective_id: :release_hardening,
      primary_blocker: :release_evidence,
      blocker_categories: [:release_evidence],
      can_progress_without_new_hardware?: true,
      next_unblock_action:
        "Attach fresh release-candidate evidence and run operator wording review for the candidate.",
      required_evidence: [
        "Release artifact bundle.",
        "Operator-authored release notes.",
        "Release candidate evidence review output."
      ]
    }
  ]

  @spec entries() :: [Entry.t()]
  def entries do
    statuses = readiness_statuses()

    Enum.map(@entries, fn entry ->
      entry
      |> Map.put(:status, Map.fetch!(statuses, entry.objective_id))
      |> struct_entry()
    end)
  end

  @spec snapshot() :: map()
  def snapshot do
    entries = entries()

    %{
      matrix_version: 1,
      boundary: :whole_project_completion_blocker_matrix,
      completion_claim_allowed?: false,
      entries: entries,
      category_counts: category_counts(entries),
      primary_blocker_counts: primary_blocker_counts(entries),
      blocked_by_new_hardware: ids(entries, &(!&1.can_progress_without_new_hardware?)),
      can_progress_without_new_hardware: ids(entries, & &1.can_progress_without_new_hardware?),
      next_action_summary: next_action_summary(entries),
      notes: [
        "Hardware-blocked items require new device evidence and cannot be closed by more manifests alone.",
        "Product-decision items can progress without new hardware, but still need explicit acceptance evidence before claims change.",
        "Release-evidence items must be rerun for every release candidate."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp readiness_statuses do
    LocalProjectReadiness.snapshot().open_items
    |> Map.new(&{&1.id, &1.status})
  end

  defp struct_entry(entry), do: struct!(Entry, entry)

  defp category_counts(entries) do
    entries
    |> Enum.flat_map(& &1.blocker_categories)
    |> Enum.frequencies()
  end

  defp primary_blocker_counts(entries) do
    entries
    |> Enum.map(& &1.primary_blocker)
    |> Enum.frequencies()
  end

  defp ids(entries, predicate) do
    entries
    |> Enum.filter(predicate)
    |> Enum.map(& &1.objective_id)
  end

  defp next_action_summary(entries) do
    %{
      hardware_blocked: next_actions(entries, &(!&1.can_progress_without_new_hardware?)),
      can_progress_without_new_hardware:
        next_actions(entries, & &1.can_progress_without_new_hardware?),
      recommended_now: recommended_now(entries)
    }
  end

  defp next_actions(entries, predicate) do
    entries
    |> Enum.filter(predicate)
    |> Enum.map(fn entry ->
      %{
        objective_id: entry.objective_id,
        primary_blocker: entry.primary_blocker,
        next_unblock_action: entry.next_unblock_action,
        required_evidence: entry.required_evidence
      }
    end)
  end

  defp recommended_now(entries) do
    entries
    |> Enum.find(& &1.can_progress_without_new_hardware?)
    |> then(fn
      nil ->
        nil

      entry ->
        %{
          objective_id: entry.objective_id,
          primary_blocker: entry.primary_blocker,
          next_unblock_action: entry.next_unblock_action,
          required_evidence: entry.required_evidence
        }
    end)
  end
end
