defmodule Jelly.Guess.TeamTest do
  use ExUnit.Case
  import Jelly.GameFactory

  alias Jelly.Game.Team

  test "should return a new team" do
    players = build_list(4, :player)

    assert %{players: ^players, remaining_players: ^players, name: "name"} =
             Team.new("name", players, [])
  end

  test "should update team points in the given phase" do
    players = build_list(4, :player)
    team = Team.new("name", players, [:password])
    assert team = %{points: [password: 1]} = Team.mark_point(team, :password)
    assert team = %{points: [password: 2]} = Team.mark_point(team, :password)
    assert %{points: [password: 2, mimicry: 1]} = Team.mark_point(team, :mimicry)
  end

  test "should set next current player" do
    players = build_list(2, :player)

    %{remaining_players: remaining_players} =
      Team.new("name", players, [])
      |> Team.set_next_player()

    assert length(remaining_players) == 1
  end

  test "should reassign players when remaining players end" do
    players = build_list(2, :player)

    %{remaining_players: remaining_players} =
      Team.new("name", players, [])
      |> Team.set_next_player()
      |> Team.set_next_player()

    assert length(remaining_players) == 2
  end

  test "should return phase point value" do
    players = build_list(4, :player)

    assert 1 =
             Team.new("name", players, [:password])
             |> Team.mark_point(:password)
             |> Team.get_phase_point(:password)
  end

  test "should return team total points" do
    players = build_list(4, :player)

    assert 3 =
             Team.new("name", players, [:password])
             |> Team.mark_point(:password)
             |> Team.mark_point(:mimicry)
             |> Team.mark_point(:one_password)
             |> Team.get_total_points()
  end
end
