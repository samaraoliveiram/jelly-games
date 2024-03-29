defmodule Jelly.GuessFactory do
  @moduledoc false

  use ExMachina

  alias Jelly.Guess.Player

  def player_factory do
    Player.new(sequence("nickname"))
  end

  def words_list(number) do
    Enum.map(1..number, fn _ -> sequence("word") end)
  end
end
