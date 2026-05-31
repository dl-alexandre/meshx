defmodule Mob.Node.BLE.LocalInboxFetchIntents do
  @moduledoc """
  Projects unresolved local inbox resolution statuses into fetch intents.

  This module builds `BeaconFetchRequest` records from `:needs_fetch`
  resolution statuses. It does not dispatch them, open a transport,
  route, persist, ACK, retry, encrypt, or claim message delivery.
  """

  alias Mob.Node.BLE.{BeaconFetchRequest, LocalInboxResolution}

  defmodule Intent do
    @moduledoc false

    @enforce_keys [
      :message_key,
      :resolution_state,
      :transport_state,
      :fetch_request,
      :notes
    ]
    defstruct @enforce_keys

    @type transport_state :: :blocked_unvalidated

    @type t :: %__MODULE__{
            message_key: binary(),
            resolution_state: :needs_fetch | :stale_needs_fetch,
            transport_state: transport_state(),
            fetch_request: BeaconFetchRequest.t(),
            notes: [atom()]
          }
  end

  @type opts :: [
          now: integer(),
          ttl_ms: pos_integer(),
          requesting_peer_id: binary() | nil,
          candidate_source_peer_ids: [binary()],
          id_fun: (map() -> binary())
        ]

  @spec from_snapshot(map(), opts()) :: {:ok, [Intent.t()]} | {:error, term()}
  def from_snapshot(%{} = snapshot, opts) do
    snapshot
    |> resolution_statuses()
    |> from_statuses(opts)
  end

  defp resolution_statuses(%{resolution_statuses: statuses}) when is_list(statuses), do: statuses
  defp resolution_statuses(%{} = snapshot), do: LocalInboxResolution.statuses(snapshot)

  @spec from_statuses([LocalInboxResolution.Status.t()], opts()) ::
          {:ok, [Intent.t()]} | {:error, term()}
  def from_statuses(statuses, opts) when is_list(statuses) do
    statuses
    |> Enum.filter(&fetch_needed?/1)
    |> Enum.reduce_while({:ok, []}, fn status, {:ok, acc} ->
      case from_status(status, opts) do
        {:ok, intent} -> {:cont, {:ok, [intent | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> reverse_ok()
  end

  def from_statuses(_statuses, _opts), do: {:error, :invalid_resolution_statuses}

  @spec from_status(LocalInboxResolution.Status.t(), opts()) ::
          {:ok, Intent.t()} | {:error, term()}
  def from_status(
        %LocalInboxResolution.Status{resolution_state: state, request: request} = status,
        opts
      )
      when state in [:needs_fetch, :stale_needs_fetch] and is_map(request) do
    case BeaconFetchRequest.from_resolver_result({:needs_fetch, request}, opts) do
      {:ok, fetch_request} ->
        {:ok,
         %Intent{
           message_key: status.message_key,
           resolution_state: state,
           transport_state: :blocked_unvalidated,
           fetch_request: fetch_request,
           notes: [:fetch_intent_only, :transport_not_validated, :no_dispatch]
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def from_status(%LocalInboxResolution.Status{}, _opts), do: {:error, :not_needed}
  def from_status(_status, _opts), do: {:error, :invalid_resolution_status}

  defp fetch_needed?(%LocalInboxResolution.Status{resolution_state: state})
       when state in [:needs_fetch, :stale_needs_fetch],
       do: true

  defp fetch_needed?(_status), do: false

  defp reverse_ok({:ok, list}), do: {:ok, Enum.reverse(list)}
  defp reverse_ok({:error, _reason} = error), do: error
end
