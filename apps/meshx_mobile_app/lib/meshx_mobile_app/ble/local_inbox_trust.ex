defmodule MeshxMobileApp.BLE.LocalInboxTrust do
  @moduledoc """
  Trust classification for advertisement-only local inbox observations.

  BLE advertisement observations are useful local evidence, but they are
  not proof of authorship. This module makes that explicit for product
  and future storage consumers without adding crypto, signatures,
  authenticated identity, replay protection, routing, fetch, persistence,
  or transport behavior.
  """

  alias MeshxMobileApp.BLE.LocalInboxView

  defmodule Evidence do
    @moduledoc false

    @enforce_keys [
      :message_key,
      :item_state,
      :trust_state,
      :authorship,
      :integrity,
      :replay_protection,
      :resolution_state,
      :reasons
    ]
    defstruct @enforce_keys

    @type trust_state :: :unsigned_observation | :untrusted_reference
    @type authorship :: :unverified
    @type integrity :: :canonical_envelope_validated | :hash_reference_only
    @type replay_protection :: :none
    @type resolution_state ::
            :full_envelope_present | :needs_resolution | :stale_reference

    @type t :: %__MODULE__{
            message_key: binary(),
            item_state: LocalInboxView.Item.state(),
            trust_state: trust_state(),
            authorship: authorship(),
            integrity: integrity(),
            replay_protection: replay_protection(),
            resolution_state: resolution_state(),
            reasons: [atom()]
          }
  end

  @spec classify_snapshot(map(), keyword()) :: [Evidence.t()]
  def classify_snapshot(%{} = snapshot, opts \\ []) do
    snapshot
    |> nearby_messages(opts)
    |> Enum.map(&classify/1)
  end

  defp nearby_messages(%{nearby_messages: nearby_messages}, _opts)
       when is_list(nearby_messages) do
    nearby_messages
  end

  defp nearby_messages(%{} = snapshot, opts), do: LocalInboxView.nearby_messages(snapshot, opts)

  @spec classify(LocalInboxView.Item.t()) :: Evidence.t()
  def classify(%LocalInboxView.Item{state: :full_message} = item) do
    %Evidence{
      message_key: item.message_key,
      item_state: item.state,
      trust_state: :unsigned_observation,
      authorship: :unverified,
      integrity: :canonical_envelope_validated,
      replay_protection: :none,
      resolution_state: :full_envelope_present,
      reasons: [
        :passive_ble_observation,
        :no_signature,
        :no_authenticated_peer_identity,
        :no_replay_protection
      ]
    }
  end

  def classify(%LocalInboxView.Item{} = item)
      when item.state in [:unresolved_ref, :gossiped_ref] do
    %Evidence{
      message_key: item.message_key,
      item_state: item.state,
      trust_state: :untrusted_reference,
      authorship: :unverified,
      integrity: :hash_reference_only,
      replay_protection: :none,
      resolution_state: :needs_resolution,
      reasons: [
        :legacy_beacon_ref,
        :full_envelope_absent,
        :no_signature,
        :no_authenticated_peer_identity,
        :no_replay_protection
      ]
    }
  end

  def classify(%LocalInboxView.Item{state: :stale_ref} = item) do
    %Evidence{
      message_key: item.message_key,
      item_state: item.state,
      trust_state: :untrusted_reference,
      authorship: :unverified,
      integrity: :hash_reference_only,
      replay_protection: :none,
      resolution_state: :stale_reference,
      reasons: [
        :legacy_beacon_ref,
        :stale_observation,
        :full_envelope_absent,
        :no_signature,
        :no_authenticated_peer_identity,
        :no_replay_protection
      ]
    }
  end
end
