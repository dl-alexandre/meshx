defmodule MeshxMobileApp.BLE.AdvertGossipLedger do
  @moduledoc """
  In-memory suppression ledger for advertisement gossip planning.

  The ledger records when a message reference was last planned for
  advertisement gossip. It is pure caller-owned state, not persistence.
  """

  defstruct last_planned_at: %{}

  @type key :: {binary(), binary()}
  @type t :: %__MODULE__{last_planned_at: %{key() => integer()}}

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec suppressed?(t(), key(), integer(), non_neg_integer()) :: boolean()
  def suppressed?(%__MODULE__{} = ledger, key, now, min_interval_ms) do
    case Map.get(ledger.last_planned_at, key) do
      nil -> false
      planned_at -> now - planned_at < min_interval_ms
    end
  end

  @spec record(t(), [struct()]) :: t()
  def record(%__MODULE__{} = ledger, intents) when is_list(intents) do
    updates =
      Map.new(intents, fn intent ->
        {{intent.message_id_hash, intent.sender_peer_hash}, intent.planned_at}
      end)

    %{ledger | last_planned_at: Map.merge(ledger.last_planned_at, updates)}
  end
end
