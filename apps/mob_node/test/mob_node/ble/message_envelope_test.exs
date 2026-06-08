defmodule Mob.Node.BLE.MessageEnvelopeTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.MessageEnvelope

  # ── fixture corpus (code-as-fixture: stable bytes from documented opts) ──

  defp valid_broadcast do
    {:ok, e} =
      MessageEnvelope.build(
        message_id: <<1::128>>,
        sender_peer_id: "meshx-alpha",
        recipient_peer_id: nil,
        created_at: 1_700_000_000_000,
        ttl: 8,
        payload_type: "TX",
        payload: "broadcast hello",
        capability_requirements: 0x04
      )

    {e, MessageEnvelope.encode(e)}
  end

  defp valid_directed do
    {:ok, e} =
      MessageEnvelope.build(
        message_id: <<2::128>>,
        sender_peer_id: "meshx-alpha",
        recipient_peer_id: "meshx-beta",
        created_at: 1_700_000_001_000,
        ttl: 4,
        payload_type: "TX",
        payload: "directed hello",
        capability_requirements: 0x07
      )

    {e, MessageEnvelope.encode(e)}
  end

  defp unknown_payload_type do
    {:ok, e} =
      MessageEnvelope.build(
        message_id: <<3::128>>,
        sender_peer_id: "meshx-alpha",
        created_at: 0,
        payload_type: "XYZ_FUTURE",
        payload: <<0xDE, 0xAD, 0xBE, 0xEF>>,
        capability_requirements: 0
      )

    {e, MessageEnvelope.encode(e)}
  end

  # Hand-crafted malformed envelope: valid magic + version + flags, but
  # truncates partway through the message_id field. Parser must return
  # tagged error rather than raise.
  defp malformed_truncated do
    <<"MX", 1, 0, 0xAA, 0xBB, 0xCC>>
  end

  # ── build/1 validation ──

  describe "build/1 — required fields" do
    test "minimum valid envelope succeeds" do
      assert {:ok, %MessageEnvelope{}} =
               MessageEnvelope.build(
                 sender_peer_id: "alpha",
                 created_at: 0,
                 payload_type: "TX"
               )
    end

    test "generates a random 16-byte message_id when omitted" do
      {:ok, e1} =
        MessageEnvelope.build(sender_peer_id: "a", created_at: 0, payload_type: "TX")

      {:ok, e2} =
        MessageEnvelope.build(sender_peer_id: "a", created_at: 0, payload_type: "TX")

      assert byte_size(e1.message_id) == 16
      assert byte_size(e2.message_id) == 16
      # Two separate generations should differ (probabilistically — 128 bits).
      refute e1.message_id == e2.message_id
    end

    test "injected message_id is preserved verbatim (test determinism)" do
      mid = <<42::128>>

      {:ok, e} =
        MessageEnvelope.build(
          message_id: mid,
          sender_peer_id: "a",
          created_at: 0,
          payload_type: "TX"
        )

      assert e.message_id == mid
    end
  end

  describe "build/1 — rejects invalid fields" do
    test "rejects too-short message_id" do
      assert {:error, :invalid_message_id} =
               MessageEnvelope.build(
                 message_id: <<1, 2, 3>>,
                 sender_peer_id: "a",
                 created_at: 0,
                 payload_type: "TX"
               )
    end

    test "rejects empty sender_peer_id" do
      assert {:error, :invalid_sender_peer_id} =
               MessageEnvelope.build(
                 sender_peer_id: "",
                 created_at: 0,
                 payload_type: "TX"
               )
    end

    test "rejects oversized sender_peer_id" do
      big = String.duplicate("x", 33)

      assert {:error, :invalid_sender_peer_id} =
               MessageEnvelope.build(
                 sender_peer_id: big,
                 created_at: 0,
                 payload_type: "TX"
               )
    end

    test "rejects empty recipient_peer_id (but allows nil for broadcast)" do
      assert {:error, :invalid_recipient_peer_id} =
               MessageEnvelope.build(
                 sender_peer_id: "a",
                 recipient_peer_id: "",
                 created_at: 0,
                 payload_type: "TX"
               )

      # nil is fine — broadcast.
      assert {:ok, %{recipient_peer_id: nil}} =
               MessageEnvelope.build(
                 sender_peer_id: "a",
                 recipient_peer_id: nil,
                 created_at: 0,
                 payload_type: "TX"
               )
    end

    test "rejects negative created_at" do
      assert {:error, :invalid_created_at} =
               MessageEnvelope.build(
                 sender_peer_id: "a",
                 created_at: -1,
                 payload_type: "TX"
               )
    end

    test "rejects ttl above the bound" do
      assert {:error, :invalid_ttl} =
               MessageEnvelope.build(
                 sender_peer_id: "a",
                 created_at: 0,
                 ttl: MessageEnvelope.max_ttl() + 1,
                 payload_type: "TX"
               )
    end

    test "rejects negative ttl" do
      assert {:error, :invalid_ttl} =
               MessageEnvelope.build(
                 sender_peer_id: "a",
                 created_at: 0,
                 ttl: -1,
                 payload_type: "TX"
               )
    end

    test "accepts ttl at the exact bound" do
      assert {:ok, _} =
               MessageEnvelope.build(
                 sender_peer_id: "a",
                 created_at: 0,
                 ttl: MessageEnvelope.max_ttl(),
                 payload_type: "TX"
               )
    end

    test "rejects empty payload_type" do
      assert {:error, :invalid_payload_type} =
               MessageEnvelope.build(
                 sender_peer_id: "a",
                 created_at: 0,
                 payload_type: ""
               )
    end

    test "rejects payload larger than @max_payload_size" do
      oversized = :binary.copy(<<0>>, MessageEnvelope.max_payload_size() + 1)

      assert {:error, :payload_too_large} =
               MessageEnvelope.build(
                 sender_peer_id: "a",
                 created_at: 0,
                 payload_type: "TX",
                 payload: oversized
               )
    end

    test "accepts payload at the exact bound" do
      exact = :binary.copy(<<0>>, MessageEnvelope.max_payload_size())

      assert {:ok, _} =
               MessageEnvelope.build(
                 sender_peer_id: "a",
                 created_at: 0,
                 payload_type: "TX",
                 payload: exact
               )
    end
  end

  # ── encode + parse round-trip ──

  describe "round-trip — build → encode → parse" do
    test "valid broadcast survives round-trip byte-identical" do
      {original, bytes} = valid_broadcast()
      assert {:ok, parsed} = MessageEnvelope.parse(bytes)
      assert parsed == original
      assert parsed.recipient_peer_id == nil
    end

    test "valid directed survives round-trip byte-identical" do
      {original, bytes} = valid_directed()
      assert {:ok, parsed} = MessageEnvelope.parse(bytes)
      assert parsed == original
      assert parsed.recipient_peer_id == "meshx-beta"
    end

    test "unknown payload_type round-trips and is preserved (not executed)" do
      {original, bytes} = unknown_payload_type()
      assert {:ok, parsed} = MessageEnvelope.parse(bytes)
      assert parsed.payload_type == "XYZ_FUTURE"
      # The envelope layer does not interpret payload bytes for unknown types.
      assert parsed.payload == <<0xDE, 0xAD, 0xBE, 0xEF>>
      assert parsed == original
    end

    test "empty payload round-trips correctly" do
      {:ok, e} =
        MessageEnvelope.build(
          sender_peer_id: "a",
          created_at: 100,
          payload_type: "PING"
        )

      assert {:ok, ^e} = MessageEnvelope.parse(MessageEnvelope.encode(e))
      assert e.payload == <<>>
    end

    test "max payload size round-trips" do
      payload = :binary.copy("z", MessageEnvelope.max_payload_size())

      {:ok, e} =
        MessageEnvelope.build(
          sender_peer_id: "a",
          created_at: 0,
          payload_type: "TX",
          payload: payload
        )

      assert {:ok, ^e} = MessageEnvelope.parse(MessageEnvelope.encode(e))
    end

    test "capability_requirements bitmap round-trips for every bit pattern" do
      for caps <- [0x00, 0x01, 0x07, 0x1F, 0xFF] do
        {:ok, e} =
          MessageEnvelope.build(
            sender_peer_id: "a",
            created_at: 0,
            payload_type: "TX",
            capability_requirements: caps
          )

        assert {:ok, %{capability_requirements: ^caps}} =
                 MessageEnvelope.parse(MessageEnvelope.encode(e))
      end
    end
  end

  # ── parse/1 robustness ──

  describe "parse/1 — malformed input returns tagged errors, never raises" do
    test "empty input" do
      assert {:error, :missing_magic} = MessageEnvelope.parse(<<>>)
    end

    test "wrong magic" do
      assert {:error, :missing_magic} = MessageEnvelope.parse(<<"XX", 1, 0>>)
    end

    test "unsupported envelope version" do
      assert {:error, :unsupported_envelope_version} =
               MessageEnvelope.parse(<<"MX", 99, 0>>)
    end

    test "non-zero flags (reserved in v1)" do
      assert {:error, :invalid_flags} = MessageEnvelope.parse(<<"MX", 1, 0xFF>>)
    end

    test "truncated mid-envelope" do
      assert {:error, :truncated_envelope} = MessageEnvelope.parse(malformed_truncated())
    end

    test "non-binary input" do
      assert {:error, :missing_magic} = MessageEnvelope.parse(123)
      assert {:error, :missing_magic} = MessageEnvelope.parse(nil)
      assert {:error, :missing_magic} = MessageEnvelope.parse(%{})
    end

    test "valid header but oversized payload_len field" do
      # Build a valid envelope, then surgically rewrite its payload_len
      # bytes to claim a length far above the allowed max.
      {_e, bytes} = valid_broadcast()

      header_size = byte_size(bytes) - 17
      <<header::binary-size(^header_size), _payload_len::16, payload::binary>> = bytes

      forged = <<header::binary, 0xFFFF::16, payload::binary>>
      assert {:error, :payload_too_large} = MessageEnvelope.parse(forged)
    end
  end

  # ── replay-style: parse fixture-built bytes without a transport ──

  describe "replay-style parsing" do
    test "broadcast fixture bytes parse without any transport involvement" do
      {original, bytes} = valid_broadcast()
      assert {:ok, parsed} = MessageEnvelope.parse(bytes)
      assert parsed.sender_peer_id == original.sender_peer_id
      assert parsed.recipient_peer_id == nil
      assert parsed.payload == "broadcast hello"
    end

    test "directed fixture bytes parse without any transport involvement" do
      {_original, bytes} = valid_directed()
      assert {:ok, parsed} = MessageEnvelope.parse(bytes)
      assert parsed.recipient_peer_id == "meshx-beta"
      assert parsed.payload_type == "TX"
    end

    test "two independent encodes of the same opts produce byte-identical output" do
      opts = [
        message_id: <<7::128>>,
        sender_peer_id: "alpha",
        recipient_peer_id: "beta",
        created_at: 12345,
        ttl: 3,
        payload_type: "TX",
        payload: "deterministic",
        capability_requirements: 0x07
      ]

      {:ok, e1} = MessageEnvelope.build(opts)
      {:ok, e2} = MessageEnvelope.build(opts)

      assert MessageEnvelope.encode(e1) == MessageEnvelope.encode(e2)
    end
  end
end
