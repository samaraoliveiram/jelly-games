defmodule Jelly.GameFixtures do
  alias Jelly.Guess.Player

  def player_fixture do
    Player.new("user#{System.unique_integer()}")
  end

  def words_fixture(amount) do
    Enum.map(1..amount, fn idx -> "word#{idx}" end)
  end

  def build_list(amount, fixture_name, attributes \\ []) do
    if is_integer(amount) && amount > 0 do
      Enum.map(1..amount, fn _ -> apply(__MODULE__, fixture_name, attributes) end)
    else
      raise "expected build amount to be a non negative integer"
    end
  end
end
