defmodule MeshxMobileApp.BLE.LocalSecurityTrustedMessageDecision do
  @moduledoc """
  Pure trusted-message decision pipeline for full local BLE envelopes.

  This module combines existing security boundaries: peer identity binding,
  authorship verification, replay protection, and an explicit peer trust
  state. It produces a local trusted-message decision for full
  `MessageEnvelope` values only. It does not discover keys, persist trust,
  persist replay state, authenticate beacon refs, fetch, route, ACK, retry,
  encrypt, run background work, or claim delivery.
  """

  alias MeshxMobileApp.BLE.{
    LocalSecurityPeerIdentityBinding,
    LocalSecurityReplayProtection,
    LocalSecurityTrustModel,
    MessageEnvelope
  }

  alias MeshxMobileApp.BLE.LocalSecurityAuthorshipProof.Proof
  alias MeshxMobileApp.BLE.LocalSecurityPeerIdentityBinding.Binding
  alias MeshxMobileApp.BLE.LocalSecurityReplayProtection.State

  @blocked_claims [:trusted_delivery, :routed_delivery, :guaranteed_delivery]

  @type decision_status :: :trusted_message | :untrusted | :blocked | :rejected

  @type decision :: %{
          required(:status) => decision_status(),
          required(:trusted_message?) => boolean(),
          required(:trusted_delivery_claim_allowed?) => false,
          required(:peer_trust_state) => LocalSecurityTrustModel.peer_state(),
          required(:provided_evidence) => [atom()],
          required(:missing_evidence) => [atom()],
          required(:reasons) => [atom()],
          required(:blocked_claims) => [atom()],
          optional(:binding_key_id) => binary(),
          optional(:message_id) => binary(),
          optional(:replay_fingerprint) => binary()
        }

  @spec decide(MessageEnvelope.t(), Proof.t(), Binding.t(), State.t(), keyword()) ::
          {:ok, State.t(), decision()} | {:error, atom(), State.t(), decision()}
  def decide(
        %MessageEnvelope{} = envelope,
        %Proof{} = proof,
        %Binding{} = binding,
        %State{} = replay_state,
        opts
      ) do
    peer_trust_state = Keyword.get(opts, :peer_trust_state, :unknown)
    observed_at = Keyword.get(opts, :observed_at)

    with {:ok, binding_evidence} <-
           LocalSecurityPeerIdentityBinding.verify(envelope, proof, binding),
         {:ok, next_replay_state, replay_evidence} <-
           LocalSecurityReplayProtection.accept(replay_state, envelope, proof,
             observed_at: observed_at
           ) do
      decision =
        trust_decision(peer_trust_state,
          binding_key_id: binding_evidence.binding_key_id,
          message_id: binding_evidence.message_id,
          replay_fingerprint: replay_evidence.fingerprint
        )

      {:ok, next_replay_state, decision}
    else
      {:error, reason, %State{} = state} ->
        {:error, reason, state, rejected_decision(peer_trust_state, reason)}

      {:error, reason} ->
        {:error, reason, replay_state, rejected_decision(peer_trust_state, reason)}
    end
  end

  def decide(_envelope, _proof, _binding, %State{} = replay_state, opts) do
    peer_trust_state = Keyword.get(opts, :peer_trust_state, :unknown)

    {:error, :invalid_envelope, replay_state,
     rejected_decision(peer_trust_state, :invalid_envelope)}
  end

  @spec proof_flags(decision()) :: map()
  def proof_flags(%{trusted_message?: true}) do
    %{
      authenticated_peer_identity?: true,
      message_authorship?: true,
      replay_protection?: true,
      peer_trust_state: :trusted
    }
  end

  def proof_flags(%{peer_trust_state: peer_trust_state}) do
    %{
      authenticated_peer_identity?: false,
      message_authorship?: false,
      replay_protection?: false,
      peer_trust_state: peer_trust_state
    }
  end

  defp trust_decision(peer_trust_state, fields) do
    evaluation =
      LocalSecurityTrustModel.evaluate(%{item_state: :full_message},
        authenticated_peer_identity?: true,
        message_authorship?: true,
        replay_protection?: true,
        peer_trust_state: peer_trust_state
      )

    status =
      cond do
        peer_trust_state in [:blocked, :revoked] -> :blocked
        evaluation.trusted_message? -> :trusted_message
        true -> :untrusted
      end

    fields
    |> Map.new()
    |> Map.merge(%{
      status: status,
      trusted_message?: status == :trusted_message,
      trusted_delivery_claim_allowed?: false,
      peer_trust_state: peer_trust_state,
      provided_evidence: evaluation.provided_evidence,
      missing_evidence: evaluation.missing_evidence,
      reasons: evaluation.reasons,
      blocked_claims:
        if(status == :trusted_message, do: @blocked_claims, else: evaluation.blocked_claims)
    })
  end

  defp rejected_decision(peer_trust_state, reason) do
    %{
      status: :rejected,
      trusted_message?: false,
      trusted_delivery_claim_allowed?: false,
      peer_trust_state: peer_trust_state,
      provided_evidence: [],
      missing_evidence: [:authenticated_peer_identity, :message_authorship, :replay_protection],
      reasons: [reason],
      blocked_claims: [:trusted_message | @blocked_claims]
    }
  end
end
