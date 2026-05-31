defmodule Mob.Node.BLE.LocalSecurityIdentityContract do
  @moduledoc """
  Security and identity proof contract for local BLE message observations.

  This module defines the proof categories required before passive BLE
  observations can be presented as authenticated messages. It does not
  verify signatures, manage keys, encrypt, decrypt, route, fetch, persist,
  ACK, retry, or run background work.
  """

  defmodule Requirement do
    @moduledoc false

    @enforce_keys [:id, :status, :required_evidence, :current_gap, :notes]
    defstruct @enforce_keys

    @type id ::
            :authenticated_peer_identity
            | :message_authorship
            | :replay_protection
            | :trust_policy
            | :beacon_ref_authentication

    @type status :: :not_implemented | :contract_only

    @type t :: %__MODULE__{
            id: id(),
            status: status(),
            required_evidence: [binary()],
            current_gap: binary(),
            notes: [binary()]
          }
  end

  @requirements [
    %{
      id: :authenticated_peer_identity,
      status: :contract_only,
      required_evidence: [
        "A stable peer identity must bind to cryptographic key material or equivalent authenticated evidence.",
        "The binding must survive transport-local device_id rotation."
      ],
      current_gap:
        "Current peer_id values are passive advertisement-derived labels or hashes, not authenticated identities.",
      notes: [
        "Identity.Claim reserves future cryptographic source values, but no BLE path emits them."
      ]
    },
    %{
      id: :message_authorship,
      status: :not_implemented,
      required_evidence: [
        "A full MessageEnvelope must carry or reference an authorship proof.",
        "The proof must bind message_id, sender_peer_id, payload_kind, payload bytes, and envelope_version."
      ],
      current_gap:
        "Full-envelope advertisements validate canonical bytes but do not prove who authored them.",
      notes: ["Canonical envelope validation is integrity shape evidence, not authorship."]
    },
    %{
      id: :replay_protection,
      status: :not_implemented,
      required_evidence: [
        "A receiver must be able to detect stale or replayed signed envelopes within the chosen policy window.",
        "Replay state must be explicit and bounded before any trusted-delivery wording is allowed."
      ],
      current_gap: "Local inbox trust evidence currently reports replay_protection: :none.",
      notes: ["Seen-count dedupe is a local UI signal, not replay protection."]
    },
    %{
      id: :trust_policy,
      status: :not_implemented,
      required_evidence: [
        "A policy must define trusted, untrusted, blocked, and unknown peer states.",
        "The policy must define how a peer becomes trusted and how trust is revoked."
      ],
      current_gap:
        "Local inbox entries only expose unsigned_observation or untrusted_reference states.",
      notes: ["No BLE local trust store or trust transition exists."]
    },
    %{
      id: :beacon_ref_authentication,
      status: :not_implemented,
      required_evidence: [
        "A beacon ref must authenticate the sender/hash pointer or resolve to a full authenticated envelope.",
        "A hash-only beacon must never be promoted to trusted message delivery by itself."
      ],
      current_gap: "Legacy beacon refs are pointers with hash_reference_only integrity.",
      notes: ["Beacon refs remain useful discovery signals, not messages with authorship proof."]
    }
  ]

  @spec requirements() :: [Requirement.t()]
  def requirements, do: Enum.map(@requirements, &struct!(Requirement, &1))

  @spec get(Requirement.id()) :: {:ok, Requirement.t()} | {:error, :not_found}
  def get(id) do
    case Enum.find(requirements(), &(&1.id == id)) do
      %Requirement{} = requirement -> {:ok, requirement}
      nil -> {:error, :not_found}
    end
  end

  @spec open_requirements() :: [Requirement.t()]
  def open_requirements, do: requirements()

  @spec snapshot() :: map()
  def snapshot do
    %{
      requirements: requirements(),
      open_requirements: open_requirements(),
      open_requirement_count: length(open_requirements()),
      notes: [
        "Current BLE local inbox entries are not authenticated.",
        "Message hashes and beacon refs are lookup references, not authorship proof.",
        "No trusted-delivery wording is allowed until these requirements have implementation and validation evidence."
      ]
    }
  end
end
