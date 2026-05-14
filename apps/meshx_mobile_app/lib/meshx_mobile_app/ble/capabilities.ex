defmodule MeshxMobileApp.BLE.Capabilities do
  @moduledoc """
  Versioned capability descriptor exchanged at bridge handshake.

  Lets Kotlin ship before reaching iOS parity without iOS misreading
  silence as "unsupported". The runtime treats unknown features as
  absent — never crash on a feature the other side doesn't advertise.
  """

  @current_version 1

  @type role :: :central | :peripheral
  @type feature :: atom()

  @type t :: %__MODULE__{
          version: pos_integer(),
          roles: MapSet.t(role()),
          features: MapSet.t(feature())
        }

  defstruct version: 1, roles: %MapSet{}, features: %MapSet{}

  @spec current_version() :: pos_integer()
  def current_version, do: @current_version

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      version: Keyword.get(opts, :version, @current_version),
      roles: opts |> Keyword.get(:roles, []) |> MapSet.new(),
      features: opts |> Keyword.get(:features, []) |> MapSet.new()
    }
  end

  @spec has_feature?(t(), feature()) :: boolean()
  def has_feature?(%__MODULE__{features: features}, feature),
    do: MapSet.member?(features, feature)

  @spec has_role?(t(), role()) :: boolean()
  def has_role?(%__MODULE__{roles: roles}, role), do: MapSet.member?(roles, role)
end
