defmodule MeshxMobileApp.BLE.AdvertOnlyTransportProfile do
  @moduledoc """
  Local BLE profile for advertisement-only MeshX operation.

  This profile is a capability statement, not a transport implementation.
  It records that local mesh mode can use legacy beacon advertisements and
  full-envelope advertisements when capability-proven, while explicitly
  excluding GATT fetch, ACKs, large payloads, retries, and guaranteed
  delivery.
  """

  @enforce_keys [
    :name,
    :supports,
    :does_not_support,
    :capability_notes
  ]
  defstruct name: :advertisement_only_local_mesh,
            supports: MapSet.new(),
            does_not_support: MapSet.new(),
            capability_notes: []

  @type capability ::
          :legacy_beacon_adverts
          | :full_envelope_adverts_when_capability_proven

  @type unsupported ::
          :gatt_fetch
          | :acks
          | :large_payloads
          | :retries
          | :guaranteed_delivery

  @type t :: %__MODULE__{
          name: :advertisement_only_local_mesh,
          supports: MapSet.t(capability()),
          does_not_support: MapSet.t(unsupported()),
          capability_notes: [binary()]
        }

  @spec advert_only() :: t()
  def advert_only do
    %__MODULE__{
      name: :advertisement_only_local_mesh,
      supports:
        MapSet.new([
          :legacy_beacon_adverts,
          :full_envelope_adverts_when_capability_proven
        ]),
      does_not_support:
        MapSet.new([
          :gatt_fetch,
          :acks,
          :large_payloads,
          :retries,
          :guaranteed_delivery
        ]),
      capability_notes: [
        "Legacy beacon advertisements are references, not message delivery.",
        "Full-envelope advertisements are accepted only when sender and observer capability is proven.",
        "GATT fetch remains experimental and disabled by default."
      ]
    }
  end

  @spec supports?(t(), capability()) :: boolean()
  def supports?(%__MODULE__{} = profile, capability),
    do: MapSet.member?(profile.supports, capability)

  @spec unsupported?(t(), unsupported()) :: boolean()
  def unsupported?(%__MODULE__{} = profile, capability),
    do: MapSet.member?(profile.does_not_support, capability)

  @spec snapshot(t()) :: map()
  def snapshot(%__MODULE__{} = profile) do
    %{
      name: profile.name,
      supports: profile.supports |> MapSet.to_list() |> Enum.sort(),
      does_not_support: profile.does_not_support |> MapSet.to_list() |> Enum.sort(),
      capability_notes: profile.capability_notes
    }
  end
end
