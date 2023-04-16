defmodule Jelly.Guess.Team do
  @moduledoc false

  alias Jelly.Guess.Player

  @enforce_keys :name
  defstruct players: [], remaining_players: [], points: [], name: nil

  @type t :: %__MODULE__{
          players: list(),
          remaining_players: list(),
          points: list(),
          name: binary()
        }

  @spec new([Player.t()], binary(), list()) :: t()
  def new(name, players, phases) do
    %__MODULE__{
      players: players,
      remaining_players: players,
      name: name,
      points: Keyword.new(phases, &{&1, 0})
    }
  end

  def mark_point(team, phase) do
    %{team | points: Keyword.update(team.points, phase, 1, &(&1 + 1))}
  end

  def set_next_player(team) do
    players =
      case List.delete_at(team.remaining_players, 0) do
        [] -> team.players
        players -> players
      end

    %{team | remaining_players: players}
  end

  def get_phase_point(team, phase) do
    Keyword.get(team.points, phase)
  end

  def get_total_points(team) do
    Keyword.values(team.points)
    |> Enum.sum()
  end
end
