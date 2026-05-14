defmodule MeshxMobileApp.BLE.Identity do
  @moduledoc """
  Passive peer-identity derivation from BLE advertisement payloads.

  `device_id` is transport-local — iOS rotates its peripheral UUID,
  Android randomizes its MAC, neither is stable across hours. The mesh
  layer needs a *stable* identifier that survives `device_id` rotation;
  this module derives that identifier passively, from the advertisement
  bytes alone, with no handshake and no crypto.

  ## Current rule

  Parse the standard BLE Advertising Data structure (Bluetooth Core
  spec, Vol 3 Part C §11). If a Complete Local Name (type `0x09`) or
  Shortened Local Name (type `0x08`) record exists, and its value
  begins with the ASCII prefix `"meshx-"`, return the full local name
  as the peer_id.

  Everything else — empty advertisements, malformed records, names
  without the MeshX prefix, manufacturer data with no local name —
  returns `nil` (anonymous). Anonymous peers are still tracked by
  `PeerTable` via their `device_id`; they just don't merge across
  rotations.

  ## Determinism

  This module is a pure function of the advertisement bytes. Same
  bytes → same result, every time. No timestamps, no external state,
  no randomness. Replays are therefore identity-stable.

  ## Future extensions (deliberately not implemented yet)

  - Manufacturer-data-based identity (custom CIC + payload)
  - Service UUID matching
  - Cryptographic key fingerprints in advertisement

  Each extension can be added behind a new clause without changing
  the contract — anonymous remains the safe fallback.
  """

  @local_name_complete 0x09
  @local_name_shortened 0x08
  @meshx_prefix "meshx-"

  defmodule Claim do
    @moduledoc """
    The evidence supporting a peer identity, returned by
    `MeshxMobileApp.BLE.Identity.classify/1`.

    `source` describes *how* the `peer_id` was obtained — letting the
    runtime weigh different evidence levels without re-parsing the
    advertisement. Today only `:advertised_name` is implemented;
    `:fingerprint` and `:signed_identity` are reserved for stronger
    cryptographic evidence and will be added behind their own clauses
    when those codepaths land.
    """

    @type source :: :none | :advertised_name | :fingerprint | :signed_identity

    @type t :: %__MODULE__{
            peer_id: binary() | nil,
            source: source()
          }

    defstruct peer_id: nil, source: :none
  end

  @doc """
  Classifies an advertisement payload, returning both the derived
  `peer_id` and the evidence `source` that supports it.

  Anonymous (no derivable peer_id) is `%Claim{peer_id: nil, source: :none}`.
  Safe to call with empty or malformed binaries.
  """
  @spec classify(binary()) :: Claim.t()
  def classify(advertisement) when is_binary(advertisement) do
    case extract_local_name(advertisement) do
      <<@meshx_prefix, _::binary>> = name -> %Claim{peer_id: name, source: :advertised_name}
      _ -> %Claim{}
    end
  end

  def classify(_), do: %Claim{}

  @doc """
  Convenience wrapper around `classify/1` returning just the peer_id.

  Retained for callers that don't need the evidence source. New code
  should prefer `classify/1` — the source field carries observable
  signal about identity confidence.
  """
  @spec derive(binary()) :: binary() | nil
  def derive(advertisement), do: classify(advertisement).peer_id

  # Walk the AD structure. Each record is <<len, type, data:len-1>>.
  # Stop on a zero-length record (padding) or a truncated record at EOF.
  @spec extract_local_name(binary()) :: binary() | nil
  defp extract_local_name(<<>>), do: nil
  defp extract_local_name(<<0, _::binary>>), do: nil

  defp extract_local_name(<<len, rest::binary>>) when byte_size(rest) < len do
    # Truncated record — refuse to read past the buffer.
    nil
  end

  defp extract_local_name(<<len, type, data::binary-size(len - 1), _tail::binary>>)
       when type in [@local_name_complete, @local_name_shortened] do
    data
  end

  defp extract_local_name(<<len, _type, _data::binary-size(len - 1), tail::binary>>) do
    extract_local_name(tail)
  end
end
