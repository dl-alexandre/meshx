defmodule Mob.Node.MeshStatusBanner do
  @moduledoc false

  @doc "Banner colors: `{background, headline_color, detail_color}`."
  def colors_for(:ready), do: {:primary, :on_primary, :on_primary}
  def colors_for(:listening), do: {:surface, :primary, :muted}
  def colors_for(:radio_off), do: {:surface, :on_surface, :muted}
  def colors_for(:not_ready), do: {:surface, :on_surface, :muted}
end
