defmodule Mob.Routing.Event do
  @moduledoc """
  Normalized transport event constructors.
  """

  @type transport_name :: atom()
  @type event ::
          {:mob_routing, transport_name(), {:peer_up, Mob.Routing.Peer.t()}}
          | {:mob_routing, transport_name(), {:peer_down, term()}}
          | {:mob_routing, transport_name(), {:frame, term(), binary()}}

  @spec peer_up(transport_name(), Mob.Routing.Peer.t()) :: event()
  def peer_up(transport, peer), do: {:mob_routing, transport, {:peer_up, peer}}

  @spec peer_down(transport_name(), term()) :: event()
  def peer_down(transport, peer_id), do: {:mob_routing, transport, {:peer_down, peer_id}}

  @spec frame(transport_name(), term(), binary()) :: event()
  def frame(transport, peer_id, bytes), do: {:mob_routing, transport, {:frame, peer_id, bytes}}
end
