defmodule MeshxProtocol.Packet do
  @moduledoc """
  Core packet struct and type definitions for the MeshX wire protocol.
  """

  alias MeshxProtocol.Packet

  # --- Type constants ---

  @type_data 0x01
  @type_ack 0x02
  @type_gossip 0x03
  @type_control 0x04
  @type_fragment 0x05

  @flag_encrypted 0x01
  @flag_fragmented 0x02
  @flag_ack_requested 0x04
  @flag_channel 0x08

  # --- Struct ---

  @enforce_keys [:type, :msg_id, :payload]
  defstruct [
    :type,
    :msg_id,
    :payload,
    version: 0x01,
    flags: 0x00,
    ttl: 64,
    channel_id: ""
  ]

  @type t :: %Packet{
          version: pos_integer(),
          type: atom(),
          flags: non_neg_integer(),
          ttl: non_neg_integer(),
          msg_id: non_neg_integer(),
          payload: binary(),
          channel_id: binary()
        }

  # --- Public API ---

  @doc "Returns the supported protocol version."
  def version, do: 0x01

  @doc "Converts an atom type to its byte value."
  def type_byte(:data), do: @type_data
  def type_byte(:ack), do: @type_ack
  def type_byte(:gossip), do: @type_gossip
  def type_byte(:control), do: @type_control
  def type_byte(:fragment), do: @type_fragment
  def type_byte(_), do: :unknown

  @doc "Converts a byte value to its atom type."
  def byte_type(@type_data), do: :data
  def byte_type(@type_ack), do: :ack
  def byte_type(@type_gossip), do: :gossip
  def byte_type(@type_control), do: :control
  def byte_type(@type_fragment), do: :fragment
  def byte_type(_), do: :unknown

  @doc "Flag constants."
  def flag_encrypted, do: @flag_encrypted
  def flag_fragmented, do: @flag_fragmented
  def flag_ack_requested, do: @flag_ack_requested
  def flag_channel, do: @flag_channel

  @doc "Checks if a specific flag is set."
  def flag_set?(flags, flag), do: Bitwise.band(flags, flag) == flag

  @doc "Sets a specific flag."
  def set_flag(flags, flag), do: Bitwise.bor(flags, flag)

  @doc "Clears a specific flag."
  def clear_flag(flags, flag), do: Bitwise.band(flags, Bitwise.bnot(flag))

  @doc "Decrements TTL, returning the new value."
  def decrement_ttl(%Packet{ttl: 0}), do: 0
  def decrement_ttl(%Packet{ttl: ttl}), do: max(0, ttl - 1)

  @doc "Builds a new packet with default values."
  def new(type, msg_id, payload \\ <<>>) do
    %Packet{type: type, msg_id: msg_id, payload: payload}
  end
end
