defmodule MeshxMobileApp.BLE.LocalSecurityPeerEnrollment do
  @moduledoc """
  Pure peer-key enrollment boundary for local BLE security proofs.

  Enrollment is explicit operator-supplied Ed25519 public key material for a
  peer id. Passive BLE observations, device names, device ids, hashes, and
  beacon refs cannot enroll trusted identity through this boundary. This
  module is in-memory/pure only; it does not persist keys, rotate keys, revoke
  peers, fetch envelopes, route, ACK, retry, encrypt, or run background work.
  """

  alias MeshxMobileApp.BLE.LocalSecurityPeerIdentityBinding
  alias MeshxMobileApp.BLE.LocalSecurityPeerIdentityBinding.Binding

  defmodule Enrollment do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :enrollment_version,
               :source,
               :peer_id,
               :key_id,
               :public_key,
               :label,
               :enrolled_at,
               :trust_state,
               :blocked_claims,
               :notes
             ]}
    @enforce_keys [
      :enrollment_version,
      :source,
      :peer_id,
      :key_id,
      :public_key,
      :label,
      :enrolled_at,
      :trust_state,
      :blocked_claims,
      :notes
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            enrollment_version: 1,
            source: :operator_supplied_ed25519_key,
            peer_id: binary(),
            key_id: binary(),
            public_key: binary(),
            label: binary() | nil,
            enrolled_at: non_neg_integer(),
            trust_state: :untrusted,
            blocked_claims: [atom()],
            notes: [binary()]
          }
  end

  @blocked_claims [
    :trusted_peer_identity,
    :trusted_message,
    :trusted_delivery,
    :guaranteed_delivery,
    :routed_delivery
  ]

  @type error ::
          :missing_enrolled_at
          | :invalid_enrolled_at
          | :invalid_label
          | :invalid_enrollment
          | :passive_observation_not_enrollment
          | LocalSecurityPeerIdentityBinding.error()

  @spec enroll(binary(), binary(), keyword()) :: {:ok, Enrollment.t()} | {:error, error()}
  def enroll(peer_id, public_key, opts \\ []) do
    with {:ok, enrolled_at} <- fetch_enrolled_at(opts),
         :ok <- validate_label(Keyword.get(opts, :label)),
         {:ok, %Binding{} = binding} <- LocalSecurityPeerIdentityBinding.bind(peer_id, public_key) do
      {:ok,
       %Enrollment{
         enrollment_version: 1,
         source: :operator_supplied_ed25519_key,
         peer_id: binding.peer_id,
         key_id: binding.key_id,
         public_key: binding.public_key,
         label: Keyword.get(opts, :label),
         enrolled_at: enrolled_at,
         trust_state: :untrusted,
         blocked_claims: @blocked_claims,
         notes: [
           "Enrollment records supplied key material only.",
           "Operator trust policy is still required before trusted-message promotion.",
           "Enrollment does not authenticate beacon refs or claim delivery."
         ]
       }}
    end
  end

  @spec reject_passive_observation(term()) :: {:error, :passive_observation_not_enrollment}
  def reject_passive_observation(_observation), do: {:error, :passive_observation_not_enrollment}

  @spec to_binding(Enrollment.t()) :: {:ok, Binding.t()} | {:error, error()}
  def to_binding(%Enrollment{
        enrollment_version: 1,
        source: :operator_supplied_ed25519_key,
        peer_id: peer_id,
        public_key: public_key
      }) do
    LocalSecurityPeerIdentityBinding.bind(peer_id, public_key)
  end

  def to_binding(_enrollment), do: {:error, :invalid_enrollment}

  @spec snapshot() :: map()
  def snapshot do
    %{
      boundary: :operator_supplied_peer_key_enrollment,
      enrollment_source: :operator_supplied_ed25519_key,
      passive_observation_enrollment_allowed?: false,
      trusted_peer_identity_claim_allowed?: false,
      trusted_message_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      blocked_claims: @blocked_claims,
      notes: [
        "This boundary creates no durable key store.",
        "Enrolled key material remains untrusted until explicit operator trust policy and authorship/replay checks pass.",
        "BLE names, device ids, hashes, and beacon refs are not enrollment evidence."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp fetch_enrolled_at(opts) do
    case Keyword.fetch(opts, :enrolled_at) do
      {:ok, enrolled_at} when is_integer(enrolled_at) and enrolled_at >= 0 ->
        {:ok, enrolled_at}

      {:ok, _invalid} ->
        {:error, :invalid_enrolled_at}

      :error ->
        {:error, :missing_enrolled_at}
    end
  end

  defp validate_label(nil), do: :ok
  defp validate_label(label) when is_binary(label) and byte_size(label) <= 64, do: :ok
  defp validate_label(_label), do: {:error, :invalid_label}
end
