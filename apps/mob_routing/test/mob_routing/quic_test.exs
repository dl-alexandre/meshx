defmodule Mob.Routing.QUICTest do
  use ExUnit.Case

  alias Mob.Routing.QUIC

  test "reports optional quicer availability" do
    assert is_boolean(QUIC.available?())
  end

  test "returns an explicit error when quicer is not installed" do
    if QUIC.available?() do
      assert true
    else
      assert {:error, :quic_not_available} = QUIC.start_link(id: "q")
    end
  end
end
