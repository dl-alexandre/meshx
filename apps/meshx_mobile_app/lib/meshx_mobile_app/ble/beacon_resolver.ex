defmodule MeshxMobileApp.BLE.BeaconResolver do
  @moduledoc """
  Pure contract for resolving legacy message beacons into full envelopes.

  This module does not fetch anything. It only decides what a caller
  should do with a `BeaconRef` and the envelopes it already has.
  """

  alias MeshxMobileApp.BLE.{BeaconRef, MessageEnvelope}

  @type request :: %{
          envelope_version: pos_integer(),
          payload_kind: binary(),
          message_id_hash: binary(),
          sender_peer_hash: binary(),
          observed_at: integer(),
          received_device_id: binary(),
          rssi: integer()
        }

  @type reason ::
          {:invalid_beacon_ref, BeaconRef.error()}
          | :hash_mismatch
          | :invalid_cache

  @spec resolve(BeaconRef.t() | {:error, BeaconRef.error()}, term()) ::
          {:needs_fetch, request()}
          | {:already_known, MessageEnvelope.t()}
          | {:unresolvable, reason()}
  def resolve({:error, reason}, _cache), do: {:unresolvable, {:invalid_beacon_ref, reason}}

  def resolve(%BeaconRef{} = ref, cache) do
    with :ok <- BeaconRef.validate(ref),
         {:ok, envelopes} <- normalize_cache(cache) do
      case Enum.find(envelopes, &BeaconRef.matches_envelope?(ref, &1)) do
        %MessageEnvelope{} = envelope ->
          {:already_known, envelope}

        nil ->
          if hash_collision_candidate?(ref, envelopes) do
            {:unresolvable, :hash_mismatch}
          else
            {:needs_fetch, request(ref)}
          end
      end
    else
      {:error, reason} -> {:unresolvable, {:invalid_beacon_ref, reason}}
      :error -> {:unresolvable, :invalid_cache}
    end
  end

  def resolve(_other, _cache), do: {:unresolvable, :invalid_cache}

  defp normalize_cache(envelopes) when is_list(envelopes) do
    if Enum.all?(envelopes, &match?(%MessageEnvelope{}, &1)) do
      {:ok, envelopes}
    else
      :error
    end
  end

  defp normalize_cache(%{envelopes: envelopes}), do: normalize_cache(envelopes)
  defp normalize_cache(%{"envelopes" => envelopes}), do: normalize_cache(envelopes)
  defp normalize_cache(_cache), do: :error

  defp hash_collision_candidate?(%BeaconRef{} = ref, envelopes) do
    Enum.any?(envelopes, fn envelope ->
      BeaconRef.message_id_hash(envelope) == ref.message_id_hash
    end)
  end

  defp request(%BeaconRef{} = ref) do
    %{
      envelope_version: ref.envelope_version,
      payload_kind: ref.payload_kind,
      message_id_hash: ref.message_id_hash,
      sender_peer_hash: ref.sender_peer_hash,
      observed_at: ref.observed_at,
      received_device_id: ref.received_device_id,
      rssi: ref.rssi
    }
  end
end
