defmodule MeshxTransport.Event do
  @moduledoc """
  Normalized transport event constructors.
  """

  @type transport_name :: atom()
  @type event ::
          {:meshx_transport, transport_name(), {:peer_up, MeshxTransport.Peer.t()}}
          | {:meshx_transport, transport_name(), {:peer_down, term()}}
          | {:meshx_transport, transport_name(), {:frame, term(), binary()}}

  @spec peer_up(transport_name(), MeshxTransport.Peer.t()) :: event()
  def peer_up(transport, peer), do: {:meshx_transport, transport, {:peer_up, peer}}

  @spec peer_down(transport_name(), term()) :: event()
  def peer_down(transport, peer_id), do: {:meshx_transport, transport, {:peer_down, peer_id}}

  @spec frame(transport_name(), term(), binary()) :: event()
  def frame(transport, peer_id, bytes), do: {:meshx_transport, transport, {:frame, peer_id, bytes}}
end
