defmodule MeshxStore.OutboxTest do
  use ExUnit.Case
  alias MeshxStore.Outbox

  setup do
    MeshxStore.TestHelpers.ensure_db_started()
    Outbox.clear()
    :ok
  end

  test "enqueue and retrieve pending messages" do
    assert {:ok, msg} = Outbox.enqueue(%{msg_id: 1, payload: "hello", destinations: ["peer_a"]})
    assert msg.status == :pending

    pending = Outbox.pending()
    assert length(pending) == 1
    assert hd(pending).msg_id == 1
  end

  test "mark_sent updates status" do
    {:ok, _} = Outbox.enqueue(%{msg_id: 2, payload: "x"})
    assert {:ok, updated} = Outbox.mark_sent(2)
    assert updated.status == :sent
    assert Outbox.pending() == []
  end

  test "mark_sent_by_id updates a specific row" do
    {:ok, msg} = Outbox.enqueue(%{msg_id: 22, payload: "x"})
    assert {:ok, updated} = Outbox.mark_sent_by_id(msg.id)
    assert updated.status == :sent
  end

  test "mark_failed increments attempts and eventually fails" do
    {:ok, _} = Outbox.enqueue(%{msg_id: 3, payload: "y", max_attempts: 2})

    assert {:ok, m1} = Outbox.mark_failed(3)
    assert m1.attempts == 1
    assert m1.status == :pending

    assert {:ok, m2} = Outbox.mark_failed(3)
    assert m2.attempts == 2
    assert m2.status == :failed
  end

  test "mark_failed_by_id increments attempts for a specific row" do
    {:ok, msg} = Outbox.enqueue(%{msg_id: 33, payload: "y", max_attempts: 2})

    assert {:ok, updated} = Outbox.mark_failed_by_id(msg.id)
    assert updated.attempts == 1
    assert updated.status == :pending
  end

  test "record_attempt_by_id fails when max attempts is reached" do
    {:ok, msg} = Outbox.enqueue(%{msg_id: 34, payload: "y", max_attempts: 1})

    assert {:ok, updated} = Outbox.record_attempt_by_id(msg.id)
    assert updated.attempts == 1
    assert updated.status == :failed
  end

  test "ack marks matching destination row sent" do
    {:ok, _} = Outbox.enqueue(%{msg_id: 50, payload: "x", destinations: ["peer-a"]})
    {:ok, _} = Outbox.enqueue(%{msg_id: 51, payload: "y", destinations: ["peer-b"]})

    assert {:ok, sent} = Outbox.ack(50, "peer-a")
    assert sent.status == :sent
    assert Outbox.pending_for_destination("peer-a") == []
    assert [%{msg_id: 51}] = Outbox.pending_for_destination("peer-b")
  end

  test "ack can mark an exhausted row sent if the ack arrives late" do
    {:ok, msg} =
      Outbox.enqueue(%{msg_id: 52, payload: "x", destinations: ["peer-a"], max_attempts: 1})

    assert {:ok, failed} = Outbox.record_attempt_by_id(msg.id)
    assert failed.status == :failed

    assert {:ok, sent} = Outbox.ack(52, "peer-a")
    assert sent.status == :sent
  end

  test "pending_for_destination includes direct and broadcast entries" do
    {:ok, _} = Outbox.enqueue(%{msg_id: 40, payload: "a", destinations: ["peer-a"]})
    {:ok, _} = Outbox.enqueue(%{msg_id: 41, payload: "b", destinations: ["peer-b"]})
    {:ok, _} = Outbox.enqueue(%{msg_id: 42, payload: "c", destinations: []})

    ids =
      "peer-a"
      |> Outbox.pending_for_destination()
      |> Enum.map(& &1.msg_id)
      |> Enum.sort()

    assert ids == [40, 42]
  end

  test "retryable returns failed but not exhausted" do
    {:ok, _} =
      Outbox.enqueue(%{msg_id: 4, payload: "z", max_attempts: 3, status: :failed, attempts: 1})

    retryable = Outbox.retryable()
    assert length(retryable) == 1
    assert hd(retryable).msg_id == 4
  end

  test "status updates return not_found for missing records" do
    assert {:error, :not_found} = Outbox.mark_sent(404)
    assert {:error, :not_found} = Outbox.mark_sent_by_id(-1)
    assert {:error, :not_found} = Outbox.mark_failed(404)
    assert {:error, :not_found} = Outbox.mark_failed_by_id(-1)
    assert {:error, :not_found} = Outbox.record_attempt_by_id(-1)
    assert {:error, :not_found} = Outbox.ack(404, "missing")
  end

  test "enqueue validates required fields" do
    assert {:error, :missing_msg_id} = Outbox.enqueue(%{payload: "hello"})
    assert {:error, :missing_payload} = Outbox.enqueue(%{msg_id: 1})
    assert {:error, :invalid_attempts} = Outbox.enqueue(%{msg_id: 1, payload: "x", attempts: -1})

    assert {:error, :invalid_max_attempts} =
             Outbox.enqueue(%{msg_id: 1, payload: "x", max_attempts: 0})
  end
end
