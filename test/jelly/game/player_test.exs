defmodule Jelly.Game.PlayerTest do
  use ExUnit.Case
  alias Jelly.Game.Player

  test "returns a valid player" do
    nickname = "nickname"
    assert %Player{nickname: ^nickname} = Player.new(nickname)
  end
end
