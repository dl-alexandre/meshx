defmodule MeshxMobileApp.BLE.LocalSecurityReleaseEvidenceReview do
  @moduledoc """
  Pure review contract for local security release evidence.

  This module validates operator-supplied security evidence metadata before
  authenticated or trusted wording can be used. It does not read files,
  persist keys, persist trust, persist replay state, fetch envelopes, inspect
  hardware, route, ACK, retry, encrypt, or run background work.
  """

  alias MeshxMobileApp.BLE.LocalSecurityIdentityValidationPlan

  defmodule SecurityAttachment do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :artifact_id,
               :path,
               :source,
               :plan_gate_ids,
               :evidence_types_by_gate,
               :blocked_claims_called_out,
               :operator_reviewed?
             ]}
    @enforce_keys [
      :artifact_id,
      :path,
      :source,
      :plan_gate_ids,
      :evidence_types_by_gate,
      :blocked_claims_called_out,
      :operator_reviewed?,
      :plan_gate_ids_container_valid?,
      :evidence_types_by_gate_container_valid?,
      :blocked_claims_called_out_container_valid?,
      :operator_reviewed_valid?
    ]
    defstruct @enforce_keys
  end

  @required_plan_gate_ids [
    :peer_key_enrollment,
    :authorship_fixture_matrix,
    :replay_state_lifecycle,
    :trust_policy_lifecycle,
    :canonical_replay_integration,
    :beacon_ref_authentication_integration,
    :release_artifact_evidence,
    :negative_claim_review
  ]

  @required_blocked_claims [
    :authenticated_peer_identity,
    :authenticated_message,
    :trusted_message,
    :trusted_delivery,
    :fresh_message
  ]

  @required_evidence_types %{
    peer_key_enrollment: :peer_key_enrollment_fixture,
    authorship_fixture_matrix: :authorship_fixture_matrix,
    replay_state_lifecycle: :replay_lifecycle_validation,
    trust_policy_lifecycle: :trust_lifecycle_validation,
    canonical_replay_integration: :canonical_replay_decision_fixture,
    beacon_ref_authentication_integration: :beacon_authentication_fixture,
    release_artifact_evidence: :release_artifact_review,
    negative_claim_review: :crypto_negative_fixture_matrix
  }

  @spec required_plan_gate_ids() :: [atom()]
  def required_plan_gate_ids, do: @required_plan_gate_ids

  @spec required_blocked_claims() :: [atom()]
  def required_blocked_claims, do: @required_blocked_claims

  @spec required_evidence_types() :: %{atom() => atom()}
  def required_evidence_types, do: @required_evidence_types

  @spec required_gate_blocked_claims() :: %{atom() => [atom()]}
  def required_gate_blocked_claims do
    LocalSecurityIdentityValidationPlan.snapshot()
    |> gate_blocked_claims()
  end

  @spec review(map()) :: map()
  def review(input) when is_map(input) do
    validation_plan = LocalSecurityIdentityValidationPlan.snapshot()
    gate_blocked_claims = gate_blocked_claims(validation_plan)
    security_attachments = get_field(input, :security_attachments, [])

    attachments =
      if is_list(security_attachments) do
        Enum.map(security_attachments, &security_attachment/1)
      else
        []
      end

    represented_gate_ids =
      attachments
      |> Enum.flat_map(& &1.plan_gate_ids)
      |> Enum.uniq()

    called_out_claims =
      attachments
      |> Enum.flat_map(& &1.blocked_claims_called_out)
      |> Enum.uniq()

    missing =
      []
      |> missing_required_paths(input)
      |> malformed_required_paths(input)
      |> non_trimmed_required_paths(input)
      |> non_relative_required_paths(input)
      |> malformed_attachments_container(security_attachments)
      |> missing_attachments(attachments)
      |> missing_gate_coverage(represented_gate_ids)
      |> missing_blocked_claim_callouts(called_out_claims)
      |> malformed_attachment_containers(attachments)
      |> missing_gate_specific_blocked_claim_callouts(attachments, gate_blocked_claims)
      |> missing_operator_review(attachments)
      |> malformed_operator_review(attachments)
      |> Enum.reverse()

    %{
      review_version: 1,
      boundary: :local_security_release_evidence_review,
      status: if(missing == [], do: :ready, else: :open),
      security_release_evidence_complete?: missing == [],
      authenticated_peer_identity_claim_allowed?: false,
      authenticated_message_claim_allowed?: false,
      trusted_message_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      plan_gate_ids: plan_gate_ids(validation_plan),
      required_plan_gate_ids: @required_plan_gate_ids,
      represented_plan_gate_ids: represented_gate_ids,
      missing_plan_gate_ids: @required_plan_gate_ids -- represented_gate_ids,
      required_blocked_claims: @required_blocked_claims,
      called_out_blocked_claims: called_out_claims,
      missing_blocked_claims: @required_blocked_claims -- called_out_claims,
      security_attachments: attachments,
      missing: missing,
      notes: [
        "Ready review means security evidence is packaged; it does not enable trusted delivery.",
        "Authenticated/trusted wording remains blocked until the underlying security validation gates close.",
        "Full beacon authentication still depends on real full-envelope resolution transport evidence."
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
    %{
      "readiness_manifest_path" => "",
      "release_manifest_path" => "",
      "security_manifest_path" => "",
      "security_attachments" => [
        %{
          "artifact_id" => "",
          "path" => "",
          "source" => "",
          "plan_gate_ids" => Enum.map(@required_plan_gate_ids, &Atom.to_string/1),
          "evidence_types_by_gate" =>
            Map.new(@required_evidence_types, fn {gate_id, evidence_type} ->
              {Atom.to_string(gate_id), Atom.to_string(evidence_type)}
            end),
          "blocked_claims_called_out" => [],
          "operator_reviewed?" => false
        }
      ]
    }
  end

  defp missing_required_paths(missing, input) do
    [:readiness_manifest_path, :release_manifest_path, :security_manifest_path]
    |> Enum.reduce(missing, fn field, acc ->
      if present?(get_field(input, field)) do
        acc
      else
        ["Missing #{field}." | acc]
      end
    end)
  end

  defp malformed_required_paths(missing, input) do
    [:readiness_manifest_path, :release_manifest_path, :security_manifest_path]
    |> Enum.reduce(missing, fn field, acc ->
      value = get_field(input, field)

      if is_nil(value) or is_binary(value) do
        acc
      else
        ["#{field} must be a string." | acc]
      end
    end)
  end

  defp non_trimmed_required_paths(missing, input) do
    [:readiness_manifest_path, :release_manifest_path, :security_manifest_path]
    |> Enum.reduce(missing, fn field, acc ->
      value = get_field(input, field)

      if not is_binary(value) or value == String.trim(value) do
        acc
      else
        ["#{field} must not have leading or trailing whitespace." | acc]
      end
    end)
  end

  defp non_relative_required_paths(missing, input) do
    [:readiness_manifest_path, :release_manifest_path, :security_manifest_path]
    |> Enum.reduce(missing, fn field, acc ->
      value = get_field(input, field)

      if relative_artifact_path?(value) do
        acc
      else
        ["#{field} must be a relative artifact path." | acc]
      end
    end)
  end

  defp missing_attachments(missing, []),
    do: ["Missing at least one security attachment." | missing]

  defp missing_attachments(missing, attachments) do
    attachments
    |> Enum.with_index(1)
    |> Enum.reduce(missing, fn {attachment, index}, acc ->
      []
      |> missing_attachment_field(attachment, index, :artifact_id)
      |> malformed_attachment_string_field(attachment, index, :artifact_id)
      |> non_trimmed_attachment_text(attachment, index, :artifact_id)
      |> missing_attachment_field(attachment, index, :path)
      |> malformed_attachment_string_field(attachment, index, :path)
      |> non_trimmed_attachment_text(attachment, index, :path)
      |> non_relative_attachment_path(attachment, index)
      |> missing_attachment_field(attachment, index, :source)
      |> malformed_attachment_string_field(attachment, index, :source)
      |> non_trimmed_attachment_text(attachment, index, :source)
      |> missing_attachment_gate_ids(attachment, index)
      |> missing_attachment_evidence_types(attachment, index)
      |> Kernel.++(acc)
    end)
  end

  defp malformed_attachments_container(missing, attachments) do
    if is_list(attachments) do
      missing
    else
      ["security_attachments must be a list." | missing]
    end
  end

  defp malformed_attachment_containers(missing, attachments) do
    attachments
    |> Enum.with_index(1)
    |> Enum.reduce(missing, fn {attachment, index}, acc ->
      acc
      |> maybe_attachment_container_error(
        attachment.plan_gate_ids_container_valid?,
        index,
        "plan_gate_ids must be a list."
      )
      |> maybe_attachment_container_error(
        attachment.evidence_types_by_gate_container_valid?,
        index,
        "evidence_types_by_gate must be an object."
      )
      |> maybe_attachment_container_error(
        attachment.blocked_claims_called_out_container_valid?,
        index,
        "blocked_claims_called_out must be a list."
      )
    end)
  end

  defp maybe_attachment_container_error(missing, true, _index, _message), do: missing

  defp maybe_attachment_container_error(missing, false, index, message),
    do: ["Security attachment #{index} #{message}" | missing]

  defp missing_attachment_field(missing, attachment, index, field) do
    if present?(Map.fetch!(attachment, field)) do
      missing
    else
      ["Security attachment #{index} missing #{field}." | missing]
    end
  end

  defp malformed_attachment_string_field(missing, attachment, index, field) do
    value = Map.fetch!(attachment, field)

    if is_nil(value) or is_binary(value) do
      missing
    else
      ["Security attachment #{index} #{field} must be a string." | missing]
    end
  end

  defp non_trimmed_attachment_text(missing, attachment, index, field) do
    value = Map.fetch!(attachment, field)

    if not is_binary(value) or value == String.trim(value) do
      missing
    else
      [
        "Security attachment #{index} #{field} must not have leading or trailing whitespace."
        | missing
      ]
    end
  end

  defp non_relative_attachment_path(missing, attachment, index) do
    if relative_artifact_path?(attachment.path) do
      missing
    else
      ["Security attachment #{index} path must be a relative artifact path." | missing]
    end
  end

  defp missing_attachment_gate_ids(missing, attachment, index) do
    if attachment.plan_gate_ids == [] do
      ["Security attachment #{index} missing plan_gate_ids." | missing]
    else
      missing
    end
  end

  defp missing_attachment_evidence_types(missing, attachment, index) do
    Enum.reduce(attachment.plan_gate_ids, missing, fn gate_id, acc ->
      case Map.fetch(@required_evidence_types, gate_id) do
        {:ok, expected} ->
          if Map.get(attachment.evidence_types_by_gate, gate_id) == expected do
            acc
          else
            [
              "Security attachment #{index} gate #{gate_id} evidence_type must be #{inspect(expected)}."
              | acc
            ]
          end

        :error ->
          ["Security attachment #{index} has unknown plan_gate_id #{inspect(gate_id)}." | acc]
      end
    end)
  end

  defp missing_gate_coverage(missing, represented_gate_ids) do
    case @required_plan_gate_ids -- represented_gate_ids do
      [] ->
        missing

      missing_gate_ids ->
        ["Missing security plan gate evidence: #{inspect(missing_gate_ids)}." | missing]
    end
  end

  defp missing_blocked_claim_callouts(missing, called_out_claims) do
    case @required_blocked_claims -- called_out_claims do
      [] ->
        missing

      missing_claims ->
        ["Missing security blocked claim callouts: #{inspect(missing_claims)}." | missing]
    end
  end

  defp missing_gate_specific_blocked_claim_callouts(missing, attachments, gate_blocked_claims) do
    attachments
    |> Enum.with_index(1)
    |> Enum.reduce(missing, fn {attachment, index}, acc ->
      Enum.reduce(attachment.plan_gate_ids, acc, fn gate_id, gate_acc ->
        required_claims = Map.get(gate_blocked_claims, gate_id, [])
        missing_claims = required_claims -- attachment.blocked_claims_called_out

        if missing_claims == [] do
          gate_acc
        else
          [
            "Security attachment #{index} gate #{gate_id} missing gate-specific blocked claim callouts: #{inspect(missing_claims)}."
            | gate_acc
          ]
        end
      end)
    end)
  end

  defp missing_operator_review(missing, attachments) do
    if Enum.all?(attachments, & &1.operator_reviewed?) do
      missing
    else
      ["Security attachments must be operator reviewed." | missing]
    end
  end

  defp malformed_operator_review(missing, attachments) do
    attachments
    |> Enum.with_index(1)
    |> Enum.reduce(missing, fn {attachment, index}, acc ->
      if attachment.operator_reviewed_valid? do
        acc
      else
        ["Security attachment #{index} operator_reviewed? must be a boolean." | acc]
      end
    end)
  end

  defp security_attachment(%SecurityAttachment{} = attachment), do: attachment

  defp security_attachment(input) when is_map(input) do
    operator_reviewed = get_field(input, :operator_reviewed?, false)
    plan_gate_ids = get_field(input, :plan_gate_ids, [])
    evidence_types = get_field(input, :evidence_types_by_gate, %{})
    blocked_claims_called_out = get_field(input, :blocked_claims_called_out, [])

    struct!(SecurityAttachment, %{
      artifact_id: get_field(input, :artifact_id),
      path: get_field(input, :path),
      source: get_field(input, :source),
      plan_gate_ids: atom_list(plan_gate_ids),
      evidence_types_by_gate: evidence_types_by_gate(evidence_types),
      blocked_claims_called_out: atom_list(blocked_claims_called_out),
      operator_reviewed?: operator_reviewed == true,
      plan_gate_ids_container_valid?: is_list(plan_gate_ids),
      evidence_types_by_gate_container_valid?: is_map(evidence_types),
      blocked_claims_called_out_container_valid?: is_list(blocked_claims_called_out),
      operator_reviewed_valid?: is_boolean(operator_reviewed)
    })
  end

  defp plan_gate_ids(validation_plan), do: Enum.map(validation_plan.gates, & &1.id)

  defp gate_blocked_claims(validation_plan),
    do: Map.new(validation_plan.gates, &{&1.id, &1.blocked_claims})

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

  defp get_field(input, field, default \\ nil) when is_atom(field) do
    Map.get(input, field, Map.get(input, Atom.to_string(field), default))
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

  defp evidence_types_by_gate(values) when is_map(values) do
    Map.new(values, fn {gate_id, evidence_type} ->
      {atom_value(gate_id), atom_value(evidence_type)}
    end)
  end

  defp evidence_types_by_gate(_values), do: %{}
end
