defmodule MeshxMobileApp.BLE.LocalInboxUxAcceptance do
  @moduledoc """
  Acceptance contract for the Nearby Messages product surface.

  This module evaluates the pure native read model and records what the
  surface must expose before it can be considered production-ready UX. It is
  not an on-device validation result. It does not scan, advertise, fetch,
  route, persist, ACK, retry, encrypt, or run background work.
  """

  alias MeshxMobileApp.BLE.{LocalInboxNativeSurface, LocalInboxUxValidationPlan}

  @required_states [:full_message, :unresolved_ref, :gossiped_ref, :stale_ref]
  @required_sorts [:recent_first, :state_then_recent, :strongest_rssi]

  @derive {JSON.Encoder,
           only: [
             :id,
             :status,
             :evidence,
             :missing,
             :blocked_claims,
             :notes
           ]}
  defstruct [:id, :status, :evidence, :missing, :blocked_claims, :notes]

  @type status :: :satisfied | :blocked

  @type t :: %__MODULE__{
          id: atom(),
          status: status(),
          evidence: [binary()],
          missing: [binary()],
          blocked_claims: [atom()],
          notes: [binary()]
        }

  @spec evaluate(map() | nil, keyword()) :: [t()]
  def evaluate(snapshot, opts \\ []) do
    surface = LocalInboxNativeSurface.build(snapshot, opts)

    [
      state_filter_gate(surface),
      sort_gate(surface),
      control_summary_gate(surface),
      row_gate(surface),
      detail_gate(snapshot, surface, opts),
      blocked_claim_copy_gate(snapshot, surface, opts),
      warning_gate(surface),
      on_device_gate()
    ]
  end

  @spec snapshot(map() | nil, keyword()) :: map()
  def snapshot(snapshot, opts \\ []) do
    gates = evaluate(snapshot, opts)

    %{
      acceptance_version: 1,
      surface: :nearby_messages,
      gates: gates,
      satisfied_count: Enum.count(gates, &(&1.status == :satisfied)),
      blocked_count: Enum.count(gates, &(&1.status == :blocked)),
      production_ux_claim_allowed?: Enum.all?(gates, &(&1.status == :satisfied)),
      blocked_claims: [:production_nearby_messages_ux, :delivery, :trusted_delivery, :routing],
      notes: [
        "The native surface must expose every local inbox state before production UX claims.",
        "On-device validation remains required before production UX claims.",
        "Acceptance gates do not add transport behavior or delivery semantics."
      ]
    }
  end

  @spec json_snapshot(map() | nil, keyword()) :: map()
  def json_snapshot(snapshot, opts \\ []) do
    snapshot(snapshot, opts)
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp state_filter_gate(surface) do
    states = Enum.map(surface.state_filters, & &1.state)
    missing = Enum.reject([:all | @required_states], &(&1 in states))

    gate(
      :state_filters,
      missing == [],
      [
        "Native surface exposes All plus full, unresolved, gossiped, and stale state filters."
      ],
      Enum.map(missing, &"Missing state filter #{inspect(&1)}."),
      [:production_nearby_messages_ux],
      ["State filters let operators distinguish full messages from refs."]
    )
  end

  defp sort_gate(surface) do
    sorts = Enum.map(surface.sort_options, & &1.sort)
    missing = Enum.reject(@required_sorts, &(&1 in sorts))

    gate(
      :sort_controls,
      missing == [],
      ["Native surface exposes recency, state, and signal sorting controls."],
      Enum.map(missing, &"Missing sort option #{inspect(&1)}."),
      [:production_nearby_messages_ux],
      ["Sorting is presentation-only and does not imply priority delivery."]
    )
  end

  defp control_summary_gate(surface) do
    missing =
      []
      |> maybe_missing(
        present?(Map.get(surface, :filter_summary)),
        "Missing active filter summary."
      )
      |> maybe_missing(
        present?(Map.get(surface, :sort_summary)),
        "Missing active sort summary."
      )
      |> Enum.reverse()

    gate(
      :control_summaries,
      missing == [],
      ["Native surface exposes active filter and sort summaries for evidence capture."],
      missing,
      [:production_nearby_messages_ux],
      ["Control summaries are presentation evidence and do not start transport work."]
    )
  end

  defp row_gate(surface) do
    missing =
      @required_states
      |> Enum.reject(fn state ->
        Enum.any?(surface.rows, fn row ->
          row.state == state and present?(row.title) and present?(row.subtitle) and
            present?(row.meta) and present?(row.badge)
        end)
      end)

    gate(
      :state_rows,
      missing == [],
      [
        "Rows for each state carry stable title, subtitle, metadata, and badge copy."
      ],
      Enum.map(missing, &"Missing complete row for #{inspect(&1)}."),
      [:production_nearby_messages_ux],
      ["Rows are read-model entries, not delivery receipts."]
    )
  end

  defp blocked_claim_copy_gate(snapshot, surface, opts) do
    missing_rows =
      @required_states
      |> Enum.reject(fn state ->
        Enum.any?(surface.rows, fn row ->
          row.state == state and claim_copy_present?(Map.get(row, :blocked_claims))
        end)
      end)
      |> Enum.map(&"Missing row blocked-claim copy for #{inspect(&1)}.")

    missing_details =
      @required_states
      |> Enum.reject(fn state ->
        surface.rows
        |> Enum.find(&(&1.state == state))
        |> selected_detail_blocked_claims_ok?(snapshot, opts)
      end)
      |> Enum.map(&"Missing detail blocked-claim copy for #{inspect(&1)}.")

    missing = missing_rows ++ missing_details

    gate(
      :blocked_claim_copy,
      missing == [],
      ["Rows and detail panels expose per-state blocked claims."],
      missing,
      [:delivery, :trusted_delivery, :routing],
      [
        "Blocked-claim copy prevents observation rows from becoming delivery, trust, or routing claims."
      ]
    )
  end

  defp detail_gate(snapshot, surface, opts) do
    missing =
      @required_states
      |> Enum.reject(fn state ->
        surface.rows
        |> Enum.find(&(&1.state == state))
        |> selected_detail_ok?(snapshot, opts)
      end)

    gate(
      :detail_panels,
      missing == [],
      ["Every state can produce a detail panel with limitation and next-action copy."],
      Enum.map(missing, &"Missing detail panel coverage for #{inspect(&1)}."),
      [:production_nearby_messages_ux, :delivery],
      [
        "Detail panels must keep delivery_claim_allowed? false for current local BLE observations."
      ]
    )
  end

  defp warning_gate(surface) do
    text = Enum.join(surface.warnings, "\n")

    missing =
      [
        {"legacy beacon pointer warning", String.contains?(text, "pointers")},
        {"gossip non-delivery warning", String.contains?(text, "not guaranteed delivery")},
        {"stale observation warning", String.contains?(text, "Stale refs")}
      ]
      |> Enum.reject(fn {_label, present?} -> present? end)
      |> Enum.map(fn {label, _present?} -> "Missing #{label}." end)

    gate(
      :blocked_claim_warnings,
      missing == [],
      ["Native surface carries warnings that block pointer, gossip, and stale-ref overclaims."],
      missing,
      [:delivery, :trusted_delivery, :routing],
      ["Warning copy is part of the product contract for advert-only local mesh."]
    )
  end

  defp on_device_gate do
    %__MODULE__{
      id: :on_device_validation,
      status: :blocked,
      evidence: [
        "LocalInboxUxValidationPlan defines target device matrix, state coverage, interaction coverage, blocked-claim copy review, and visual density review evidence."
      ],
      missing: [
        "Run the Mob Nearby Messages surface on target hardware with full, unresolved, gossiped, and stale fixture states.",
        "Capture screenshots or operator notes proving text density, selection, filters, sorting, and detail panels are usable on device.",
        "Attach evidence satisfying #{LocalInboxUxValidationPlan.snapshot().open_gate_count} LocalInboxUxValidationPlan gates."
      ],
      blocked_claims: [:production_nearby_messages_ux],
      notes: [
        "Pure surface acceptance is necessary but not sufficient for production UX.",
        "This blocked gate prevents tests from being mistaken for on-device validation."
      ]
    }
  end

  defp selected_detail_ok?(nil, _snapshot, _opts), do: false

  defp selected_detail_ok?(row, snapshot, opts) do
    selected =
      LocalInboxNativeSurface.build(
        snapshot,
        opts
        |> Keyword.delete(:selected_state)
        |> Keyword.put(:selected_state, :all)
        |> Keyword.put(:detail_message_key, row.message_key)
      )

    match?(
      %{
        status: :selected,
        state: _,
        limitation: limitation,
        next_action: next_action,
        delivery_claim_allowed?: false
      }
      when is_binary(limitation) and byte_size(limitation) > 0 and is_binary(next_action) and
             byte_size(next_action) > 0,
      selected.detail
    )
  end

  defp selected_detail_blocked_claims_ok?(nil, _snapshot, _opts), do: false

  defp selected_detail_blocked_claims_ok?(row, snapshot, opts) do
    selected =
      LocalInboxNativeSurface.build(
        snapshot,
        opts
        |> Keyword.delete(:selected_state)
        |> Keyword.put(:selected_state, :all)
        |> Keyword.put(:detail_message_key, row.message_key)
      )

    match?(
      %{
        status: :selected,
        blocked_claims: blocked_claims,
        detail_lines: detail_lines
      }
      when is_list(blocked_claims) and length(blocked_claims) > 0 and is_list(detail_lines),
      selected.detail
    ) and
      Enum.any?(selected.detail.detail_lines, &String.starts_with?(&1, "Blocked claims:"))
  end

  defp claim_copy_present?(claims),
    do: is_list(claims) and Enum.all?(claims, &present?/1) and claims != []

  defp maybe_missing(missing, true, _message), do: missing
  defp maybe_missing(missing, false, message), do: [message | missing]

  defp gate(id, true, evidence, missing, blocked_claims, notes) do
    %__MODULE__{
      id: id,
      status: :satisfied,
      evidence: evidence,
      missing: missing,
      blocked_claims: blocked_claims,
      notes: notes
    }
  end

  defp gate(id, false, evidence, missing, blocked_claims, notes) do
    %__MODULE__{
      id: id,
      status: :blocked,
      evidence: evidence,
      missing: missing,
      blocked_claims: blocked_claims,
      notes: notes
    }
  end

  defp present?(value), do: is_binary(value) and byte_size(value) > 0
end
