defmodule Jelly.Guess.Game do
  @moduledoc """
  This modules is the context responsible for dealing with the
  Guess Game functionalities
  """
  alias Jelly.Guess.Team

  @enforce_keys :code
  defstruct code: nil,
            phases: [],
            players: [],
            teams: [],
            words: [],
            sent_words: [],
            remaining_words: [],
            winner: nil

  @type t :: %__MODULE__{
          code: binary(),
          players: list(),
          phases: list(),
          teams: list(),
          words: list(),
          sent_words: list(),
          remaining_words: list(),
          winner: integer()
        }

  @guessing_phases [:password, :mimicry, :one_password]
  @setup_phases [:defining_teams, :word_selection]
  @phases @setup_phases ++ Enum.intersperse(@guessing_phases, :scores)

  def gen_code() do
    to_string(System.os_time())
  end

  def new(code) do
    %__MODULE__{code: code, phases: @phases}
  end

  def define_teams(%{phases: [:defining_teams | _]} = game, players) when length(players) >= 4 do
    index = round(length(players) / 2)

    teams =
      players
      |> Enum.map(& &1.id)
      |> Enum.shuffle()
      |> Enum.split(index)
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.map(fn {players, index} -> Team.new(index, players, @guessing_phases) end)

    %{game | teams: teams, players: players}
    |> set_next_phase()
  end

  def put_words(%{phases: [:word_selection | _]} = game, new_words, player_id)
      when length(new_words) == 3 do
    game =
      if player_id in game.sent_words do
        game
      else
        game
        |> Map.update!(:words, fn words -> new_words ++ words end)
        |> Map.update!(:sent_words, fn players -> [player_id | players] end)
      end

    maybe_complete_phase(game)
  end

  def mark_team_point(game) do
    [current_team | rest] = game.teams

    team =
      current_team
      |> Team.mark_point(current_phase(game))
      |> Team.set_next_player()

    %{game | teams: [team | rest]}
    |> set_next_word()
    |> maybe_complete_phase()
  end

  def switch_teams(game) do
    %{teams: [team_a, team_b]} = game
    %{game | teams: [team_b, team_a]}
  end

  def set_next_phase(game) do
    [current_phase | next_phases] = game.phases

    cond do
      next_phases == [] ->
        %{game | phases: next_phases}
        |> set_winner()

      current_phase == :scores ->
        %{game | phases: next_phases}

      true ->
        game = set_next_teams(game)
        %{game | phases: next_phases, remaining_words: Enum.shuffle(game.words)}
    end
  end

  defp set_next_teams(game) do
    teams =
      if current_phase(game) in @guessing_phases do
        put_loser_first(game)
        |> Enum.map(&Team.set_next_player/1)
      else
        Enum.shuffle(game.teams)
      end

    %{game | teams: teams}
  end

  defp put_loser_first(game) do
    [a, b] = game.teams
    phase = current_phase(game)
    a_points = Team.get_phase_point(a, phase)
    b_points = Team.get_phase_point(b, phase)

    cond do
      a_points > b_points -> [b, a]
      a_points == b_points -> [b, a]
      true -> [a, b]
    end
  end

  defp set_next_word(game) do
    %{game | remaining_words: List.delete_at(game.remaining_words, 0)}
  end

  defp maybe_complete_phase(game) do
    cond do
      current_phase(game) in @setup_phases && length(game.players) == length(game.sent_words) ->
        set_next_phase(game)

      current_phase(game) in @guessing_phases && game.remaining_words == [] ->
        set_next_phase(game)

      true ->
        game
    end
  end

  defp current_phase(game) do
    List.first(game.phases, [])
  end

  defp set_winner(game) do
    team =
      Enum.reduce(game.teams, nil, fn team, acc ->
        previous_team = acc || team

        if Team.get_total_points(team) > Team.get_total_points(previous_team) do
          team
        else
          previous_team
        end
      end)

    %{game | winner: team.name}
  end
end
