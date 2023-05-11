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

  describe "put_words/3" do
    test "should insert player words" do
      players = [player | _] = build_list(4, :player)
      words = words_list(3)

      assert %{words: ^words} =
               Game.new(gen_game_code())
               |> Game.define_teams(players)
               |> Game.put_words(words, player.id)
    end

    test "should merge players words" do
      players = [player_1, player_2 | _] = build_list(4, :player)

      %{words: words} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> Game.put_words(words_list(3), player_1)
        |> Game.put_words(words_list(3), player_2)

      assert length(words) == 6
    end

    test "should move next phase if all players sent words" do
      players = [player_1 | rest] = build_list(4, :player)

      game =
        %{phases: [old_phase | _]} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> put_words(rest)

      %{phases: [new_phase | _]} = Game.put_words(game, words_list(3), player_1.id)
      assert new_phase != old_phase
    end

    test "should not update pool of words if player already sent words" do
      players = [player | _] = build_list(4, :player)

      game =
        %{words: words} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> Game.put_words(words_list(3), player.id)

      assert %{words: ^words} = Game.put_words(game, words_list(3), player.id)
    end
  end

  describe "mark_point/2" do
    test "should update the point of the current team in the current phase" do
      players = build_list(4, :player)

      %{phases: [current_phase | _], teams: [current_team, _]} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> put_words(players)
        |> Game.mark_team_point()

      assert 1 = current_team.points[current_phase]
    end

    test "should move phase if all words were guessed" do
      players = build_list(4, :player)

      game =
        %{phases: [old_phase | _]} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> put_words(players)
        |> Map.update!(:remaining_words, fn _ -> words_list(1) end)

      %{phases: [new_phase | _]} = Game.mark_team_point(game)
      assert new_phase != old_phase
    end

    test "should put loser team first when remaining words end" do
      players = build_list(4, :player)

      game =
        %{teams: [winner_team | _]} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> put_words(players)
        |> Map.update!(:remaining_words, fn _ -> words_list(1) end)

      %{teams: [loser_team | _]} = Game.mark_team_point(game)
      assert winner_team.name != loser_team.name
    end

    test "should switch team when remaining words end and they are tied" do
      players = build_list(4, :player)

      game =
        %{teams: [team_a | _]} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> put_words(players)
        |> Game.mark_team_point()

      # team A marks one point

      %{teams: [current_team | _]} =
        game
        |> Game.switch_teams()
        # then team B start playing
        |> Map.update!(:remaining_words, fn _ -> words_list(1) end)
        |> Game.mark_team_point()

      # team B marks one point but the phase ends and they are tied, so as team
      # B were playing team A is the current team

      assert team_a.name == current_team.name
    end

    test "should not switch team when remaining words end and current team is the loser" do
      players = build_list(4, :player)

      game =
        %{teams: [_team_a | [team_b]]} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> put_words(players)
        |> Game.mark_team_point()
        |> Game.mark_team_point()

      # team a marks 2 points

      %{teams: [current_team | _]} =
        game
        |> Game.switch_teams()
        # now team b is playing
        |> Map.update!(:remaining_words, fn _ -> words_list(1) end)
        |> Game.mark_team_point()

      # team b marks 1 point but the phase ends because there is no words
      # remaining, team b have less point so still the current team playing

      assert team_b.name == current_team.name
    end

    test "should have winner when finish phases" do
      players = build_list(4, :player)

      game =
        %{teams: [%{name: team_name} | _]} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> put_words(players)

      game =
        Map.update!(game, :remaining_words, fn _ -> words_list(1) end)
        |> Game.mark_team_point()
        |> Game.set_next_phase()
        |> Map.update!(:remaining_words, fn _ -> words_list(1) end)
        |> Game.mark_team_point()
        |> Game.set_next_phase()
        |> Map.update!(:remaining_words, fn _ -> words_list(1) end)

      assert %{winner: ^team_name, phases: []} = Game.mark_team_point(game)
    end

    test "the team that didnt the last point can win" do
      players = build_list(4, :player)

      game =
        %{teams: [_ | [%{name: team_name}]]} =
        Game.new(gen_game_code())
        |> Game.define_teams(players)
        |> put_words(players)
        |> Game.switch_teams()
        |> Map.update!(:remaining_words, fn _ -> words_list(1) end)
        |> Game.mark_team_point()
        |> Game.set_next_phase()
        |> Map.update!(:remaining_words, fn _ -> words_list(1) end)
        |> Game.switch_teams()
        |> Game.mark_team_point()
        |> Game.set_next_phase()
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
        |> put_words(players)

      assert %{teams: [^team_b, ^team_a]} = Game.switch_teams(game)
    end
  end

  defp gen_game_code do
    to_string(System.os_time())
  end

  defp put_words(game, players) do
    Enum.reduce(players, game, fn player, game ->
      Game.put_words(game, words_list(3), player.id)
    end)
  end
end
