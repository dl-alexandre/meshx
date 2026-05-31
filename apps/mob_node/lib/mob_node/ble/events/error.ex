defmodule Mob.Node.BLE.Events.Error do
  @moduledoc """
  Bridge-layer error. `kind` is drawn from the closed taxonomy in
  `Mob.Node.BLE.Error`; `detail` is a free-form diagnostic string
  that the runtime must not pattern-match on. `device_id` is set when
  the error is attributable to a specific transport peer.
  """

  @type t :: %__MODULE__{
          kind: Mob.Node.BLE.Error.kind(),
          detail: String.t(),
          device_id: binary() | nil
        }

  @enforce_keys [:kind]
  defstruct kind: :unknown, detail: "", device_id: nil
end
