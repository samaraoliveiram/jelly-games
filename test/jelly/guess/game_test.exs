defmodule Jelly.Guess.GameTest do
  use ExUnit.Case
  alias Jelly.Guess.Game

  import Jelly.GuessFactory

  test "new/0 should return a Game struct" do
    assert %Game{} = Game.new(gen_game_code())
  end

  describe "define_teams/2" do
    test "should divide players into two equals teams" do
      game = Game.new(gen_game_code())
      players = build_list(4, :player)
      assert %{teams: [team1, team2]} = Game.define_teams(game, players)
      assert length(team1.players) == length(team2.players)
    end

    test "should set next phase" do
      players = build_list(4, :player)
      game = %{phases: [old_phase | _]} = Game.new(gen_game_code())
      %{phases: [new_phase | _]} = Game.define_teams(game, players)

      assert new_phase != old_phase
    end
  end

  describe "put_words/2" do
    test "should insert player words" do
      players = build_list(4, :player)
      words = words_list(3)

      assert %{words: ^words} =
               Game.new(gen_game_code())
               |> Game.define_teams(players)
               |> Game.put_words(words)
    end

    test "should merge players words" do
      players = build_list(4, :player)

      %{words: words} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> Game.put_words(words_list(3))
        |> Game.put_words(words_list(3))

      assert length(words) == 6
    end

    test "should move next phase if enough words" do
      players = build_list(4, :player)

      game =
        %{phases: [old_phase | _]} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> Game.put_words(words_list(6))

      %{phases: [new_phase | _]} = Game.put_words(game, words_list(6))
      assert new_phase != old_phase
    end
  end

  describe "mark_point/2" do
    test "should update the point of the current team in the current phase" do
      players = build_list(4, :player)

      %{phases: [current_phase | _], teams: [current_team, _]} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> Game.put_words(words_list(12))
        |> Game.mark_team_point()

      assert 1 = current_team.points[current_phase]
    end

    test "should move phase if all words were guessed" do
      players = build_list(4, :player)

      game =
        %{phases: [old_phase | _]} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> Game.put_words(words_list(12))
        |> Map.update!(:remaining_words, fn _ -> words_list(1) end)

      %{phases: [new_phase | _]} = Game.mark_team_point(game)
      assert new_phase != old_phase
    end

    test "should put loser team first when words end" do
      players = build_list(4, :player)

      game =
        %{teams: [winner_team | _]} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> Game.put_words(words_list(12))
        |> Map.update!(:remaining_words, fn _ -> words_list(1) end)

      %{teams: [loser_team | _]} = Game.mark_team_point(game)
      assert winner_team.name != loser_team.name
    end

    test "should switch team when words end and they are tied" do
      players = build_list(4, :player)

      game =
        %{teams: [team_a | _]} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> Game.put_words(words_list(12))
        |> Game.mark_team_point()
        |> Game.switch_teams()
        |> Map.update!(:remaining_words, fn _ -> words_list(1) end)

      %{teams: [team_b | _]} = Game.mark_team_point(game) |> IO.inspect()
      assert team_a.name != team_b.name
    end

    test "should end game if finish phases" do
      players = build_list(4, :player)

      game =
        %{teams: [%{name: team_name} | _]} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> Game.put_words(words_list(12))

      game =
        Map.update!(game, :remaining_words, fn _ -> words_list(1) end)
        |> Game.mark_team_point()
        |> Map.update!(:remaining_words, fn _ -> words_list(1) end)
        |> Game.mark_team_point()
        |> Map.update!(:remaining_words, fn _ -> words_list(1) end)

      assert %{winner: ^team_name, phases: []} = Game.mark_team_point(game)
    end
  end

  describe "switch_team/1" do
    test "should switch the current team" do
      players = build_list(4, :player)

      game =
        %{teams: [team_a, team_b]} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> Game.put_words(words_list(12))

      assert %{teams: [^team_b, ^team_a]} = Game.switch_teams(game)
    end
  end

  defp gen_game_code do
    to_string(System.os_time())
  end
end
