defmodule Mob.Node.BLE.LocalBackgroundLifecycleContract do
  @moduledoc """
  Contract for mobile BLE background lifecycle work.

  The current validated local BLE mode is foreground/manual. This module
  records what must be proven before MeshX can claim Android foreground
  service support, iOS background behavior, automatic restart, scheduled
  retry, or background gossip. It does not start services, request OS
  background modes, schedule work, scan, advertise, route, persist, ACK,
  retry, encrypt, or fetch.
  """

  defmodule Requirement do
    @moduledoc false

    @enforce_keys [:id, :status, :required_evidence, :current_gap, :notes]
    defstruct @enforce_keys

    @type id ::
            :android_foreground_service
            | :android_background_ble_policy
            | :ios_background_ble_policy
            | :automatic_restart
            | :background_gossip_limits

    @type status :: :not_implemented | :foreground_only

    @type t :: %__MODULE__{
            id: id(),
            status: status(),
            required_evidence: [binary()],
            current_gap: binary(),
            notes: [binary()]
          }
  end

  @requirements [
    %{
      id: :android_foreground_service,
      status: :not_implemented,
      required_evidence: [
        "Android manifest and source must declare and start a bounded foreground service only if product requirements need it.",
        "Hardware validation must prove foreground-service scan/advertise behavior across app backgrounding."
      ],
      current_gap:
        "Android source has foreground/manual harness behavior, not a foreground service.",
      notes: ["No Android foreground-service permission or service lifecycle is claimed."]
    },
    %{
      id: :android_background_ble_policy,
      status: :foreground_only,
      required_evidence: [
        "Policy must define what BLE scan/advertise actions may continue when the app backgrounds.",
        "Battery, permission, notification, and OS throttling behavior must be documented and validated."
      ],
      current_gap: "Android background BLE behavior is not implemented or hardware validated.",
      notes: ["Current validation uses explicit start/stop while foregrounded."]
    },
    %{
      id: :ios_background_ble_policy,
      status: :not_implemented,
      required_evidence: [
        "iOS capabilities and bridge behavior must define any background BLE scan/advertise mode.",
        "Hardware validation must prove actual iOS background behavior and replay-normalized events."
      ],
      current_gap: "iOS background BLE participation is not implemented or validated.",
      notes: ["The iOS bridge shell does not imply background support."]
    },
    %{
      id: :automatic_restart,
      status: :not_implemented,
      required_evidence: [
        "A lifecycle policy must define restart triggers, cancellation, and operator-visible status.",
        "Restart behavior must not imply retries, delivery guarantees, or background gossip unless separately proven."
      ],
      current_gap: "No automatic restart, scheduler, or retry loop exists.",
      notes: ["Manual start/stop remains the only supported mobile BLE lifecycle."]
    },
    %{
      id: :background_gossip_limits,
      status: :not_implemented,
      required_evidence: [
        "Background gossip must define rate limits, TTL handling, battery bounds, and OS-specific constraints.",
        "Hardware validation must prove behavior without claiming delivery, routing, ACKs, or retries."
      ],
      current_gap:
        "Advert gossip execution is foreground/manual and one-hop hardware validated only.",
      notes: ["Background gossip is not part of the current validated local mode."]
    }
  ]

  @spec requirements() :: [Requirement.t()]
  def requirements, do: Enum.map(@requirements, &struct!(Requirement, &1))

  @spec get(Requirement.id()) :: {:ok, Requirement.t()} | {:error, :not_found}
  def get(id) do
    case Enum.find(requirements(), &(&1.id == id)) do
      %Requirement{} = requirement -> {:ok, requirement}
      nil -> {:error, :not_found}
    end
  end

  @spec open_requirements() :: [Requirement.t()]
  def open_requirements, do: requirements()

  @spec snapshot() :: map()
  def snapshot do
    %{
      requirements: requirements(),
      open_requirements: open_requirements(),
      open_requirement_count: length(open_requirements()),
      notes: [
        "Current mobile BLE mode is foreground/manual.",
        "No Android foreground service or iOS background BLE behavior is implemented.",
        "No automatic restart, scheduled retry, or background gossip is claimed."
      ]
    }
  end
end
