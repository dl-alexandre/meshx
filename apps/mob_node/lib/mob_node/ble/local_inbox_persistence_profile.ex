defmodule Mob.Node.BLE.LocalInboxPersistenceProfile do
  @moduledoc """
  Runtime persistence profile for advertisement-only local inbox snapshots.

  The durable store already exists, but app persistence is still an operator
  choice. This module makes that choice explicit and machine-checkable. It
  does not save snapshots, prune storage, schedule work, start background
  services, resolve beacon refs, fetch envelopes, route, ACK, retry, or
  encrypt data.
  """

  alias Mob.Node.BLE.LocalInboxPersistencePolicy

  @modes [:memory_only, :opt_in_durable]

  @type mode :: :memory_only | :opt_in_durable
  @type t :: %{
          required(:profile_version) => pos_integer(),
          required(:mode) => mode(),
          required(:enabled?) => boolean(),
          required(:restore_on_start?) => boolean(),
          required(:snapshot_id) => atom() | binary(),
          required(:policy) => LocalInboxPersistencePolicy.t(),
          required(:save_triggers) => [atom()],
          required(:cleanup) => map(),
          required(:session_options) => keyword(),
          required(:operator_notes) => [binary()],
          required(:unsupported_claims) => [binary()]
        }

  @spec memory_only(keyword()) :: t()
  def memory_only(opts \\ []) do
    profile(:memory_only, opts)
  end

  @spec opt_in_durable(keyword()) :: t()
  def opt_in_durable(opts \\ []) do
    profile(:opt_in_durable, opts)
  end

  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%{mode: mode}) when mode not in @modes, do: {:error, :invalid_mode}

  def validate(%{snapshot_id: snapshot_id})
      when not (is_atom(snapshot_id) or is_binary(snapshot_id)) do
    {:error, :invalid_snapshot_id}
  end

  def validate(%{policy: %LocalInboxPersistencePolicy{}}), do: :ok
  def validate(%{policy: _policy}), do: {:error, :invalid_policy}
  def validate(_profile), do: {:error, :invalid_profile}

  @spec session_options(t()) :: keyword()
  def session_options(%{} = profile), do: profile.session_options

  defp profile(mode, opts) do
    snapshot_id = Keyword.get(opts, :snapshot_id, :default)
    restore? = Keyword.get(opts, :restore_on_start?, mode == :opt_in_durable)
    policy = Keyword.get(opts, :policy, LocalInboxPersistencePolicy.default())
    enabled? = mode == :opt_in_durable

    %{
      profile_version: 1,
      mode: mode,
      enabled?: enabled?,
      restore_on_start?: restore?,
      snapshot_id: snapshot_id,
      policy: policy,
      save_triggers: save_triggers(mode),
      cleanup: cleanup(mode),
      session_options: [
        persist_local_inbox?: enabled?,
        restore_local_inbox?: enabled? and restore?,
        local_inbox_snapshot_id: snapshot_id
      ],
      operator_notes: operator_notes(mode),
      unsupported_claims: [
        "Persistence does not make beacon refs resolvable.",
        "Persistence does not create delivery guarantees.",
        "Persistence does not run cleanup in the background.",
        "Persistence does not store raw transport metadata or crypto material."
      ]
    }
  end

  defp save_triggers(:memory_only), do: []

  defp save_triggers(:opt_in_durable) do
    [
      :received_full_message,
      :received_message_beacon,
      :session_stop
    ]
  end

  defp cleanup(:memory_only) do
    %{
      scheduled?: false,
      operator_command: nil,
      notes: ["No durable snapshots are written in memory-only mode."]
    }
  end

  defp cleanup(:opt_in_durable) do
    %{
      scheduled?: false,
      operator_command: "LocalInboxStore.prune_expired(now: <timestamp_ms>)",
      notes: [
        "Cleanup remains caller-driven with an injected clock.",
        "No scheduled worker or background-safe write loop exists."
      ]
    }
  end

  defp operator_notes(:memory_only) do
    [
      "Default local inbox behavior remains memory-only.",
      "Restarting the app drops nearby-message observations unless opt-in durable mode is used."
    ]
  end

  defp operator_notes(:opt_in_durable) do
    [
      "Opt-in durable mode saves policy-approved local inbox snapshots.",
      "Restore is enabled by default for the selected snapshot_id.",
      "Durable data remains a local read model, not delivery proof."
    ]
  end
end
