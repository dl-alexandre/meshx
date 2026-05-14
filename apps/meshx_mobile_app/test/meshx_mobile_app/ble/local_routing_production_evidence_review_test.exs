defmodule MeshxMobileApp.BLE.LocalRoutingProductionEvidenceReviewTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalRoutingProductionEvidenceReview

  test "empty evidence remains open and lists all routing gates" do
    review = LocalRoutingProductionEvidenceReview.review(%{})

    assert review.review_version == 1
    assert review.boundary == :production_routing_evidence_review
    assert review.status == :open
    refute review.production_routing_evidence_complete?
    refute review.route_table_claim_allowed?
    refute review.route_selection_claim_allowed?
    refute review.forwarding_claim_allowed?
    refute review.routed_delivery_claim_allowed?
    refute review.guaranteed_delivery_claim_allowed?
    refute review.multi_hop_hardware_claim_allowed?

    for gate <- LocalRoutingProductionEvidenceReview.required_gates() do
      assert Enum.any?(review.missing, &String.contains?(&1, "#{gate} missing artifact_path"))
    end
  end

  test "complete string-keyed metadata is ready without enabling routing" do
    review = LocalRoutingProductionEvidenceReview.review(complete_json_input())

    assert review.status == :ready
    assert review.production_routing_evidence_complete?
    refute review.route_selection_claim_allowed?
    refute review.forwarding_claim_allowed?
    refute review.routed_delivery_claim_allowed?
    assert review.missing == []

    assert Map.keys(review.evidence_by_gate) |> Enum.sort() ==
             LocalRoutingProductionEvidenceReview.required_gates() |> Enum.sort()
  end

  test "omitted routing evidence gate sections are explicit" do
    review = LocalRoutingProductionEvidenceReview.review(%{})

    assert review.status == :open

    for gate <- LocalRoutingProductionEvidenceReview.required_gates() do
      assert Enum.any?(
               review.missing,
               &String.contains?(&1, "Missing #{gate} evidence section.")
             )
    end
  end

  test "malformed routing evidence gate sections fail closed instead of collapsing" do
    input =
      complete_json_input()
      |> Map.put("forwarding_service_boundary", "not-an-object")

    review = LocalRoutingProductionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "forwarding_service_boundary evidence section must be an object"
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "forwarding_service_boundary missing artifact_path")
           )
  end

  test "JSON review is machine readable and keeps routing claims blocked" do
    review = LocalRoutingProductionEvidenceReview.json_review(complete_json_input())

    assert review["status"] == "ready"
    assert review["production_routing_evidence_complete?"] == true
    assert review["route_selection_claim_allowed?"] == false
    assert review["forwarding_claim_allowed?"] == false
    assert review["routed_delivery_claim_allowed?"] == false
    assert review["hardware_validation_plan"]["current_mode"] == "advert_only_non_routing"
  end

  test "template input lists every gate but remains incomplete" do
    template = LocalRoutingProductionEvidenceReview.template_input()

    assert Map.keys(template) |> Enum.sort() ==
             LocalRoutingProductionEvidenceReview.required_gates()
             |> Enum.map(&Atom.to_string/1)
             |> Enum.sort()

    for gate <- LocalRoutingProductionEvidenceReview.required_gates() do
      item = Map.fetch!(template, Atom.to_string(gate))

      assert item["artifact_path"] == ""
      assert item["summary"] == ""
      assert item["test_command"] == ""

      assert item["evidence_type"] ==
               LocalRoutingProductionEvidenceReview.required_evidence_types()
               |> Map.fetch!(gate)
               |> Atom.to_string()

      assert item["blocked_claims_called_out"] == []
    end

    review = LocalRoutingProductionEvidenceReview.review(template)

    assert review.status == :open
    refute review.production_routing_evidence_complete?
    refute review.route_table_claim_allowed?
    refute review.forwarding_claim_allowed?
    refute review.routed_delivery_claim_allowed?
    refute review.guaranteed_delivery_claim_allowed?
    refute review.multi_hop_hardware_claim_allowed?
  end

  test "malformed metadata identifies missing fields and blocked claim callouts" do
    input =
      complete_json_input()
      |> put_in(["route_table_state_model", "artifact_path"], "")
      |> put_in(["forwarding_service_boundary", "blocked_claims_called_out"], [
        "route_table_available"
      ])
      |> put_in(["delivery_semantics_policy", "evidence_type"], nil)

    review = LocalRoutingProductionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "route_table_state_model missing artifact_path")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "forwarding_service_boundary missing blocked claim callouts")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "delivery_semantics_policy missing evidence_type")
           )
  end

  test "blocked claim callouts must be listed explicitly" do
    input =
      complete_json_input()
      |> put_in(["forwarding_service_boundary", "blocked_claims_called_out"], "routed_delivery")

    review = LocalRoutingProductionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "forwarding_service_boundary blocked_claims_called_out must be a list"
             )
           )
  end

  test "ready metadata must use the required evidence type for each routing gate" do
    input =
      complete_json_input()
      |> put_in(["forwarding_service_boundary", "evidence_type"], "route_selection_policy")

    review = LocalRoutingProductionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "forwarding_service_boundary evidence_type must be :forwarding_service_boundary"
             )
           )
  end

  test "routing evidence artifact paths must be release-relative" do
    input =
      complete_json_input()
      |> put_in(["route_table_state_model", "artifact_path"], "/tmp/routing/table.md")
      |> put_in(["deterministic_route_selection", "artifact_path"], "../outside/selection.md")
      |> put_in(["forwarding_service_boundary", "artifact_path"], "file:///tmp/forwarding.md")
      |> put_in(
        ["delivery_semantics_policy", "artifact_path"],
        "https://example.invalid/routing.md"
      )
      |> put_in(["multi_hop_hardware_rig", "artifact_path"], "~/routing/rig.md")

    review = LocalRoutingProductionEvidenceReview.review(input)

    assert review.status == :open

    for gate <- [
          :route_table_state_model,
          :deterministic_route_selection,
          :forwarding_service_boundary,
          :delivery_semantics_policy,
          :multi_hop_hardware_rig
        ] do
      assert Enum.any?(
               review.missing,
               &String.contains?(&1, "#{gate} artifact_path must be a relative artifact path.")
             )
    end
  end

  test "routing evidence text fields must be strings and not need trimming" do
    input =
      complete_json_input()
      |> put_in(["route_table_state_model", "artifact_path"], 123)
      |> put_in(["deterministic_route_selection", "summary"], 456)
      |> put_in(["forwarding_service_boundary", "test_command"], 789)
      |> put_in(
        ["delivery_semantics_policy", "artifact_path"],
        " artifacts/local-ble/run/routing/delivery.md"
      )
      |> put_in(["multi_hop_hardware_rig", "summary"], " multi-hop evidence attached ")
      |> put_in(["release_artifact_evidence", "test_command"], " mix test routing ")

    review = LocalRoutingProductionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "route_table_state_model artifact_path must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "deterministic_route_selection summary must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "forwarding_service_boundary test_command must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "delivery_semantics_policy artifact_path must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "multi_hop_hardware_rig summary must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "release_artifact_evidence test_command must not have leading or trailing whitespace."
             )
           )
  end

  test "ready metadata must call out gate-specific routing blockers" do
    input =
      complete_json_input()
      |> put_in(
        ["forwarding_service_boundary", "blocked_claims_called_out"],
        Enum.map(
          LocalRoutingProductionEvidenceReview.required_blocked_claims(),
          &Atom.to_string/1
        )
      )

    review = LocalRoutingProductionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "forwarding_service_boundary missing gate-specific blocked claim callouts"
             )
           )
  end

  defp complete_json_input do
    gate_claims = LocalRoutingProductionEvidenceReview.required_gate_blocked_claims()

    Map.new(LocalRoutingProductionEvidenceReview.required_gates(), fn gate ->
      {Atom.to_string(gate),
       %{
         "artifact_path" => "artifacts/local-ble/run/routing/#{gate}.md",
         "summary" => "#{gate} evidence attached",
         "test_command" =>
           "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_routing_#{gate}_test.exs",
         "evidence_type" =>
           LocalRoutingProductionEvidenceReview.required_evidence_types()
           |> Map.fetch!(gate)
           |> Atom.to_string(),
         "blocked_claims_called_out" =>
           (LocalRoutingProductionEvidenceReview.required_blocked_claims() ++
              Map.get(gate_claims, gate, []))
           |> Enum.uniq()
           |> Enum.map(&Atom.to_string/1)
       }}
    end)
  end
end
