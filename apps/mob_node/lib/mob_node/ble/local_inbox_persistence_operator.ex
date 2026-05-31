defmodule Mob.Node.BLE.LocalInboxPersistenceOperator do
  @moduledoc """
  Operator-facing controls for opt-in local inbox persistence.

  These controls wrap the durable local inbox store with explicit operator
  actions and status data. They do not enable default persistence, schedule
  cleanup, write in the background, resolve beacon refs, fetch envelopes,
  route, ACK, retry, encrypt, or authenticate messages.
  """

  alias Mob.Node.BLE.{LocalInboxStore, LocalInboxPersistenceProfile}

  @type action_id ::
          :status
          | :save_snapshot
          | :restore_snapshot
          | :prune_expired
          | :clear_snapshot
          | :clear_all

  @type action :: %{
          required(:id) => action_id(),
          required(:status) => :available | :manual_only,
          required(:command) => binary(),
          required(:notes) => [binary()],
          required(:blocked_claims) => [atom()]
        }

  @blocked_claims [
    :default_app_persistence,
    :background_persistence,
    :scheduled_cleanup,
    :delivery_record,
    :full_message_resolution,
    :trusted_message_delivery
  ]

  @spec actions() :: [action()]
  def actions do
    [
      action(
        :status,
        :available,
        "LocalInboxPersistenceOperator.status(now: <timestamp_ms>)",
        [
          "Lists saved local inbox snapshots and expiry state.",
          "Requires an injected clock for deterministic expiry reporting."
        ]
      ),
      action(
        :save_snapshot,
        :available,
        "LocalInboxPersistenceOperator.save_snapshot(snapshot, persisted_at: <timestamp_ms>)",
        [
          "Saves only the policy-approved durable snapshot shape.",
          "Does not persist raw transport metadata."
        ]
      ),
      action(
        :restore_snapshot,
        :available,
        "LocalInboxPersistenceOperator.restore_snapshot(snapshot_id: :default)",
        [
          "Restores a read model for display/query use.",
          "Restored beacon refs remain unresolved pointers."
        ]
      ),
      action(
        :prune_expired,
        :manual_only,
        "LocalInboxPersistenceOperator.prune_expired(now: <timestamp_ms>)",
        [
          "Deletes only expired snapshots using an injected clock.",
          "No scheduled cleanup worker exists."
        ]
      ),
      action(
        :clear_snapshot,
        :manual_only,
        "LocalInboxPersistenceOperator.clear_snapshot(snapshot_id: :default)",
        [
          "Deletes one selected local inbox snapshot.",
          "Does not clear raw hardware evidence bundles."
        ]
      ),
      action(
        :clear_all,
        :manual_only,
        "LocalInboxPersistenceOperator.clear_all()",
        [
          "Deletes all local inbox snapshots.",
          "Does not disable future opt-in saves by itself."
        ]
      )
    ]
  end

  @spec snapshot() :: map()
  def snapshot do
    %{
      control_version: 1,
      boundary: :operator_opt_in_local_inbox_persistence,
      default_profile: profile_summary(LocalInboxPersistenceProfile.memory_only()),
      opt_in_profile: profile_summary(LocalInboxPersistenceProfile.opt_in_durable()),
      actions: actions(),
      default_persistence_enabled?: false,
      background_writes_enabled?: false,
      scheduled_cleanup_enabled?: false,
      blocked_claims: @blocked_claims,
      notes: [
        "Controls are explicit operator actions over the durable local inbox store.",
        "Default app sessions remain memory-only unless opt-in session options are used.",
        "Persistence preserves nearby-message read models, not delivery proof."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  @spec status(keyword()) :: map() | {:error, :missing_now | :invalid_now}
  def status(opts \\ []) do
    case Keyword.fetch(opts, :now) do
      {:ok, now} when is_integer(now) ->
        summaries = LocalInboxStore.list(now: now)

        %{
          snapshot_count: length(summaries),
          expired_count: Enum.count(summaries, & &1.expired?),
          snapshots: summaries,
          default_persistence_enabled?: false,
          background_writes_enabled?: false,
          scheduled_cleanup_enabled?: false
        }

      {:ok, _now} ->
        {:error, :invalid_now}

      :error ->
        {:error, :missing_now}
    end
  end

  @spec save_snapshot(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def save_snapshot(local_snapshot, opts \\ []) do
    LocalInboxStore.save(local_snapshot, opts)
  end

  @spec restore_snapshot(keyword()) :: {:ok, map()} | {:error, term()}
  def restore_snapshot(opts \\ []) do
    opts
    |> Keyword.get(:snapshot_id, :default)
    |> LocalInboxStore.load_read_model(opts)
  end

  @spec prune_expired(keyword()) :: {:ok, [LocalInboxStore.snapshot_id()]} | {:error, term()}
  def prune_expired(opts \\ []) do
    LocalInboxStore.prune_expired(opts)
  end

  @spec clear_snapshot(keyword()) :: :ok | {:error, term()}
  def clear_snapshot(opts \\ []) do
    opts
    |> Keyword.get(:snapshot_id, :default)
    |> LocalInboxStore.delete()
  end

  @spec clear_all() :: :ok
  def clear_all, do: LocalInboxStore.clear()

  defp profile_summary(profile) do
    %{
      mode: profile.mode,
      enabled?: profile.enabled?,
      restore_on_start?: profile.restore_on_start?,
      snapshot_id: profile.snapshot_id,
      save_triggers: profile.save_triggers,
      cleanup: profile.cleanup,
      session_options: Map.new(profile.session_options),
      operator_notes: profile.operator_notes,
      unsupported_claims: profile.unsupported_claims
    }
  end

  defp action(id, status, command, notes) do
    %{
      id: id,
      status: status,
      command: command,
      notes: notes,
      blocked_claims: @blocked_claims
    }
  end
end
