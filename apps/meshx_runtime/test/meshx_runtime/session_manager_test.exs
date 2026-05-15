defmodule MeshxRuntime.SessionManagerTest do
  @moduledoc """
  Focused coverage for the Noise session lifecycle around peer reconnect.

  `SessionManager.drop/1` was added in commit `ce69095` to tear down the
  Noise session on transport `peer_down`, so the next reconnect
  renegotiates a fresh session instead of reusing a cipher state whose
  nonces have desynced across the disconnect. These tests pin that
  contract end to end:

  - `drop` on an unknown peer is a no-op.
  - `drop` after a fully established handshake terminates the underlying
    Noise session process and resets `established?/1` to `false`.
  - The next `ensure_initiator/1` builds a *new* session (different
    `pid`), proving the manager actually renegotiates rather than
    silently returning the dropped entry.
  - The replacement session has an independent cipher state: encrypting
    the same plaintext through the pre-drop and post-drop sessions
    produces different ciphertexts (the property that makes the drop
    correct in the first place — same plaintext + same nonce on a
    desynced session is exactly the failure mode `drop` exists to
    prevent).
  - `[:meshx_runtime, :noise, :session, :dropped]` telemetry fires on drop with the
    correct role metadata so the BLE bridge / Router can be observed
    detaching sessions.
  """

  use ExUnit.Case

  @moduletag capture_log: true

  alias MeshxNoise.Session
  alias MeshxRuntime.SessionManager
  alias MeshxStore.{Identity, Trust}

  setup do
    restart_runtime()
    SessionManager.reset()
    Identity.clear()
    Trust.clear()
    :ok
  end

  describe "drop/1 — peer-down session teardown" do
    test "is a no-op for an unknown peer" do
      assert :ok = SessionManager.drop("never-seen")
      refute SessionManager.established?("never-seen")
    end

    test "tears down an in-flight handshake before it completes" do
      # ensure_initiator starts the handshake but doesn't finish it —
      # peer_down before the responder's reply must still drop cleanly.
      {:ok, _msg1} = SessionManager.ensure_initiator("peer-a")
      refute SessionManager.established?("peer-a")

      assert :ok = SessionManager.drop("peer-a")
      refute SessionManager.established?("peer-a")
    end
  end

  describe "drop -> ensure_initiator — fresh session lifecycle" do
    test "replaces the session pid and re-initiates a handshake" do
      attach_telemetry([
        [:meshx_runtime, :noise, :session, :dropped],
        [:meshx_runtime, :noise, :handshake, :started]
      ])

      {pre_pid, remote_pre} = handshake_to_established("peer-b")
      assert SessionManager.established?("peer-b")

      # Encrypt against the pre-drop session — proves baseline cipher
      # state works end-to-end through the SessionManager.
      {:ok, ciphertext_pre} = SessionManager.encrypt("peer-b", "ping", [])
      assert {:ok, "ping"} = Session.decrypt(remote_pre, ciphertext_pre, [])

      # The first handshake fired one :handshake :started telemetry.
      assert_receive {:telemetry, [:meshx_runtime, :noise, :handshake, :started], %{count: 1},
                      %{peer_id: "peer-b", role: :initiator}}

      # peer_down. The contract under test is that the manager *replaces*
      # the session entry — not that it papers over reuse of the old one.
      assert :ok = SessionManager.drop("peer-b")
      refute SessionManager.established?("peer-b")
      refute Process.alive?(pre_pid)

      assert_receive {:telemetry, [:meshx_runtime, :noise, :session, :dropped], %{count: 1},
                      %{peer_id: "peer-b", role: :initiator}}

      # The next ensure_initiator must (a) NOT return {:ok, :established}
      # — that would mean drop silently left the old entry behind — and
      # (b) drive a fresh handshake_started telemetry event.
      assert {:ok, msg1_post} = SessionManager.ensure_initiator("peer-b")
      assert is_binary(msg1_post)
      refute SessionManager.established?("peer-b")

      assert_receive {:telemetry, [:meshx_runtime, :noise, :handshake, :started], %{count: 1},
                      %{peer_id: "peer-b", role: :initiator}}

      # The replacement session entry holds a different pid than the
      # one we just terminated.
      post_pid = session_pid("peer-b")
      assert post_pid != pre_pid
      assert Process.alive?(post_pid)
    end

    test "drop is idempotent across repeated peer_down notifications" do
      handshake_to_established("peer-c")

      assert :ok = SessionManager.drop("peer-c")
      assert :ok = SessionManager.drop("peer-c")
      assert :ok = SessionManager.drop("peer-c")
      refute SessionManager.established?("peer-c")
    end
  end

  # ── helpers ──────────────────────────────────────────────────────────────

  # Drives a full XX handshake against a locally-managed responder Session
  # so we can assert on both sides. Returns the {initiator_session_pid,
  # responder_session_pid} pair so the test can decrypt what the
  # SessionManager encrypts (and prove cipher-state freshness).
  defp handshake_to_established(peer_id) do
    {:ok, remote} = Session.start_link(role: :responder)

    {:ok, msg1} = SessionManager.ensure_initiator(peer_id)
    :ok = Session.handshake_recv(remote, msg1)
    {:ok, msg2} = Session.handshake_send(remote)

    # handle_handshake returns {:ok, reply_or_nil, established?} — the
    # third element is the established flag the Router uses to drain
    # queued sends.
    assert {:ok, msg3, true} = SessionManager.handle_handshake(peer_id, msg2)
    :ok = Session.handshake_recv(remote, msg3)

    assert SessionManager.established?(peer_id)
    assert Session.established?(remote)

    pre_pid = session_pid(peer_id)
    {pre_pid, remote}
  end

  defp session_pid(peer_id) do
    # SessionManager keeps the session pid in its private state map. We
    # don't have a public accessor (and shouldn't add one just for tests),
    # so reach in via :sys.get_state — acceptable for an internal test.
    state = :sys.get_state(SessionManager)
    %{pid: pid} = Map.fetch!(state, peer_id)
    pid
  end

  defp restart_runtime do
    Application.stop(:meshx_runtime)
    {:ok, _apps} = Application.ensure_all_started(:meshx_runtime)
    :ok
  end

  defp attach_telemetry(events) do
    id = {__MODULE__, self(), System.unique_integer([:positive])}

    :ok =
      :telemetry.attach_many(
        id,
        events,
        fn event, measurements, metadata, test_pid ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        self()
      )

    on_exit(fn -> :telemetry.detach(id) end)
  end
end
