defmodule MeshxTransport.Peer do
  @moduledoc """
  Transport-agnostic peer descriptor.

  `id` is intentionally transport-defined. BLE might use a stable peripheral
  identifier; simulator transports can use strings; future transports may use
  public keys or compound route identifiers.
  """

  @enforce_keys [:id, :transport]
  defstruct [:id, :transport, :address, metadata: %{}, seen_at: nil]

  @type t :: %__MODULE__{
          id: term(),
          transport: atom(),
          address: term(),
          metadata: map(),
          seen_at: integer() | nil
        }

  @doc "Builds a peer descriptor with a monotonic `seen_at` timestamp."
  @spec new(term(), atom(), keyword()) :: t()
  def new(id, transport, attrs \\ []) do
    %__MODULE__{
      id: id,
      transport: transport,
      address: Keyword.get(attrs, :address),
      metadata: Keyword.get(attrs, :metadata, %{}),
      seen_at: Keyword.get(attrs, :seen_at, System.monotonic_time(:millisecond))
    }
  end
end
