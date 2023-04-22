defmodule Jelly.Game.PlayerTest do
  use ExUnit.Case
  alias Jelly.Guess.Player

  test "returns a valid player" do
    nickname = "nickname"
    assert %Player{nickname: ^nickname} = Player.new(nickname)
  end
end
