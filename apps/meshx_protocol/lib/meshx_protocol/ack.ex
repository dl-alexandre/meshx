defmodule MeshxProtocol.Ack do
  @moduledoc """
  Delivery acknowledgement and read-receipt packet helpers.

  Typed receipt payload layout:

      <<1::8, kind::8, acked_msg_id::32-little>>

  `kind` is `1` for delivery acknowledgements and `2` for read receipts.
  The legacy four-byte payload layout is still accepted as a delivery
  acknowledgement:

      <<acked_msg_id::32-little>>
  """

  alias MeshxProtocol.Packet

  @payload_version 1
  @kind_delivery 1
  @kind_read 2

  @type kind :: :delivery | :read
  @type receipt :: %{
          kind: kind(),
          acked_msg_id: non_neg_integer()
        }

  @spec packet(non_neg_integer(), keyword()) :: Packet.t()
  def packet(acked_msg_id, opts \\ []), do: delivery_packet(acked_msg_id, opts)

  @spec delivery_packet(non_neg_integer(), keyword()) :: Packet.t()
  def delivery_packet(acked_msg_id, opts \\ []) do
    receipt_packet(:delivery, acked_msg_id, opts)
  end

  @spec read_receipt_packet(non_neg_integer(), keyword()) :: Packet.t()
  def read_receipt_packet(acked_msg_id, opts \\ []) do
    receipt_packet(:read, acked_msg_id, opts)
  end

  @spec decode(Packet.t()) ::
          {:ok, non_neg_integer()} | {:error, :not_ack | :malformed_ack | :unknown_receipt_kind}
  def decode(%Packet{} = packet) do
    case decode_receipt(packet) do
      {:ok, %{acked_msg_id: acked_msg_id}} -> {:ok, acked_msg_id}
      error -> error
    end
  end

  @spec decode_receipt(Packet.t()) ::
          {:ok, receipt()} | {:error, :not_ack | :malformed_ack | :unknown_receipt_kind}
  def decode_receipt(%Packet{type: :ack, payload: <<acked_msg_id::32-little>>}) do
    {:ok, %{kind: :delivery, acked_msg_id: acked_msg_id}}
  end

  def decode_receipt(%Packet{
        type: :ack,
        payload: <<@payload_version::8, kind_byte::8, acked_msg_id::32-little>>
      }) do
    case kind(kind_byte) do
      {:ok, kind} -> {:ok, %{kind: kind, acked_msg_id: acked_msg_id}}
      :error -> {:error, :unknown_receipt_kind}
    end
  end

  def decode_receipt(%Packet{type: :ack}), do: {:error, :malformed_ack}
  def decode_receipt(%Packet{}), do: {:error, :not_ack}

  defp receipt_packet(kind, acked_msg_id, opts) do
    msg_id =
      Keyword.get(opts, :msg_id, :erlang.phash2({:ack, acked_msg_id, System.monotonic_time()}))

    ttl = Keyword.get(opts, :ttl, 1)

    %Packet{
      type: :ack,
      msg_id: msg_id,
      ttl: ttl,
      payload: <<@payload_version::8, kind_byte(kind)::8, acked_msg_id::32-little>>
    }
  end

  defp kind_byte(:delivery), do: @kind_delivery
  defp kind_byte(:read), do: @kind_read

  defp kind(@kind_delivery), do: {:ok, :delivery}
  defp kind(@kind_read), do: {:ok, :read}
  defp kind(_), do: :error
end
