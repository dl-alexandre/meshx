defmodule Mob.Node.BLE.LocalTransportLifecycleProfile do
  @moduledoc """
  Lifecycle capability profile for the current local BLE transport mode.

  The current validated MeshX mobile BLE path is foreground/manual. This
  module makes that explicit for UI, docs, and future release checks. It
  does not start services, request background modes, schedule work, touch
  native code, route, persist, ACK, retry, encrypt, or fetch.
  """

  @supported [
    :foreground_scan,
    :foreground_advertise,
    :manual_harness_validation,
    :explicit_start_stop
  ]

  @unsupported [
    :android_foreground_service,
    :android_background_scan,
    :android_background_advertise,
    :ios_background_scan,
    :ios_background_advertise,
    :background_fetch,
    :background_gossip,
    :automatic_restart,
    :scheduled_retry
  ]

  @type capability ::
          :foreground_scan
          | :foreground_advertise
          | :manual_harness_validation
          | :explicit_start_stop
          | :android_foreground_service
          | :android_background_scan
          | :android_background_advertise
          | :ios_background_scan
          | :ios_background_advertise
          | :background_fetch
          | :background_gossip
          | :automatic_restart
          | :scheduled_retry

  @type t :: %__MODULE__{
          name: :foreground_manual_ble,
          supports: [capability()],
          does_not_support: [capability()],
          lifecycle_notes: [binary()]
        }

  defstruct name: :foreground_manual_ble,
            supports: @supported,
            does_not_support: @unsupported,
            lifecycle_notes: [
              "BLE scan/advertise validation is foreground/manual.",
              "Android foreground service support is not implemented.",
              "iOS background BLE behavior is not implemented.",
              "No automatic restart, retry loop, or background gossip is claimed."
            ]

  @spec foreground_manual() :: t()
  def foreground_manual, do: %__MODULE__{}

  @spec supports?(t(), capability()) :: boolean()
  def supports?(%__MODULE__{} = profile, capability), do: capability in profile.supports

  @spec unsupported?(t(), capability()) :: boolean()
  def unsupported?(%__MODULE__{} = profile, capability),
    do: capability in profile.does_not_support

  @spec snapshot(t()) :: map()
  def snapshot(%__MODULE__{} = profile) do
    %{
      name: profile.name,
      supports: profile.supports,
      does_not_support: profile.does_not_support,
      lifecycle_notes: profile.lifecycle_notes
    }
  end
end
