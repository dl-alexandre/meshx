defmodule Mob.Node.BLE.PeerCapabilities do
  @moduledoc """
  Passive parsing of MeshX peer-capability advertisements.

  Distinct from `Mob.Node.BLE.Capabilities` (which describes
  *bridge* capabilities exchanged at the Kotlin/Swift ↔ Elixir
  handshake). This module describes what a *remote BLE peer*
  advertises about itself — the layer above transport, below
  routing.

  ## Wire format

  A MeshX capability advertisement is a single BLE AD record with
  type `0xFF` (Manufacturer Specific Data), payload prefix `"MX"`
  (a MeshX-namespaced marker acting as a fake CIC), then a version
  byte, then version-defined payload:

      <<len, 0xFF, "MX", protocol_version, capability_flags_v1, …trailing>>

  ### v1 payload

    * one byte `capability_flags_v1` (bitmap):
      - bit 0: `supports_replay_contract`
      - bit 1: `supports_passive_presence`
      - bit 2: `supports_churn`
      - bit 3: `supports_message_exchange` (reserved, always 0 in v1)
      - bit 4: `supports_crypto_identity` (reserved, always 0 in v1)
      - bits 5-7: reserved, must be 0 in v1

  ### Forward compatibility

  Bytes beyond the v1-known portion are preserved in
  `unknown_payload` so a future parser can introspect them. v1
  itself ignores them. Unknown protocol_versions (≥2) still decode
  the v1-compatible portion if a flags byte is present; everything
  after is preserved.

  ## Default and missing capabilities

  `parse/1` always returns a `%PeerCapabilities{}` struct, never
  `nil`. The default (no MeshX capability AD record present, or no
  advertisement parsed yet) has `protocol_version: nil` and every
  `supports_*` field set to `false`. Consumers can pattern-match on
  `protocol_version != nil` to ask "did this peer ever advertise
  MeshX capabilities."

  ## Robustness

  Malformed advertisements never crash the parser:

    * Truncated AD records → skipped, defaults returned.
    * Wrong manufacturer marker → not a MeshX record, defaults returned.
    * AD record present but no version byte → defaults returned.
    * AD record present with version but no flags byte → version
      known, flags default to false.

  Same input always produces the same output (pure function of bytes).
  """

  import Bitwise

  @manufacturer_specific_data 0xFF
  @mob_marker "MX"
  @current_protocol_version 1

  @bit_replay_contract 0
  @bit_passive_presence 1
  @bit_churn 2
  @bit_message_exchange 3
  @bit_crypto_identity 4

  @type t :: %__MODULE__{
          protocol_version: nil | non_neg_integer(),
          supports_replay_contract: boolean(),
          supports_passive_presence: boolean(),
          supports_churn: boolean(),
          supports_message_exchange: boolean(),
          supports_crypto_identity: boolean(),
          unknown_payload: binary()
        }

  defstruct protocol_version: nil,
            supports_replay_contract: false,
            supports_passive_presence: false,
            supports_churn: false,
            supports_message_exchange: false,
            supports_crypto_identity: false,
            unknown_payload: <<>>

  @doc """
  Returns the current MeshX capability protocol version this module
  emits and fully understands.
  """
  @spec current_protocol_version() :: pos_integer()
  def current_protocol_version, do: @current_protocol_version

  @doc """
  Parses a BLE advertisement payload, returning the peer's MeshX
  capability claim. Always returns a struct — never crashes, never
  raises, never returns nil.
  """
  @spec parse(binary()) :: t()
  def parse(advertisement) when is_binary(advertisement) do
    case find_mob_record(advertisement) do
      nil -> %__MODULE__{}
      payload -> decode_payload(payload)
    end
  end

  def parse(_), do: %__MODULE__{}

  # Returns true when the peer has ever advertised a MeshX capability
  # record (regardless of which version). Useful for routing filters
  # and UI badges.
  @spec mesh_x_capable?(t()) :: boolean()
  def mesh_x_capable?(%__MODULE__{protocol_version: nil}), do: false
  def mesh_x_capable?(%__MODULE__{}), do: true

  @doc """
  Returns true if the peer's advertised capability bits cover every bit
  set in `requirements` (a single-byte bitmap matching the v1 layout).

  A peer that hasn't advertised any MeshX capabilities (defaults, all
  `supports_*` false) satisfies only the empty requirement set
  (`requirements == 0`). Requirements with reserved bits beyond
  `0x1F` (bits 5-7) cannot currently be satisfied — that surfaces a
  forward-compat mismatch rather than silently passing.
  """
  @spec satisfies?(t(), non_neg_integer()) :: boolean()
  def satisfies?(%__MODULE__{} = caps, requirements) when is_integer(requirements) do
    # Map each known v1 bit to the corresponding struct field.
    pairs = [
      {@bit_replay_contract, caps.supports_replay_contract},
      {@bit_passive_presence, caps.supports_passive_presence},
      {@bit_churn, caps.supports_churn},
      {@bit_message_exchange, caps.supports_message_exchange},
      {@bit_crypto_identity, caps.supports_crypto_identity}
    ]

    known_bit_mask = Enum.reduce(pairs, 0, fn {bit, _}, acc -> acc ||| 1 <<< bit end)
    unknown_required = requirements &&& bnot(known_bit_mask)

    # Any unknown reserved bit in the requirement is unsatisfiable.
    if unknown_required != 0 do
      false
    else
      Enum.all?(pairs, fn {bit, has?} ->
        if (requirements >>> bit &&& 1) == 1, do: has?, else: true
      end)
    end
  end

  # ── AD walking ─────────────────────────────────────────────────────────────
  #
  # Locate the first 0xFF Manufacturer Specific Data record whose
  # payload starts with the "MX" marker. Return everything *after*
  # the marker (version + flags + trailing). Truncated records are
  # skipped silently.

  defp find_mob_record(<<>>), do: nil
  defp find_mob_record(<<0, _::binary>>), do: nil

  defp find_mob_record(<<len, rest::binary>>) when byte_size(rest) < len do
    nil
  end

  defp find_mob_record(
         <<len, @manufacturer_specific_data, data::binary-size(len - 1), tail::binary>>
       ) do
    case data do
      <<@mob_marker, payload::binary>> -> payload
      _ -> find_mob_record(tail)
    end
  end

  defp find_mob_record(<<len, _type, _data::binary-size(len - 1), tail::binary>>) do
    find_mob_record(tail)
  end

  # ── version-aware decode ───────────────────────────────────────────────────

  defp decode_payload(<<>>), do: %__MODULE__{}

  defp decode_payload(<<version, rest::binary>>) do
    decode_for_version(version, rest)
  end

  # v1: one flags byte, then trailing bytes preserved.
  defp decode_for_version(@current_protocol_version, <<flags, trailing::binary>>) do
    %__MODULE__{
      protocol_version: @current_protocol_version,
      supports_replay_contract: bit_set?(flags, @bit_replay_contract),
      supports_passive_presence: bit_set?(flags, @bit_passive_presence),
      supports_churn: bit_set?(flags, @bit_churn),
      supports_message_exchange: bit_set?(flags, @bit_message_exchange),
      supports_crypto_identity: bit_set?(flags, @bit_crypto_identity),
      unknown_payload: trailing
    }
  end

  # v1 declared but no flags byte: peer started a record but truncated.
  defp decode_for_version(@current_protocol_version, <<>>) do
    %__MODULE__{protocol_version: @current_protocol_version}
  end

  # Unknown future version: decode the v1-compatible flags byte if
  # present, preserve everything else for a future parser. Forward-
  # compatibility rule: future versions MUST keep the first payload
  # byte as a superset bitmap of the v1 flags, with new bits assigned
  # to bits 5-7 first and then to additional bytes in `unknown_payload`.
  defp decode_for_version(version, <<flags, trailing::binary>>)
       when version > @current_protocol_version do
    %__MODULE__{
      protocol_version: version,
      supports_replay_contract: bit_set?(flags, @bit_replay_contract),
      supports_passive_presence: bit_set?(flags, @bit_passive_presence),
      supports_churn: bit_set?(flags, @bit_churn),
      supports_message_exchange: bit_set?(flags, @bit_message_exchange),
      supports_crypto_identity: bit_set?(flags, @bit_crypto_identity),
      unknown_payload: trailing
    }
  end

  defp decode_for_version(version, <<>>) when version > @current_protocol_version do
    %__MODULE__{protocol_version: version}
  end

  # Versions below v1 are reserved/unknown — only the version itself
  # decodes; everything else stays at defaults. Different from
  # `unknown_payload` above because we can't trust the bit layout.
  defp decode_for_version(version, _rest) do
    %__MODULE__{protocol_version: version}
  end

  defp bit_set?(byte, bit), do: (byte >>> bit &&& 1) == 1
end
