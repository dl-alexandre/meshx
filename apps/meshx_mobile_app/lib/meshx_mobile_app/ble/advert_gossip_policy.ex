defmodule MeshxMobileApp.BLE.AdvertGossipPolicy do
  @moduledoc """
  Pure policy for opportunistic advertisement gossip.

  The policy only decides when a previously seen local inbox item may be
  planned for another advertisement. It never sends, retries, persists,
  acknowledges, routes, encrypts, or opens a transport.
  """

  defstruct min_interval_ms: 30_000,
            max_intents: 16,
            default_ttl: 2,
            max_hops: 4,
            neighbor_cooldown_ms: 30_000

  @type t :: %__MODULE__{
          min_interval_ms: non_neg_integer(),
          max_intents: pos_integer(),
          default_ttl: pos_integer(),
          max_hops: pos_integer(),
          neighbor_cooldown_ms: non_neg_integer()
        }

  @spec default() :: t()
  def default, do: %__MODULE__{}

  @spec new(keyword()) :: {:ok, t()} | {:error, term()}
  def new(opts) do
    policy = %__MODULE__{
      min_interval_ms: Keyword.get(opts, :min_interval_ms, 30_000),
      max_intents: Keyword.get(opts, :max_intents, 16),
      default_ttl: Keyword.get(opts, :default_ttl, 2),
      max_hops: Keyword.get(opts, :max_hops, 4),
      neighbor_cooldown_ms: Keyword.get(opts, :neighbor_cooldown_ms, 30_000)
    }

    case validate(policy) do
      :ok -> {:ok, policy}
      {:error, _} = error -> error
    end
  end

  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{} = policy) do
    cond do
      not is_integer(policy.min_interval_ms) or policy.min_interval_ms < 0 ->
        {:error, :invalid_min_interval_ms}

      not is_integer(policy.max_intents) or policy.max_intents < 1 ->
        {:error, :invalid_max_intents}

      not is_integer(policy.default_ttl) or policy.default_ttl < 1 ->
        {:error, :invalid_default_ttl}

      not is_integer(policy.max_hops) or policy.max_hops < 1 ->
        {:error, :invalid_max_hops}

      policy.default_ttl > policy.max_hops ->
        {:error, :default_ttl_exceeds_max_hops}

      not is_integer(policy.neighbor_cooldown_ms) or policy.neighbor_cooldown_ms < 0 ->
        {:error, :invalid_neighbor_cooldown_ms}

      true ->
        :ok
    end
  end
end
