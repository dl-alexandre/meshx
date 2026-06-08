defmodule Mob.Runtime.MDNS do
  @moduledoc """
  Minimal mDNS/DNS-SD packet support for MeshX LAN discovery.

  MeshX advertises `_mob._udp.local` with PTR, SRV, TXT, and optional A
  records. TXT records carry the stable peer id, transport, address, and
  metadata needed to build `Mob.Routing.Peer` values.
  """

  import Bitwise

  @service "_mob._udp.local"
  @ttl 120
  @type_a 1
  @type_ptr 12
  @type_txt 16
  @type_srv 33
  @class_in 1
  @response_flags 0x8400
  @query_flags 0
  @allowed_transports [:tcp, :udp, :ble, :quic, :memory]

  @type announcement :: %{
          node_id: term(),
          transport: atom(),
          address: term(),
          metadata: map()
        }

  @doc "Returns the MeshX DNS-SD service name."
  @spec service_name() :: String.t()
  def service_name, do: @service

  @doc "Encodes a multicast DNS PTR query for the MeshX service."
  @spec encode_query() :: binary()
  def encode_query do
    question = encode_name(@service) <> <<@type_ptr::16, @class_in::16>>
    <<0::16, @query_flags::16, 1::16, 0::16, 0::16, 0::16>> <> question
  end

  @doc "Encodes a DNS-SD mDNS response announcing one MeshX peer."
  @spec encode_announcement(term(), atom(), term(), map()) :: binary()
  def encode_announcement(node_id, transport, address, metadata) when is_map(metadata) do
    instance = instance_name(node_id)
    host = host_name(node_id)
    {ip, port} = address_ip_port(address)

    records = [
      resource(@service, @type_ptr, @class_in, @ttl, encode_name(instance)),
      resource(instance, @type_srv, @class_in ||| 0x8000, @ttl, encode_srv(port, host)),
      resource(
        instance,
        @type_txt,
        @class_in ||| 0x8000,
        @ttl,
        encode_txt(node_id, transport, address, metadata)
      )
    ]

    records =
      case ip do
        {a, b, c, d} ->
          [resource(host, @type_a, @class_in ||| 0x8000, @ttl, <<a, b, c, d>>) | records]

        _other ->
          records
      end

    <<0::16, @response_flags::16, 0::16, length(records)::16, 0::16, 0::16>> <>
      IO.iodata_to_binary(Enum.reverse(records))
  end

  @doc """
  Decodes an mDNS packet.

  Returns:

    * `{:announcements, announcements}` for MeshX service responses.
    * `:query` for a MeshX PTR query.
    * `:ignore` for unrelated DNS packets.
    * `{:error, reason}` for malformed DNS packets.
  """
  @spec decode_packet(binary()) ::
          {:announcements, [announcement()]} | :query | :ignore | {:error, term()}
  def decode_packet(packet) when is_binary(packet) do
    with {:ok, header, offset} <- decode_header(packet),
         {:ok, questions, offset} <- decode_questions(packet, offset, header.qdcount),
         {:ok, records, _offset} <-
           decode_records(packet, offset, header.ancount + header.nscount + header.arcount) do
      if mob_query?(questions) do
        :query
      else
        case announcements(records) do
          [] -> :ignore
          found -> {:announcements, found}
        end
      end
    end
  end

  defp decode_header(<<_id::16, flags::16, qd::16, an::16, ns::16, ar::16, _rest::binary>>) do
    {:ok, %{flags: flags, qdcount: qd, ancount: an, nscount: ns, arcount: ar}, 12}
  end

  defp decode_header(_packet), do: {:error, :truncated_header}

  defp decode_questions(packet, offset, count) do
    Enum.reduce_while(1..count//1, {:ok, [], offset}, fn _idx, {:ok, acc, current} ->
      with {:ok, name, current} <- decode_name(packet, current),
           {:ok, <<type::16, class::16>>, current} <- take(packet, current, 4) do
        {:cont, {:ok, [%{name: name, type: type, class: class} | acc], current}}
      else
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, questions, offset} -> {:ok, Enum.reverse(questions), offset}
      error -> error
    end
  end

  defp decode_records(packet, offset, count) do
    Enum.reduce_while(1..count//1, {:ok, [], offset}, fn _idx, {:ok, acc, current} ->
      with {:ok, name, current} <- decode_name(packet, current),
           {:ok, <<type::16, class::16, ttl::32, len::16>>, current} <- take(packet, current, 10),
           {:ok, rdata, current} <- take(packet, current, len),
           {:ok, data} <- decode_rdata(type, packet, current - len, rdata) do
        {:cont,
         {:ok, [%{name: name, type: type, class: class, ttl: ttl, data: data} | acc], current}}
      else
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, records, offset} -> {:ok, Enum.reverse(records), offset}
      error -> error
    end
  end

  defp decode_rdata(@type_ptr, packet, offset, _rdata),
    do: decode_name(packet, offset) |> elem_name()

  defp decode_rdata(@type_srv, packet, offset, rdata) do
    with <<_priority::16, _weight::16, port::16, _rest::binary>> <- rdata,
         {:ok, target, _offset} <- decode_name(packet, offset + 6) do
      {:ok, %{port: port, target: target}}
    else
      _ -> {:error, :invalid_srv}
    end
  end

  defp decode_rdata(@type_txt, _packet, _offset, rdata), do: decode_txt(rdata)
  defp decode_rdata(@type_a, _packet, _offset, <<a, b, c, d>>), do: {:ok, {a, b, c, d}}
  defp decode_rdata(_type, _packet, _offset, rdata), do: {:ok, rdata}

  defp elem_name({:ok, name, _offset}), do: {:ok, name}
  defp elem_name(error), do: error

  defp mob_query?(questions) do
    Enum.any?(questions, fn question ->
      normalize_name(question.name) == @service and question.type == @type_ptr
    end)
  end

  defp announcements(records) do
    instances =
      records
      |> Enum.filter(&(&1.type == @type_ptr and normalize_name(&1.name) == @service))
      |> Enum.map(&normalize_name(&1.data))

    Enum.flat_map(instances, fn instance ->
      txt =
        records
        |> Enum.find(&(&1.type == @type_txt and normalize_name(&1.name) == instance))
        |> case do
          nil -> %{}
          record -> record.data
        end

      with {:ok, node_id} <- decode_term_field(txt, "id"),
           {:ok, transport} <- decode_transport(Map.get(txt, "transport")),
           {:ok, metadata} <- decode_term_field(txt, "metadata") do
        address =
          case decode_term_field(txt, "address") do
            {:ok, value} -> value
            _error -> address_from_records(instance, records)
          end

        [%{node_id: node_id, transport: transport, address: address, metadata: metadata}]
      else
        _error -> []
      end
    end)
  end

  defp address_from_records(instance, records) do
    srv = Enum.find(records, &(&1.type == @type_srv and normalize_name(&1.name) == instance))

    with %{data: %{target: target, port: port}} <- srv,
         %{data: ip} <-
           Enum.find(
             records,
             &(&1.type == @type_a and normalize_name(&1.name) == normalize_name(target))
           ) do
      {ip, port}
    else
      _ -> nil
    end
  end

  defp decode_transport(nil), do: {:error, :missing_transport}

  defp decode_transport(value) do
    value = to_string(value)

    Enum.find(@allowed_transports, &(Atom.to_string(&1) == value))
    |> case do
      nil -> {:error, :invalid_transport}
      transport -> {:ok, transport}
    end
  end

  defp resource(name, type, class, ttl, rdata) do
    [encode_name(name), <<type::16, class::16, ttl::32, byte_size(rdata)::16>>, rdata]
  end

  defp encode_srv(port, host) do
    <<0::16, 0::16, port::16>> <> encode_name(host)
  end

  defp encode_txt(node_id, transport, address, metadata) do
    txt =
      []
      |> put_txt_chunks("id", Base.encode64(:erlang.term_to_binary(node_id)))
      |> put_txt("transport", Atom.to_string(transport))
      |> put_txt_chunks("address", Base.encode64(:erlang.term_to_binary(address)))
      |> put_txt_chunks("metadata", Base.encode64(:erlang.term_to_binary(metadata)))

    txt
    |> Enum.reverse()
    |> Enum.map(fn entry -> <<byte_size(entry)>> <> entry end)
    |> IO.iodata_to_binary()
  end

  defp put_txt(entries, key, value) do
    entry = "#{key}=#{value}"

    if byte_size(entry) <= 255 do
      [entry | entries]
    else
      entries
    end
  end

  defp put_txt_chunks(entries, key, value) do
    value
    |> chunk_binary(230)
    |> Enum.with_index()
    |> Enum.reduce(entries, fn {chunk, idx}, acc -> put_txt(acc, "#{key}#{idx}", chunk) end)
  end

  defp chunk_binary(binary, size) when byte_size(binary) <= size, do: [binary]

  defp chunk_binary(binary, size) do
    <<chunk::binary-size(^size), rest::binary>> = binary
    [chunk | chunk_binary(rest, size)]
  end

  defp decode_txt(rdata), do: decode_txt(rdata, %{})

  defp decode_txt(<<>>, acc), do: {:ok, acc}

  defp decode_txt(<<len, rest::binary>>, acc) when byte_size(rest) >= len do
    <<entry::binary-size(^len), rest::binary>> = rest

    acc =
      case String.split(entry, "=", parts: 2) do
        [key, value] -> Map.put(acc, key, value)
        _other -> acc
      end

    decode_txt(rest, acc)
  end

  defp decode_txt(_rdata, _acc), do: {:error, :invalid_txt}

  defp decode_term_field(txt, key) do
    value =
      Map.get(txt, key) ||
        txt
        |> Enum.sort_by(fn {k, _v} -> k end)
        |> Enum.filter(fn {k, _v} -> String.match?(k, ~r/^#{Regex.escape(key)}\d+$/) end)
        |> Enum.map_join(fn {_k, v} -> v end)

    with value when is_binary(value) and value != "" <- value,
         {:ok, binary} <- Base.decode64(value),
         {:ok, term} <- safe_binary_to_term(binary) do
      {:ok, term}
    else
      _ -> {:error, {:missing_txt, key}}
    end
  end

  defp encode_name(name) do
    name
    |> normalize_name()
    |> String.split(".", trim: true)
    |> Enum.map(fn label ->
      if byte_size(label) > 63, do: raise(ArgumentError, "DNS label too long: #{label}")
      <<byte_size(label)>> <> label
    end)
    |> IO.iodata_to_binary()
    |> Kernel.<>(<<0>>)
  end

  defp decode_name(packet, offset), do: decode_name(packet, offset, MapSet.new(), [])

  defp decode_name(packet, offset, seen, labels) do
    if MapSet.member?(seen, offset) do
      {:error, :dns_pointer_loop}
    else
      decode_name_part(packet, offset, seen, labels)
    end
  end

  defp decode_name_part(packet, offset, seen, labels) do
    with {:ok, <<len>>, offset_after_len} <- take(packet, offset, 1) do
      cond do
        len == 0 ->
          {:ok, labels |> Enum.reverse() |> Enum.join("."), offset_after_len}

        (len &&& 0xC0) == 0xC0 ->
          with {:ok, <<next>>, offset_after_pointer} <- take(packet, offset_after_len, 1),
               pointer = (len &&& 0x3F) <<< 8 ||| next,
               {:ok, pointed, _} <- decode_name(packet, pointer, MapSet.put(seen, offset), []) do
            {:ok, join_labels(labels, pointed), offset_after_pointer}
          end

        (len &&& 0xC0) == 0 ->
          with {:ok, label, offset_after_label} <- take(packet, offset_after_len, len) do
            decode_name(packet, offset_after_label, seen, [label | labels])
          end

        true ->
          {:error, :invalid_label}
      end
    end
  end

  defp join_labels([], pointed), do: pointed
  defp join_labels(labels, ""), do: labels |> Enum.reverse() |> Enum.join(".")
  defp join_labels(labels, pointed), do: Enum.join(Enum.reverse(labels), ".") <> "." <> pointed

  defp take(packet, offset, size) when offset >= 0 and size >= 0 do
    if byte_size(packet) >= offset + size do
      {:ok, binary_part(packet, offset, size), offset + size}
    else
      {:error, :truncated_packet}
    end
  end

  defp normalize_name(name) do
    name
    |> to_string()
    |> String.trim_trailing(".")
    |> String.downcase()
  end

  defp instance_name(node_id), do: "mob-" <> encoded_id(node_id) <> "." <> @service
  defp host_name(node_id), do: "mob-" <> encoded_id(node_id) <> ".local"

  defp encoded_id(node_id) do
    node_id
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
  end

  defp address_ip_port({{a, b, c, d}, port}), do: {{a, b, c, d}, port}
  defp address_ip_port({ip, port}) when is_tuple(ip), do: {ip, port}
  defp address_ip_port({_host, port}), do: {nil, port}
  defp address_ip_port(_address), do: {nil, 0}

  defp safe_binary_to_term(payload) do
    {:ok, :erlang.binary_to_term(payload, [:safe])}
  rescue
    _error -> {:error, :invalid_term}
  end
end
