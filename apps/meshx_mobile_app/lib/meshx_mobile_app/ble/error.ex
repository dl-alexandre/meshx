defmodule MeshxMobileApp.BLE.Error do
  @moduledoc """
  Closed atom taxonomy for BLE bridge errors.

  Every error surfaced from a platform bridge (iOS / Android / future Noop)
  must map to one of `kinds/0`. Free-form diagnostic strings live in the
  `:detail` field of `MeshxMobileApp.BLE.Events.Error` — never in the kind.

  Keeping this set closed lets the runtime pattern-match on `kind` for
  recovery policy without coupling to platform-specific error strings.
  """

  @kinds [
    :bluetooth_off,
    :unauthorized,
    :peripheral_unsupported,
    :advertise_failed,
    :scan_failed,
    :gatt_error,
    :timeout,
    :not_connected,
    :unknown
  ]

  @type kind ::
          :bluetooth_off
          | :unauthorized
          | :peripheral_unsupported
          | :advertise_failed
          | :scan_failed
          | :gatt_error
          | :timeout
          | :not_connected
          | :unknown

  @spec kinds() :: [kind()]
  def kinds, do: @kinds

  @spec valid_kind?(term()) :: boolean()
  def valid_kind?(kind) when kind in @kinds, do: true
  def valid_kind?(_), do: false

  @doc """
  Coerces an unknown atom into `:unknown`, leaving valid kinds unchanged.

  The bridge protocol decoder uses this so a future platform that invents
  a new error string never crashes the pipeline — it gets bucketed as
  `:unknown` with the original string preserved in `:detail`.
  """
  @spec coerce(term()) :: kind()
  def coerce(kind) when kind in @kinds, do: kind
  def coerce(_), do: :unknown
end
