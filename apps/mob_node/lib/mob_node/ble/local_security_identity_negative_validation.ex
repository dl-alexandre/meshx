defmodule Mob.Node.BLE.LocalSecurityIdentityNegativeValidation do
  @moduledoc """
  Negative validation matrix for current local BLE security claims.

  The current advert-only mode has useful nearby observations, but it has no
  authenticated identity, authorship proof, replay protection, or trust
  transition model. This module records the cases that must stay blocked.
  It does not implement crypto, signatures, key management, replay
  protection, trust storage, fetch transport, routing, persistence, ACKs,
  retries, or background work.
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
      id: :unsigned_full_envelope,
      input: :received_message,
      blocked_claims: [
        :authenticated_message,
        :trusted_message,
        :trusted_delivery
      ],
      expected_decision: :local_unsigned_message,
      required_before_allowed: [
        :authenticated_peer_identity,
        :message_authorship,
        :replay_protection,
        :trust_policy_transition
      ],
      notes: [
        "Canonical MessageEnvelope parsing proves shape, not authorship.",
        "Unsigned full-envelope adverts may be shown only as local observations."
      ]
    },
    %{
      id: :hash_only_legacy_beacon,
      input: :received_message_beacon,
      blocked_claims: [
        :authenticated_message,
        :trusted_beacon_ref,
        :trusted_delivery
      ],
      expected_decision: :local_untrusted_reference,
      required_before_allowed: [
        :full_envelope_resolution,
        :authenticated_peer_identity,
        :message_authorship,
        :replay_protection,
        :trust_policy_transition
      ],
      notes: [
        "A legacy beacon is a pointer, not a MessageEnvelope.",
        "Message and sender hashes are references, not proof of authorship."
      ]
    },
    %{
      id: :gossiped_beacon_ref,
      input: :received_message_beacon_via_advert_gossip,
      blocked_claims: [
        :authenticated_message,
        :trusted_beacon_ref,
        :routed_delivery,
        :trusted_delivery
      ],
      expected_decision: :local_untrusted_reference,
      required_before_allowed: [
        :full_envelope_resolution,
        :authenticated_peer_identity,
        :message_authorship,
        :replay_protection,
        :trust_policy_transition,
        :production_routing_policy
      ],
      notes: [
        "Advert gossip propagation does not add authorship or delivery proof.",
        "Replay gossip simulation is not a production routing trust model."
      ]
    },
    %{
      id: :stale_beacon_ref,
      input: :stale_received_message_beacon,
      blocked_claims: [
        :fresh_message,
        :authenticated_message,
        :trusted_delivery
      ],
      expected_decision: :local_untrusted_reference,
      required_before_allowed: [
        :full_envelope_resolution,
        :authenticated_peer_identity,
        :message_authorship,
        :replay_protection,
        :trust_policy_transition
      ],
      notes: [
        "Local staleness is a presentation state, not replay protection.",
        "A stale ref remains unresolved until a validated fetch path exists."
      ]
    },
    %{
      id: :passive_peer_label,
      input: :advertised_peer_id_or_name,
      blocked_claims: [
        :authenticated_peer_identity,
        :trusted_peer,
        :trusted_delivery
      ],
      expected_decision: :unauthenticated_identity_signal,
      required_before_allowed: [
        :peer_key_material,
        :identity_key_binding,
        :device_rotation_survival,
        :trust_policy_transition
      ],
      notes: [
        "Passive peer labels survive some replay cases but are not authenticated identities.",
        "Transport-local device IDs and advertised names cannot establish trust."
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
      boundary: :current_unsigned_advertisement_only_mode,
      cases: cases,
      case_count: length(cases),
      blocked_claims: blocked_claims(cases),
      trusted_claims_allowed?: false,
      delivery_claims_allowed?: false,
      notes: [
        "Every current local BLE observation remains unsigned or untrusted.",
        "Negative validation cases protect against promoting hashes, gossip, or passive labels into trust.",
        "Future crypto/trust work must replace these blocked outcomes with positive and negative fixtures."
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
