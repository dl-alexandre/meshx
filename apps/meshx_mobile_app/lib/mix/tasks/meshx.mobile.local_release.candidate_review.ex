defmodule Mix.Tasks.Meshx.Mobile.LocalRelease.CandidateReview do
  @moduledoc """
  Reviews advert-only local release-candidate evidence.

      mix meshx.mobile.local_release.candidate_review
      mix meshx.mobile.local_release.candidate_review --template --out artifacts/local-ble/run/release-candidate/evidence.json
      mix meshx.mobile.local_release.candidate_review --input artifacts/local-ble/run/evidence.json
      mix meshx.mobile.local_release.candidate_review --input artifacts/local-ble/run/evidence.json --json --out tmp/local-release-candidate-review.json

  Without `--input`, the review runs against an empty evidence package and
  reports the required missing hardware attachments, manifests, and operator
  wording. The task never reads hardware logs or approves release claims by
  itself; it only validates supplied metadata shape and wording gates.
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.LocalReleaseCandidateEvidenceReview

  @shortdoc "Review advert-only local release-candidate evidence"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)

    if opts.template? do
      print_template(opts)
    else
      input = read_input(opts.input_path)
      review = LocalReleaseCandidateEvidenceReview.review(input)
      json = LocalReleaseCandidateEvidenceReview.json_review(input) |> JSON.encode!()

      maybe_write_json(json, opts.out_path)
      print_review(review, json, opts.json?)
    end
  end

  defp parse_args(args),
    do: parse_args(args, %{json?: false, template?: false, out_path: nil, input_path: nil})

  defp parse_args([], opts), do: opts
  defp parse_args(["--json" | rest], opts), do: parse_args(rest, %{opts | json?: true})
  defp parse_args(["--template" | rest], opts), do: parse_args(rest, %{opts | template?: true})

  defp parse_args(["--input", path | rest], opts) when is_binary(path) and path != "",
    do: parse_args(rest, %{opts | input_path: path})

  defp parse_args(["--out", path | rest], opts) when is_binary(path) and path != "",
    do: parse_args(rest, %{opts | out_path: path})

  defp parse_args(["--input"], _opts), do: Mix.raise("missing path for --input")
  defp parse_args(["--out"], _opts), do: Mix.raise("missing path for --out")
  defp parse_args([unknown | _rest], _opts), do: Mix.raise("unknown option(s): #{unknown}")

  defp read_input(nil), do: %{}

  defp read_input(path) do
    path
    |> File.read!()
    |> JSON.decode!()
  end

  defp maybe_write_json(_json, nil), do: :ok

  defp maybe_write_json(json, path) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(path, json <> "\n")
  end

  defp print_template(%{input_path: path}) when is_binary(path),
    do: Mix.raise("--template cannot be combined with --input")

  defp print_template(opts) do
    json =
      LocalReleaseCandidateEvidenceReview.template_input()
      |> JSON.encode!()

    maybe_write_json(json, opts.out_path)
    Mix.shell().info(json)
  end

  defp print_review(_review, json, true), do: Mix.shell().info(json)

  defp print_review(review, _json, false) do
    Mix.shell().info(
      "LOCAL_RELEASE_CANDIDATE_REVIEW status=#{review.status} complete=#{review.release_candidate_evidence_complete?}"
    )

    Mix.shell().info(
      "RELEASE_CANDIDATE_REVIEW missing #{length(review.missing)} open_hardware_gates #{length(review.open_hardware_gate_ids)}"
    )

    Mix.shell().info(
      "OPERATOR_NOTE_PATHS readiness=#{present?(review.operator_notes.readiness_manifest_path)} completion_audit=#{present?(review.operator_notes.completion_audit_path)} completion_audit_plain_text=#{present?(review.operator_notes.completion_audit_plain_text_path)} focused_remaining_items_audit=#{present?(review.operator_notes.focused_remaining_items_audit_path)} focused_remaining_items_plain_text=#{present?(review.operator_notes.focused_remaining_items_plain_text_path)} direct_full_mx_aux_checklist=#{present?(review.operator_notes.direct_full_mx_aux_validation_checklist_path)} upstream_patch_handoff=#{present?(review.operator_notes.upstream_patch_maintainer_handoff_path)} blocker_matrix=#{present?(review.operator_notes.completion_blocker_matrix_path)} release_manifest=#{present?(review.operator_notes.release_manifest_path)} recent_evidence=#{present?(review.operator_notes.recent_evidence_inventory_path)} persistence_lifecycle=#{present?(review.operator_notes.persistence_lifecycle_plan_path)} lifecycle_review=#{present?(review.operator_notes.lifecycle_review_path)} ios_parity_review=#{present?(review.operator_notes.ios_parity_review_path)} full_resolution_review=#{present?(review.operator_notes.full_resolution_review_path)} known_good_transport_review=#{present?(review.operator_notes.known_good_transport_review_path)} multi_hop_review=#{present?(review.operator_notes.multi_hop_review_path)} routing_review=#{present?(review.operator_notes.routing_review_path)} security_review=#{present?(review.operator_notes.security_review_path)} ux_review=#{present?(review.operator_notes.ux_review_path)}"
    )

    Mix.shell().info(
      "PERSISTENCE_LIFECYCLE default=#{review.persistence_lifecycle.current_default_mode} opt_in=#{review.persistence_lifecycle.opt_in_durable_snapshots_available?} blocked_gates=#{review.persistence_lifecycle.blocked_gate_count}/#{review.persistence_lifecycle.gate_count}"
    )

    Mix.shell().info(
      "LIFECYCLE_REVIEW status=#{review.lifecycle_review.status} complete=#{review.lifecycle_review.lifecycle_hardware_evidence_complete?} background=#{review.lifecycle_review.background_ble_claim_allowed?}"
    )

    Mix.shell().info(
      "IOS_PARITY_REVIEW status=#{review.ios_parity_review.status} complete=#{review.ios_parity_review.ios_hardware_evidence_complete?} parity=#{review.ios_parity_review.ios_parity_claim_allowed?}"
    )

    Mix.shell().info(
      "FULL_RESOLUTION_REVIEW status=#{review.full_resolution_review.status} complete=#{review.full_resolution_review.full_resolution_transport_evidence_complete?} resolved=#{review.full_resolution_review.full_message_resolution_claim_allowed?}"
    )

    Mix.shell().info(
      "KNOWN_GOOD_TRANSPORT_REVIEW status=#{review.known_good_transport_review.status} complete=#{review.known_good_transport_review.known_good_transport_evidence_complete?} transport=#{review.known_good_transport_review.known_good_transport_claim_allowed?}"
    )

    Mix.shell().info(
      "MULTI_HOP_REVIEW status=#{review.multi_hop_review.status} complete=#{review.multi_hop_review.multi_hop_hardware_evidence_complete?} physical=#{review.multi_hop_review.multi_hop_physical_proof_present?}"
    )

    Mix.shell().info(
      "SECURITY_REVIEW status=#{review.security_review.status} complete=#{review.security_review.security_release_evidence_complete?} trusted=#{review.security_review.trusted_message_claim_allowed?}"
    )

    Mix.shell().info(
      "ROUTING_REVIEW status=#{review.routing_review.status} complete=#{review.routing_review.production_routing_evidence_complete?} routed=#{review.routing_review.routed_delivery_claim_allowed?}"
    )

    Mix.shell().info(
      "UX_REVIEW status=#{review.ux_review.status} targets=#{review.ux_review.target_device_count} all_selected_details=#{review.ux_review.all_target_devices_have_selected_detail_coverage?}"
    )

    maybe_print_template_hint(review)
  end

  defp maybe_print_template_hint(%{release_candidate_evidence_complete?: true}), do: :ok

  defp maybe_print_template_hint(_review) do
    Mix.shell().info(
      "RELEASE_CANDIDATE_TEMPLATE command=mix meshx.mobile.local_release.candidate_review --template --out artifacts/local-ble/<run-id>/release-candidate/evidence.json"
    )
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)
end
