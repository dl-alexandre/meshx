defmodule Mob.Node.BLE.LocalPersistenceProductionEvidenceReview do
  @moduledoc """
  Pure review contract for production-default local inbox persistence evidence.

  This module validates operator-supplied metadata for the
  `LocalPersistenceProductionLifecyclePlan` gates. It does not save, restore,
  migrate, prune, schedule work, write in the background, resolve beacon refs,
  route, ACK, retry, encrypt, authenticate, or run mobile lifecycle hooks.
  """

  alias Mob.Node.BLE.LocalPersistenceProductionLifecyclePlan

  defmodule Evidence do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :artifact_path,
               :summary,
               :test_command,
               :evidence_type,
               :decision_outcome,
               :blocked_claims_called_out
             ]}
    @enforce_keys [
      :artifact_path,
      :summary,
      :test_command,
      :evidence_type,
      :decision_outcome,
      :blocked_claims_called_out,
      :blocked_claims_called_out_container_valid?
    ]
    defstruct @enforce_keys
  end

  @required_gates [
    :default_lifecycle_decision,
    :schema_migration_policy,
    :scheduled_cleanup_worker,
    :background_safe_writer,
    :on_device_restore_fixture,
    :release_artifact_evidence
  ]

  @required_blocked_claims [
    :delivery_record,
    :trusted_message_delivery,
    :background_persistence,
    :full_message_resolution
  ]

  @required_evidence_types %{
    default_lifecycle_decision: :product_decision,
    schema_migration_policy: :migration_test,
    scheduled_cleanup_worker: :cleanup_test,
    background_safe_writer: :lifecycle_writer_test,
    on_device_restore_fixture: :on_device_restore_fixture,
    release_artifact_evidence: :release_artifact_review
  }

  @allowed_decision_outcomes [
    :keep_memory_only_default,
    :promote_durable_default
  ]

  @spec required_gates() :: [atom()]
  def required_gates, do: @required_gates

  @spec required_blocked_claims() :: [atom()]
  def required_blocked_claims, do: @required_blocked_claims

  @spec required_evidence_types() :: %{atom() => atom()}
  def required_evidence_types, do: @required_evidence_types

  @spec allowed_decision_outcomes() :: [atom()]
  def allowed_decision_outcomes, do: @allowed_decision_outcomes

  @spec review(map()) :: map()
  def review(input) when is_map(input) do
    plan = LocalPersistenceProductionLifecyclePlan.snapshot()

    evidence_by_gate =
      @required_gates
      |> Map.new(fn gate_id ->
        {gate_id, evidence(get_field(input, gate_id, %{}))}
      end)

    missing =
      []
      |> missing_gate_sections(input)
      |> malformed_gate_sections(input)
      |> missing_gate_evidence(evidence_by_gate, plan)
      |> Enum.reverse()

    %{
      review_version: 1,
      boundary: :production_default_persistence_evidence_review,
      status: if(missing == [], do: :ready, else: :open),
      production_persistence_evidence_complete?: missing == [],
      production_default_persistence_allowed?: false,
      default_persistence_claim_allowed?: false,
      background_persistence_claim_allowed?: false,
      delivery_record_claim_allowed?: false,
      full_message_resolution_claim_allowed?: false,
      production_lifecycle_plan: plan,
      required_gates: @required_gates,
      required_blocked_claims: @required_blocked_claims,
      evidence_by_gate: evidence_by_gate,
      missing: missing,
      notes: [
        "Ready evidence means the supplied metadata covers the production-default persistence plan gates.",
        "This review does not enable default persistence or inspect device logs by itself.",
        "Persisted local inbox snapshots remain read models, not delivery records."
      ]
    }
  end

  @spec json_review(map()) :: map()
  def json_review(input) do
    input
    |> review()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  @spec template_input() :: map()
  def template_input do
    @required_gates
    |> Map.new(fn gate_id ->
      {Atom.to_string(gate_id),
       %{
         "artifact_path" => "",
         "summary" => "",
         "test_command" => "",
         "evidence_type" =>
           @required_evidence_types
           |> Map.fetch!(gate_id)
           |> Atom.to_string(),
         "decision_outcome" => decision_outcome_template(gate_id),
         "blocked_claims_called_out" => []
       }}
    end)
  end

  defp missing_gate_evidence(missing, evidence_by_gate, plan) do
    gate_blocked_claims = gate_blocked_claims(plan)

    Enum.reduce(@required_gates, missing, fn gate_id, acc ->
      item = Map.fetch!(evidence_by_gate, gate_id)
      missing_claims = @required_blocked_claims -- item.blocked_claims_called_out

      missing_gate_claims =
        Map.fetch!(gate_blocked_claims, gate_id) -- item.blocked_claims_called_out

      []
      |> missing_field(item, gate_id, :artifact_path)
      |> malformed_string_field(item, gate_id, :artifact_path)
      |> non_trimmed_text(item, gate_id, :artifact_path)
      |> non_relative_artifact_path(item, gate_id)
      |> missing_field(item, gate_id, :summary)
      |> malformed_string_field(item, gate_id, :summary)
      |> non_trimmed_text(item, gate_id, :summary)
      |> missing_field(item, gate_id, :test_command)
      |> malformed_string_field(item, gate_id, :test_command)
      |> non_trimmed_text(item, gate_id, :test_command)
      |> missing_field(item, gate_id, :evidence_type)
      |> wrong_evidence_type(item, gate_id)
      |> invalid_decision_outcome(item, gate_id)
      |> maybe_missing(
        item.blocked_claims_called_out_container_valid?,
        "#{gate_id} blocked_claims_called_out must be a list."
      )
      |> maybe_missing(
        missing_claims == [],
        "#{gate_id} missing blocked claim callouts: #{inspect(missing_claims)}."
      )
      |> maybe_missing(
        missing_gate_claims == [],
        "#{gate_id} missing gate-specific blocked claim callouts: #{inspect(missing_gate_claims)}."
      )
      |> Kernel.++(acc)
    end)
  end

  defp missing_gate_sections(missing, input) do
    Enum.reduce(@required_gates, missing, fn gate_id, acc ->
      if has_field?(input, gate_id) do
        acc
      else
        ["Missing #{gate_id} evidence section." | acc]
      end
    end)
  end

  defp malformed_gate_sections(missing, input) do
    Enum.reduce(@required_gates, missing, fn gate_id, acc ->
      value = get_field(input, gate_id, %{})

      if is_map(value) do
        acc
      else
        ["#{gate_id} evidence section must be an object." | acc]
      end
    end)
  end

  defp gate_blocked_claims(plan) do
    Map.new(plan.gates, &{&1.id, &1.blocked_claims})
  end

  defp missing_field(missing, evidence, gate_id, field) do
    if present?(Map.fetch!(evidence, field)) do
      missing
    else
      ["#{gate_id} missing #{field}." | missing]
    end
  end

  defp malformed_string_field(missing, evidence, gate_id, field) do
    value = Map.fetch!(evidence, field)

    if is_nil(value) or is_binary(value) do
      missing
    else
      ["#{gate_id} #{field} must be a string." | missing]
    end
  end

  defp non_trimmed_text(missing, evidence, gate_id, field) do
    value = Map.fetch!(evidence, field)

    if not is_binary(value) or value == String.trim(value) do
      missing
    else
      ["#{gate_id} #{field} must not have leading or trailing whitespace." | missing]
    end
  end

  defp non_relative_artifact_path(missing, evidence, gate_id) do
    if relative_artifact_path?(evidence.artifact_path) do
      missing
    else
      ["#{gate_id} artifact_path must be a relative artifact path." | missing]
    end
  end

  defp wrong_evidence_type(missing, evidence, gate_id) do
    expected = Map.fetch!(@required_evidence_types, gate_id)

    if evidence.evidence_type == expected do
      missing
    else
      ["#{gate_id} evidence_type must be #{inspect(expected)}." | missing]
    end
  end

  defp maybe_missing(missing, true, _message), do: missing
  defp maybe_missing(missing, false, message), do: [message | missing]

  defp evidence(%Evidence{} = evidence), do: evidence

  defp evidence(input) when is_map(input) do
    blocked_claims_called_out = get_field(input, :blocked_claims_called_out, [])

    struct!(Evidence, %{
      artifact_path: get_field(input, :artifact_path),
      summary: get_field(input, :summary),
      test_command: get_field(input, :test_command),
      evidence_type: atom_value(get_field(input, :evidence_type)),
      decision_outcome: atom_value(get_field(input, :decision_outcome)),
      blocked_claims_called_out: atom_list(blocked_claims_called_out),
      blocked_claims_called_out_container_valid?: is_list(blocked_claims_called_out)
    })
  end

  defp evidence(_input), do: evidence(%{})

  defp invalid_decision_outcome(missing, evidence, :default_lifecycle_decision) do
    cond do
      is_nil(evidence.decision_outcome) ->
        ["default_lifecycle_decision missing decision_outcome." | missing]

      evidence.decision_outcome in @allowed_decision_outcomes ->
        missing

      true ->
        [
          "default_lifecycle_decision decision_outcome must be one of #{inspect(@allowed_decision_outcomes)}."
          | missing
        ]
    end
  end

  defp invalid_decision_outcome(missing, _evidence, _gate_id), do: missing

  defp decision_outcome_template(:default_lifecycle_decision), do: ""
  defp decision_outcome_template(_gate_id), do: nil

  defp get_field(input, field, default \\ nil) when is_atom(field) do
    Map.get(input, field, Map.get(input, Atom.to_string(field), default))
  end

  defp has_field?(input, field) when is_atom(field) do
    Map.has_key?(input, field) or Map.has_key?(input, Atom.to_string(field))
  end

  defp atom_list(values) when is_list(values), do: Enum.map(values, &atom_value/1)
  defp atom_list(_value), do: []

  defp atom_value(value) when is_atom(value), do: value

  defp atom_value(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> value
  end

  defp atom_value(value), do: value

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)

  defp relative_artifact_path?(value) when is_binary(value) do
    trimmed = String.trim(value)

    present?(trimmed) and
      not String.match?(trimmed, ~r/^[A-Za-z]:[\\\/]/) and
      not String.starts_with?(trimmed, ["/", "\\\\", "~", "file:", "http:", "https:"]) and
      not String.contains?(trimmed, "..")
  end

  defp relative_artifact_path?(_value), do: true
end
