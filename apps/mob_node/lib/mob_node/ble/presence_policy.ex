defmodule Mob.Node.BLE.PresencePolicy do
  @moduledoc """
  Pure policy for deriving a peer's presence lifecycle from observed
  BLE event timestamps.

  A peer's presence is a function of three things:

    * its `last_seen_at` (boot-relative milliseconds from a
      `Mob.Node.BLE.Events.DeviceDiscovered` /
      `AdvertisementReceived` event)
    * a caller-supplied `now` in the same scale
    * the policy's two windows

  Two thresholds, both expressed in milliseconds:

    * `active_window_ms` — a sighting within this window of `now` is
      `:active`.
    * `stale_window_ms` — beyond `active_window_ms` but within
      `active_window_ms + stale_window_ms`, the peer is `:stale`.
      Beyond that, `:expired`.

  This module owns no state and no time source — `now` is always an
  argument. That keeps presence derivation deterministic under replay:
  the same `(last_seen_at, now, policy)` triple always yields the same
  state, regardless of wall clock.

  ## Reappearance

  An expired peer that emits a new advertisement advances its
  `last_seen_at`, so the next `derive/3` call returns `:active` again.
  Nothing in this module needs to track "was expired"; the lifecycle
  is a pure function of the inputs, not a state machine.
  """

  @type state :: :active | :stale | :expired

  @type t :: %__MODULE__{
          active_window_ms: pos_integer(),
          stale_window_ms: pos_integer()
        }

  @default_active_window_ms 10_000
  @default_stale_window_ms 30_000

  defstruct active_window_ms: @default_active_window_ms,
            stale_window_ms: @default_stale_window_ms

  @doc """
  Returns the default policy: 10s active window, 30s stale window
  (so a peer expires 40s after its last sighting).
  """
  @spec default() :: t()
  def default, do: %__MODULE__{}

  @doc """
  Derives the presence state for a single `last_seen_at` timestamp.

  `now` may equal or exceed `last_seen_at`. If `now < last_seen_at`
  (clock skew, out-of-order replay), the peer is treated as `:active`
  — the safe default that doesn't penalize a peer for arithmetic
  inversions.
  """
  @spec derive(integer(), integer(), t()) :: state()
  def derive(last_seen_at, now, %__MODULE__{} = p)
      when is_integer(last_seen_at) and is_integer(now) do
    delta = now - last_seen_at

    cond do
      delta <= p.active_window_ms -> :active
      delta <= p.active_window_ms + p.stale_window_ms -> :stale
      true -> :expired
    end
  end
end
