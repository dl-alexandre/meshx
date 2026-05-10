defmodule MeshxMob.Platform do
  @moduledoc """
  Mobile platform context shared with transports and runtime policy.

  The struct captures the small set of platform facts that affect MeshX
  behavior before a native mobile bridge exists: operating system, background
  mode, granted permissions, the configured native bridge module, and arbitrary
  platform metadata.
  """

  @background_modes [:foreground, :background, :suspended]

  @enforce_keys [:os]
  defstruct os: :unknown,
            background_mode: :foreground,
            permissions: MapSet.new(),
            bridge: nil,
            metadata: %{}

  @type background_mode :: :foreground | :background | :suspended
  @type permission :: atom()

  @type t :: %__MODULE__{
          os: atom(),
          background_mode: background_mode(),
          permissions: MapSet.t(permission()),
          bridge: module() | nil,
          metadata: map()
        }

  @doc "Builds a platform context from a keyword list or map."
  @spec new(keyword() | map()) :: t()
  def new(attrs \\ %{}) do
    attrs = Map.new(attrs)

    %__MODULE__{
      os: get(attrs, :os, :unknown),
      background_mode: normalize_background_mode(get(attrs, :background_mode, :foreground)),
      permissions: normalize_permissions(get(attrs, :permissions, [])),
      bridge: get(attrs, :bridge, nil),
      metadata: get(attrs, :metadata, %{})
    }
  end

  @doc "Returns true when the platform is currently in background mode."
  @spec background?(t()) :: boolean()
  def background?(%__MODULE__{background_mode: :background}), do: true
  def background?(%__MODULE__{}), do: false

  @doc "Returns true when the platform has a permission."
  @spec permission?(t(), permission()) :: boolean()
  def permission?(%__MODULE__{permissions: permissions}, permission) do
    MapSet.member?(permissions, permission)
  end

  @doc "Returns an updated platform with a granted permission."
  @spec grant(t(), permission()) :: t()
  def grant(%__MODULE__{permissions: permissions} = platform, permission) do
    %{platform | permissions: MapSet.put(permissions, permission)}
  end

  @doc "Returns an updated platform with a revoked permission."
  @spec revoke(t(), permission()) :: t()
  def revoke(%__MODULE__{permissions: permissions} = platform, permission) do
    %{platform | permissions: MapSet.delete(permissions, permission)}
  end

  @doc """
  Converts platform context into peer metadata for transport advertisements.
  """
  @spec to_metadata(t()) :: map()
  def to_metadata(%__MODULE__{} = platform) do
    %{
      mobile: %{
        os: platform.os,
        background_mode: platform.background_mode,
        permissions: platform.permissions |> MapSet.to_list() |> Enum.sort(),
        bridge: platform.bridge,
        metadata: platform.metadata
      }
    }
  end

  @doc "Validates that a platform context is internally consistent."
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{background_mode: mode}) when mode not in @background_modes do
    {:error, {:invalid_background_mode, mode}}
  end

  def validate(%__MODULE__{metadata: metadata}) when not is_map(metadata) do
    {:error, :invalid_metadata}
  end

  def validate(%__MODULE__{}), do: :ok

  defp get(map, key, default) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp normalize_background_mode(mode) when mode in @background_modes, do: mode
  defp normalize_background_mode(_mode), do: :foreground

  defp normalize_permissions(%MapSet{} = permissions), do: permissions
  defp normalize_permissions(nil), do: MapSet.new()
  defp normalize_permissions(permissions) when is_list(permissions), do: MapSet.new(permissions)
end
