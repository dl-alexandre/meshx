defmodule MeshxRuntime.OutboxTest do
  use ExUnit.Case, async: true

  alias MeshxRuntime.Outbox

  @interval 30_000
  @max_backoff 300_000

  describe "retry_interval_for/3 (exponential backoff + equal jitter, bounded)" do
    test "jittered result stays within [capped/2, capped] for every attempt" do
      for attempt <- 0..8 do
        capped = min(@interval * 2 ** attempt, @max_backoff)
        floor = div(capped, 2)

        for _ <- 1..200 do
          ms = Outbox.retry_interval_for(attempt, @interval, @max_backoff)
          assert ms >= floor, "attempt #{attempt}: #{ms} < floor #{floor}"
          assert ms <= capped, "attempt #{attempt}: #{ms} > capped #{capped}"
        end
      end
    end

    test "backoff grows exponentially until the cap" do
      assert Outbox.retry_interval_for(0, @interval, @max_backoff) <= @interval
      # attempt 0 cap 30s, 1 -> 60s, 2 -> 120s, 3 -> 240s, 4+ -> capped 300s
      assert Outbox.retry_interval_for(3, @interval, @max_backoff) > @interval
    end

    test "never exceeds max_backoff, even for large attempts" do
      for attempt <- [4, 8, 20, 50] do
        assert Outbox.retry_interval_for(attempt, @interval, @max_backoff) <= @max_backoff
      end
    end

    test "jitter actually varies the delay (not constant)" do
      samples =
        for _ <- 1..50, do: Outbox.retry_interval_for(2, @interval, @max_backoff)

      assert length(Enum.uniq(samples)) > 1
    end
  end
end
