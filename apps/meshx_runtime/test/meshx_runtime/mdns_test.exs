defmodule MeshxRuntime.MDNSTest do
  use ExUnit.Case, async: true

  alias MeshxRuntime.MDNS

  @service "_meshx._udp.local"
  @type_a 1
  @type_ptr 12
  @type_txt 16
  @type_srv 33
  @class_in 1
  @query_flags 0
  @response_flags 0x8400

  test "exposes the MeshX service name" do
    assert MDNS.service_name() == @service
  end

  test "round-trips host, term, long metadata, and IPv6-like addresses" do
    long_metadata = %{blob: String.duplicate("x", 500)}

    cases = [
      {"host-peer", :tcp, {"meshx.local", 4_040}, %{host?: true}},
      {"term-peer", :memory, :in_memory, long_metadata},
      {"ipv6-peer", :quic, {{0, 0, 0, 0, 0, 0, 0, 1}, 4_441}, %{ipv6?: true}}
    ]

    for {node_id, transport, address, metadata} <- cases do
      payload = MDNS.encode_announcement(node_id, transport, address, metadata)

      assert {:announcements, [announcement]} = MDNS.decode_packet(payload)
      assert announcement.node_id == node_id
      assert announcement.transport == transport
      assert announcement.address == address
      assert announcement.metadata == metadata
    end
  end

  test "falls back to SRV and A records when address TXT is absent" do
    instance = "meshx-fallback.#{@service}"
    host = "meshx-fallback.local"

    records = [
      resource(@service, @type_ptr, encode_name(instance)),
      resource(instance, @type_srv, <<0::16, 0::16, 4_040::16>> <> encode_name(host)),
      resource(
        instance,
        @type_txt,
        txt([
          term_entry("id", "fallback-peer"),
          "transport=udp",
          term_entry("metadata", %{relay?: true})
        ])
      ),
      resource(host, @type_a, <<127, 0, 0, 1>>)
    ]

    assert {:announcements, [announcement]} =
             records
             |> response_packet()
             |> MDNS.decode_packet()

    assert announcement.node_id == "fallback-peer"
    assert announcement.transport == :udp
    assert announcement.address == {{127, 0, 0, 1}, 4_040}
    assert announcement.metadata == %{relay?: true}
  end

  test "ignores announcements with missing or invalid TXT fields" do
    valid = MDNS.encode_announcement("peer", :tcp, {{127, 0, 0, 1}, 4_040}, %{})

    assert :ignore =
             valid |> :binary.replace("transport=tcp", "transport=bad") |> MDNS.decode_packet()

    assert :ignore =
             valid |> :binary.replace("transport=tcp", "transport-tcp") |> MDNS.decode_packet()

    assert :ignore =
             invalid_term_packet()
             |> MDNS.decode_packet()
  end

  test "decodes compressed query names" do
    base_name = encode_name(@service)
    base_question = base_name <> <<@type_a::16, @class_in::16>>
    pointer_question = <<0xC0, 12, @type_ptr::16, @class_in::16>>
    prefixed_pointer_question = <<5, "extra", 0xC0, 12, @type_ptr::16, @class_in::16>>

    assert :query =
             question_packet([base_question, pointer_question, prefixed_pointer_question])
             |> MDNS.decode_packet()
  end

  test "returns ignore for empty and unrelated responses" do
    assert :ignore = response_packet([]) |> MDNS.decode_packet()

    assert :ignore =
             [resource("other.local", 99, "opaque")]
             |> response_packet()
             |> MDNS.decode_packet()
  end

  test "returns parser errors for malformed packets" do
    assert {:error, :truncated_header} = MDNS.decode_packet(<<1, 2, 3>>)
    assert {:error, :truncated_packet} = question_packet([<<>>]) |> MDNS.decode_packet()
    assert {:error, :truncated_packet} = response_packet([<<>>]) |> MDNS.decode_packet()
    assert {:error, :dns_pointer_loop} = question_packet([<<0xC0, 12>>]) |> MDNS.decode_packet()
    assert {:error, :invalid_label} = question_packet([<<0x40>>]) |> MDNS.decode_packet()
  end

  test "returns parser errors for malformed resource data" do
    assert {:error, :truncated_packet} =
             [resource(@service, @type_ptr, <<5, "short">>)]
             |> response_packet()
             |> MDNS.decode_packet()

    assert {:error, :invalid_srv} =
             [resource("meshx-bad.#{@service}", @type_srv, <<0, 1>>)]
             |> response_packet()
             |> MDNS.decode_packet()

    assert {:error, :invalid_txt} =
             [resource("meshx-bad.#{@service}", @type_txt, <<10, "short">>)]
             |> response_packet()
             |> MDNS.decode_packet()
  end

  defp invalid_term_packet do
    instance = "meshx-invalid.#{@service}"

    [
      resource(@service, @type_ptr, encode_name(instance)),
      resource(
        instance,
        @type_txt,
        txt([
          "id=#{Base.encode64("not-an-external-term")}",
          "transport=tcp",
          term_entry("metadata", %{bad?: true})
        ])
      )
    ]
    |> response_packet()
  end

  defp question_packet(questions) do
    <<0::16, @query_flags::16, length(questions)::16, 0::16, 0::16, 0::16>> <>
      IO.iodata_to_binary(questions)
  end

  defp response_packet(records) do
    <<0::16, @response_flags::16, 0::16, length(records)::16, 0::16, 0::16>> <>
      IO.iodata_to_binary(records)
  end

  defp resource(name, type, rdata) do
    encode_name(name) <> <<type::16, @class_in::16, 120::32, byte_size(rdata)::16>> <> rdata
  end

  defp txt(entries) do
    entries
    |> Enum.map(fn entry -> <<byte_size(entry)>> <> entry end)
    |> IO.iodata_to_binary()
  end

  defp term_entry(key, value) do
    "#{key}=#{Base.encode64(:erlang.term_to_binary(value))}"
  end

  defp encode_name(name) do
    name
    |> String.trim_trailing(".")
    |> String.split(".", trim: true)
    |> Enum.map(fn label -> <<byte_size(label)>> <> label end)
    |> IO.iodata_to_binary()
    |> Kernel.<>(<<0>>)
  end
end
