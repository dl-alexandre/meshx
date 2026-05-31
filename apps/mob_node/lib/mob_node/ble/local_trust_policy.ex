defmodule Mob.Node.BLE.LocalTrustPolicy do
  @moduledoc """
  Presentation policy for advertisement-only local inbox trust evidence.

  This module turns trust evidence into explicit UI/API decisions. Current
  local BLE observations are useful, but none are authenticated. The policy
  therefore allows display as local evidence while blocking trusted-message
  wording and trusted delivery claims.

  It does not implement crypto, signatures, key management, replay
  protection, routing, fetch transport, persistence, ACKs, retries, or
  background behavior.
  """

  alias Mob.Node.BLE.LocalInboxTrust

  defmodule Decision do
    @moduledoc false

    @enforce_keys [
      :message_key,
      :item_state,
      :trust_state,
      :presentation,
      :trusted_message?,
      :delivery_claim_allowed?,
      :required_before_trusted,
      :reasons
    ]
    defstruct @enforce_keys

    @type presentation :: :local_unsigned_message | :local_untrusted_reference

    @type t :: %__MODULE__{
            message_key: binary(),
            item_state: atom(),
            trust_state: atom(),
            presentation: presentation(),
            trusted_message?: boolean(),
            delivery_claim_allowed?: boolean(),
            required_before_trusted: [atom()],
            reasons: [atom()]
          }
  end

  @missing_proofs [
    :authenticated_peer_identity,
    :message_authorship,
    :replay_protection,
    :trust_policy_transition
  ]

  @spec current_decision() :: map()
  def current_decision do
    %{
      decision_outcome: :keep_unsigned_local_observation,
      decision_status: :selected_for_current_validated_mode,
      current_mode: :advertisement_only_local_mesh,
      authenticated_peer_identity_enabled?: false,
      authenticated_message_enabled?: false,
      trusted_message_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      security_reconsideration_gate: :authenticated_local_ble_security_validation_plan,
      rationale: [
        "The current validated mode displays local BLE advertisement observations only.",
        "Full-envelope adverts are canonical observations but are not authenticated authorship evidence.",
        "Hash-only beacon refs are pointers and cannot be promoted to trusted messages without resolved full-envelope trust evidence."
      ]
    }
  end

  @spec decisions(map() | [LocalInboxTrust.Evidence.t()]) :: [Decision.t()]
  def decisions(%{trust_evidence: evidence}) when is_list(evidence), do: decisions(evidence)

  def decisions(evidence) when is_list(evidence), do: Enum.map(evidence, &decide/1)

  @spec decide(LocalInboxTrust.Evidence.t()) :: Decision.t()
  def decide(%LocalInboxTrust.Evidence{trust_state: :unsigned_observation} = evidence) do
    %Decision{
      message_key: evidence.message_key,
      item_state: evidence.item_state,
      trust_state: evidence.trust_state,
      presentation: :local_unsigned_message,
      trusted_message?: false,
      delivery_claim_allowed?: false,
      required_before_trusted: @missing_proofs,
      reasons: [:canonical_envelope_without_authorship | evidence.reasons]
    }
  end

  def decide(%LocalInboxTrust.Evidence{trust_state: :untrusted_reference} = evidence) do
    %Decision{
      message_key: evidence.message_key,
      item_state: evidence.item_state,
      trust_state: evidence.trust_state,
      presentation: :local_untrusted_reference,
      trusted_message?: false,
      delivery_claim_allowed?: false,
      required_before_trusted: [:full_envelope_resolution | @missing_proofs],
      reasons: [:hash_reference_not_authorship | evidence.reasons]
    }
  end

  @spec snapshot(map()) :: map()
  def snapshot(%{} = local_inbox_snapshot) do
    decisions = decisions(local_inbox_snapshot)

    %{
      policy: :advertisement_only_local_trust_policy,
      current_security_decision: current_decision(),
      decisions: decisions,
      trusted_message_count: Enum.count(decisions, & &1.trusted_message?),
      untrusted_count: Enum.count(decisions, &(not &1.trusted_message?)),
      delivery_claims_allowed?:
        decisions != [] and Enum.all?(decisions, & &1.delivery_claim_allowed?),
      notes: [
        "Display is allowed only as local BLE observation evidence.",
        "Trusted-message and delivery wording remain blocked until identity, authorship, replay protection, and trust transitions exist.",
        "Beacon refs require full-envelope resolution before they can even be evaluated for authorship."
      ]
    }
  end
end
