defmodule MeshxMobileApp.BLE.LocalSecurityCanonicalReplayDecision do
  @moduledoc """
  Canonical replay ingress boundary for local trusted-message decisions.

  This module evaluates replay-normalized `ReceivedMessage` events with the
  existing local security proof inputs: supplied peer binding, supplied
  authorship proof, bounded in-memory replay state, and explicit caller
  trust state. It does not discover keys, persist trust, persist replay
  state, authenticate beacon refs, fetch, route, ACK, retry, encrypt, or run
  background work.
  """

  alias MeshxMobileApp.BLE.{
    LocalSecurityOperatorTrustPolicy,
    LocalSecurityTrustedMessageDecision,
    MessageEnvelope
  }

  alias MeshxMobileApp.BLE.Events.ReceivedMessage
  alias MeshxMobileApp.BLE.LocalSecurityAuthorshipProof.Proof
  alias MeshxMobileApp.BLE.LocalSecurityPeerIdentityBinding.Binding
  alias MeshxMobileApp.BLE.LocalSecurityReplayProtection.State

  @blocked_claims [:trusted_message, :trusted_delivery, :routed_delivery, :guaranteed_delivery]

  @type error ::
          :invalid_received_message
          | :event_envelope_mismatch
          | :transport_payload_mismatch
          | atom()

  @spec decide(ReceivedMessage.t(), Proof.t(), Binding.t(), State.t(), keyword()) ::
          {:ok, State.t(), map()} | {:error, error(), State.t(), map()}
  def decide(
        %ReceivedMessage{} = event,
        %Proof{} = proof,
        %Binding{} = binding,
        %State{} = state,
        opts
      ) do
    observed_at = Keyword.get(opts, :observed_at, event.received_at)

    with :ok <- validate_event(event),
         {:ok, opts, trust_evidence} <-
           trust_opts(binding, Keyword.put(opts, :observed_at, observed_at)),
         {:ok, next_state, decision} <-
           LocalSecurityTrustedMessageDecision.decide(
             event.envelope,
             proof,
             binding,
             state,
             opts
           ) do
      {:ok, next_state, augment(event, Map.merge(decision, trust_evidence))}
    else
      {:error, reason, %State{} = next_state, decision} ->
        {:error, reason, next_state, augment(event, decision)}

      {:error, reason} ->
        {:error, reason, state, rejected(event, reason)}
    end
  end

  def decide(_event, _proof, _binding, %State{} = state, _opts) do
    {:error, :invalid_received_message, state, rejected(nil, :invalid_received_message)}
  end

  defp validate_event(%ReceivedMessage{envelope: %MessageEnvelope{} = envelope} = event) do
    with :ok <- validate_envelope(envelope),
         :ok <- validate_event_envelope_fields(event, envelope),
         :ok <- validate_transport_payload(event, envelope) do
      :ok
    end
  end

  defp validate_event(%ReceivedMessage{}), do: {:error, :invalid_received_message}

  defp validate_envelope(%MessageEnvelope{} = envelope) do
    envelope
    |> MessageEnvelope.encode()
    |> MessageEnvelope.parse()
    |> case do
      {:ok, ^envelope} -> :ok
      {:ok, _} -> {:error, :invalid_received_message}
      {:error, _} -> {:error, :invalid_received_message}
    end
  end

  defp validate_event_envelope_fields(event, envelope) do
    if event.message_id == envelope.message_id and
         event.sender_peer_id == envelope.sender_peer_id and
         event.recipient_peer_id == envelope.recipient_peer_id do
      :ok
    else
      {:error, :event_envelope_mismatch}
    end
  end

  defp validate_transport_payload(
         %ReceivedMessage{raw_transport_metadata: %{message_payload: payload}},
         envelope
       )
       when is_binary(payload) do
    if payload == MessageEnvelope.encode(envelope) do
      :ok
    else
      {:error, :transport_payload_mismatch}
    end
  end

  defp validate_transport_payload(_event, _envelope), do: :ok

  defp trust_opts(binding, opts) do
    case Keyword.fetch(opts, :operator_trust_policy) do
      {:ok, policy} ->
        with {:ok, trust_evidence} <- LocalSecurityOperatorTrustPolicy.evaluate(policy, binding) do
          opts =
            opts
            |> Keyword.delete(:operator_trust_policy)
            |> Keyword.put(:peer_trust_state, trust_evidence.peer_trust_state)

          {:ok, opts, Map.delete(trust_evidence, :peer_trust_state)}
        end

      :error ->
        {:ok, opts, %{}}
    end
  end

  defp augment(%ReceivedMessage{} = event, decision) do
    Map.merge(decision, %{
      canonical_replay_event?: true,
      event_kind: :received_message,
      received_device_id: event.received_device_id,
      received_at: event.received_at,
      rssi: event.rssi,
      trusted_delivery_claim_allowed?: false
    })
  end

  defp rejected(%ReceivedMessage{} = event, reason) do
    Map.merge(rejected(nil, reason), %{
      received_device_id: event.received_device_id,
      received_at: event.received_at,
      rssi: event.rssi
    })
  end

  defp rejected(_event, reason) do
    %{
      canonical_replay_event?: false,
      status: :rejected,
      trusted_message?: false,
      trusted_delivery_claim_allowed?: false,
      provided_evidence: [],
      missing_evidence: [
        :canonical_received_message,
        :authenticated_peer_identity,
        :message_authorship
      ],
      reasons: [reason],
      blocked_claims: @blocked_claims
    }
  end
end
