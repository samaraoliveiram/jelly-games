defmodule Jelly.GameFixtures do
  alias Jelly.Guess.Player

  def player_fixture do
    Player.new("user#{System.unique_integer()}")
  end

  def words_fixture(amount) do
    Enum.map(1..amount, fn idx -> "word#{idx}" end)
  end
end
