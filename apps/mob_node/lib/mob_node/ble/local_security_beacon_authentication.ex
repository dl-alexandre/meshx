defmodule Mob.Node.BLE.LocalSecurityBeaconAuthentication do
  @moduledoc """
  Pure authentication boundary for legacy beacon refs.

  A legacy beacon ref is only an authenticated pointer when it matches a
  resolved full `MessageEnvelope` and that envelope has already passed the
  local trusted-message decision boundary. Hash-only beacon refs never become
  trusted messages by themselves. This module does not fetch envelopes, verify
  signatures, manage keys, persist trust, persist replay state, route, ACK,
  retry, encrypt, or run background work.
  """

  alias Mob.Node.BLE.{BeaconRef, MessageEnvelope}

  @blocked_claims [:trusted_delivery, :routed_delivery, :guaranteed_delivery]

  @type error ::
          :invalid_beacon_ref
          | :invalid_envelope
          | :beacon_ref_mismatch
          | :untrusted_envelope

  @spec authenticate(BeaconRef.t(), MessageEnvelope.t(), map()) ::
          {:ok, map()} | {:error, error(), map()}
  def authenticate(%BeaconRef{} = ref, %MessageEnvelope{} = envelope, decision)
      when is_map(decision) do
    with :ok <- BeaconRef.validate(ref),
         :ok <- validate_envelope(envelope),
         :ok <- validate_ref_match(ref, envelope),
         :ok <- validate_decision(decision) do
      {:ok,
       %{
         authenticated_beacon_ref?: true,
         authenticated_message_ref?: true,
         trusted_message?: true,
         trusted_delivery_claim_allowed?: false,
         envelope_version: ref.envelope_version,
         payload_kind: ref.payload_kind,
         message_id_hash: ref.message_id_hash,
         sender_peer_hash: ref.sender_peer_hash,
         message_id: envelope.message_id,
         sender_peer_id: envelope.sender_peer_id,
         observed_at: ref.observed_at,
         received_device_id: ref.received_device_id,
         blocked_claims: @blocked_claims,
         notes: [
           "Beacon ref authenticated only after matching a resolved trusted full envelope.",
           "This is pointer authentication, not delivery."
         ]
       }}
    else
      {:error, reason} -> {:error, reason, rejected(reason)}
    end
  end

  def authenticate(_ref, _envelope, _decision),
    do: {:error, :invalid_beacon_ref, rejected(:invalid_beacon_ref)}

  defp validate_envelope(%MessageEnvelope{} = envelope) do
    envelope
    |> MessageEnvelope.encode()
    |> MessageEnvelope.parse()
    |> case do
      {:ok, ^envelope} -> :ok
      {:ok, _} -> {:error, :invalid_envelope}
      {:error, _} -> {:error, :invalid_envelope}
    end
  end

  defp validate_ref_match(ref, envelope) do
    if BeaconRef.matches_envelope?(ref, envelope) do
      :ok
    else
      {:error, :beacon_ref_mismatch}
    end
  end

  defp validate_decision(%{trusted_message?: true}), do: :ok
  defp validate_decision(_decision), do: {:error, :untrusted_envelope}

  defp rejected(reason) do
    %{
      authenticated_beacon_ref?: false,
      authenticated_message_ref?: false,
      trusted_message?: false,
      trusted_delivery_claim_allowed?: false,
      reasons: [reason],
      blocked_claims: [:trusted_beacon_ref, :trusted_message | @blocked_claims]
    }
  end
end
