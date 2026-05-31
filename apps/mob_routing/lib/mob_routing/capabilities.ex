defmodule Mob.Routing.Capabilities do
  @moduledoc """
  Transport/runtime capability metadata advertised by peers.

  This is intentionally data-only so native bridges, simulator transports, and
  future transports can publish the same shape through peer metadata.
  """

  defstruct protocol_version: 1,
            mtu: nil,
            secure_required?: false,
            relay?: true,
            background_mode: :foreground

  @type t :: %__MODULE__{
          protocol_version: pos_integer(),
          mtu: pos_integer() | nil,
          secure_required?: boolean(),
          relay?: boolean(),
          background_mode: atom()
        }

  @spec new(keyword() | map()) :: t()
  def new(attrs \\ %{}) do
    attrs = Map.new(attrs)

    %__MODULE__{
      protocol_version: get(attrs, :protocol_version, 1),
      mtu: get(attrs, :mtu, nil),
      secure_required?: get(attrs, :secure_required?, get(attrs, :secure_required, false)),
      relay?: get(attrs, :relay?, get(attrs, :relay, true)),
      background_mode: get(attrs, :background_mode, :foreground)
    }
  end

  @spec from_metadata(map()) :: t()
  def from_metadata(%{capabilities: %__MODULE__{} = capabilities}), do: capabilities
  def from_metadata(%{"capabilities" => %__MODULE__{} = capabilities}), do: capabilities
  def from_metadata(%{capabilities: capabilities}) when is_map(capabilities), do: new(capabilities)
  def from_metadata(%{"capabilities" => capabilities}) when is_map(capabilities), do: new(capabilities)
  def from_metadata(metadata) when is_map(metadata), do: new(metadata)

  @spec to_metadata(t()) :: map()
  def to_metadata(%__MODULE__{} = capabilities) do
    %{
      capabilities: %{
        protocol_version: capabilities.protocol_version,
        mtu: capabilities.mtu,
        secure_required: capabilities.secure_required?,
        relay: capabilities.relay?,
        background_mode: capabilities.background_mode
      }
    }
  end

  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = local, %__MODULE__{} = remote) do
    %__MODULE__{
      protocol_version: min(local.protocol_version, remote.protocol_version),
      mtu: min_non_nil(local.mtu, remote.mtu),
      secure_required?: local.secure_required? or remote.secure_required?,
      relay?: local.relay? and remote.relay?,
      background_mode: stricter_background(local.background_mode, remote.background_mode)
    }
  end

  defp get(map, key, default) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp min_non_nil(nil, value), do: value
  defp min_non_nil(value, nil), do: value
  defp min_non_nil(left, right), do: min(left, right)

  defp stricter_background(:background, _other), do: :background
  defp stricter_background(_other, :background), do: :background
  defp stricter_background(left, _right), do: left
end
