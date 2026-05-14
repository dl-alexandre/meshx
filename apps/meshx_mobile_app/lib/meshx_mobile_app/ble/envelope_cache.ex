defmodule MeshxMobileApp.BLE.EnvelopeCache do
  @moduledoc """
  Bounded in-memory cache for canonical `MessageEnvelope` structs.

  Pure data structure. Callers own storage and clocks.
  """

  alias MeshxMobileApp.BLE.{BeaconRef, MessageEnvelope}

  defstruct max_entries: 32, ttl_ms: 60_000, entries: %{}

  @type entry :: %{envelope: MessageEnvelope.t(), inserted_at: integer(), expires_at: integer()}
  @type t :: %__MODULE__{
          max_entries: pos_integer(),
          ttl_ms: pos_integer(),
          entries: %{binary() => entry()}
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      max_entries: Keyword.get(opts, :max_entries, 32),
      ttl_ms: Keyword.get(opts, :ttl_ms, 60_000)
    }
  end

  @spec put(t(), MessageEnvelope.t(), keyword()) :: t()
  def put(%__MODULE__{} = cache, %MessageEnvelope{} = envelope, opts) do
    now = Keyword.fetch!(opts, :now)
    key = BeaconRef.message_id_hash(envelope)

    entry = %{
      envelope: envelope,
      inserted_at: now,
      expires_at: now + cache.ttl_ms
    }

    %{cache | entries: cache.entries |> Map.put(key, entry) |> trim(cache.max_entries)}
  end

  @spec get(t(), binary(), keyword()) :: {:ok, MessageEnvelope.t()} | :miss | :expired
  def get(%__MODULE__{} = cache, message_id_hash, opts) when is_binary(message_id_hash) do
    now = Keyword.fetch!(opts, :now)

    case Map.get(cache.entries, message_id_hash) do
      nil -> :miss
      %{expires_at: expires_at} when expires_at <= now -> :expired
      %{envelope: %MessageEnvelope{} = envelope} -> {:ok, envelope}
    end
  end

  @spec prune(t(), keyword()) :: t()
  def prune(%__MODULE__{} = cache, opts) do
    now = Keyword.fetch!(opts, :now)

    entries =
      Map.reject(cache.entries, fn {_key, %{expires_at: expires_at}} ->
        expires_at <= now
      end)

    %{cache | entries: entries}
  end

  defp trim(entries, max_entries) when map_size(entries) <= max_entries, do: entries

  defp trim(entries, max_entries) do
    entries
    |> Enum.sort_by(fn {_key, %{inserted_at: inserted_at}} -> inserted_at end)
    |> Enum.drop(max(map_size(entries) - max_entries, 0))
    |> Map.new()
  end
end
