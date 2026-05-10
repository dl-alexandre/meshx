defmodule MeshxProtocol.Ack do
  @moduledoc """
  ACK packet helpers.

  ACK payload layout:

      <<acked_msg_id::32-little>>
  """

  alias MeshxProtocol.Packet

  @spec packet(non_neg_integer(), keyword()) :: Packet.t()
  def packet(acked_msg_id, opts \\ []) do
    msg_id = Keyword.get(opts, :msg_id, :erlang.phash2({:ack, acked_msg_id, System.monotonic_time()}))
    ttl = Keyword.get(opts, :ttl, 1)

    %Packet{
      type: :ack,
      msg_id: msg_id,
      ttl: ttl,
      payload: <<acked_msg_id::32-little>>
    }
  end

  @spec decode(Packet.t()) :: {:ok, non_neg_integer()} | {:error, :not_ack | :malformed_ack}
  def decode(%Packet{type: :ack, payload: <<acked_msg_id::32-little>>}), do: {:ok, acked_msg_id}
  def decode(%Packet{type: :ack}), do: {:error, :malformed_ack}
  def decode(%Packet{}), do: {:error, :not_ack}
end
