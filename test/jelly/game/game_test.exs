defmodule Jelly.Game.GameTest do
  use ExUnit.Case, async: true
  alias Jelly.Game

  import Jelly.GameFactory

  setup do
    %{code: Game.generate_code()}
  end

  describe "generating a new game" do
    test "generate_code/0 should return a game code" do
      code = Game.generate_code()
      assert is_binary(code)
    end

    test "new/2 should return a Game struct", %{code: code} do
      owner = build(:player)
      assert %Game{owner: ^owner} = Game.new(owner, code)
    end
  end

  describe "start/2" do
    test "should divide players into two equals teams", %{code: code} do
      players = build_list(4, :player)

      assert %{teams: [team1, team2]} =
               players
               |> List.first()
               |> Game.new(code)
               |> Game.start(players)

      assert length(team1.players) == length(team2.players)
    end

    test "should set next phase", %{code: code} do
      players = build_list(4, :player)

      game =
        %{phases: [old_phase | _]} =
        players
        |> List.first()
        |> Game.new(code)

      %{phases: [new_phase | _]} = Game.start(game, players)

      assert new_phase != old_phase
    end
  end

  describe "send_words/3" do
    test "should insert player words", %{code: code} do
      players = [player | _] = build_list(4, :player)
      words = words_list(3)

      assert %{words: ^words} =
               player
               |> Game.new(code)
               |> Game.start(players)
               |> Game.send_words(words, player.id)
    end

    test "should merge players words", %{code: code} do
      players = [player_1, player_2 | _] = build_list(4, :player)

      %{words: words} =
        player_1
        |> Game.new(code)
        |> Game.start(players)
        |> Game.send_words(words_list(3), player_1)
        |> Game.send_words(words_list(3), player_2)

      assert length(words) == 6
    end

    test "should move next phase if all players sent words", %{code: code} do
      players = [player_1 | rest] = build_list(4, :player)

      game =
        %{phases: [old_phase | _]} =
        player_1
        |> Game.new(code)
        |> Game.start(players)
        |> send_all_words(rest)

      %{phases: [new_phase | _]} = Game.send_words(game, words_list(3), player_1.id)
      assert new_phase != old_phase
    end

    test "should not update pool of words if player already sent words", %{code: code} do
      players = [player | _] = build_list(4, :player)

      game =
        %{words: words} =
        player
        |> Game.new(code)
        |> Game.start(players)
        |> Game.send_words(words_list(3), player.id)

      assert %{words: ^words} = Game.send_words(game, words_list(3), player.id)
    end
  end

  describe "mark_point/2" do
    test "should update the point of the current team in the current phase", %{code: code} do
      players = [player | _] = build_list(4, :player)

      %{phases: [current_phase | _], teams: [current_team, _]} =
        player
        |> Game.new(code)
        |> Game.start(players)
        |> send_all_words(players)
        |> Game.mark_team_point()

      assert 1 = current_team.points[current_phase]
    end

    test "should move phase if all words were guessed", %{code: code} do
      players = [player | _] = build_list(4, :player)

      game =
        %{phases: [old_phase | _]} =
        player
        |> Game.new(code)
        |> Game.start(players)
        |> send_all_words(players)
        |> make_all_words_guessed()

      %{phases: [new_phase | _]} = Game.mark_team_point(game)
      assert new_phase != old_phase
    end

    test "should put loser team first when remaining words end", %{code: code} do
      players = [player | _] = build_list(4, :player)

      game =
        %{teams: [winner_team | _]} =
        player
        |> Game.new(code)
        |> Game.start(players)
        |> send_all_words(players)
        |> make_all_words_guessed()

      %{teams: [loser_team | _]} = Game.mark_team_point(game)
      assert winner_team.name != loser_team.name
    end

    test "should switch team when remaining words end and they are tied", %{code: code} do
      players = [player | _] = build_list(4, :player)

      game =
        %{teams: [team_a | _]} =
        player
        |> Game.new(code)
        |> Game.start(players)
        |> send_all_words(players)
        # team A marks one point
        |> Game.mark_team_point()

      %{teams: [current_team | _]} =
        game
        |> Game.switch_teams()
        |> make_all_words_guessed()
        # then team B start playing and mark one point
        |> Game.mark_team_point()

      # the phase ends and they are tied, so as team B were playing team A is
      # the current team

      assert team_a.name == current_team.name
    end

    test "should not switch team when remaining words end and current team is the loser", %{
      code: code
    } do
      players = [player | _] = build_list(4, :player)

      game =
        %{teams: [_team_a | [team_b]]} =
        player
        |> Game.new(code)
        |> Game.start(players)
        |> send_all_words(players)
        # team a marks 2 points
        |> Game.mark_team_point()
        |> Game.mark_team_point()

      %{teams: [current_team | _]} =
        game
        |> Game.switch_teams()
        # now team b is playing
        |> make_all_words_guessed()
        |> Game.mark_team_point()

      # team b marks 1 point but the phase ends because there is no words
      # remaining, team b have less points so still the current team playing

      assert team_b.name == current_team.name
    end

    test "should have winner when finish phases", %{code: code} do
      players = [player | _] = build_list(4, :player)

      game =
        %{teams: [%{name: team_name} | _]} =
        player
        |> Game.new(code)
        |> Game.start(players)
        |> send_all_words(players)
        |> Game.mark_team_point()
        # start next phase
        |> Game.set_next_phase()
        |> make_all_words_guessed()
        |> Game.mark_team_point()
        # start next phase
        |> Game.set_next_phase()
        |> make_all_words_guessed()
        |> Game.mark_team_point()
        # start next phase
        |> Game.set_next_phase()
        |> make_all_words_guessed()

      assert %{winner: ^team_name, phases: []} = Game.mark_team_point(game)
    end

    test "the team that didnt the last point can win", %{code: code} do
      players = [player | _] = build_list(4, :player)

      game =
        %{teams: [_team_a | [%{name: team_b}]]} =
        player
        |> Game.new(code)
        |> Game.start(players)
        |> send_all_words(players)
        |> make_all_words_guessed()
        # team a do 1 point
        |> Game.mark_team_point()
        # start next phase
        |> Game.set_next_phase()
        # team b do 3 points
        |> Game.mark_team_point()
        |> Game.mark_team_point()
        |> make_all_words_guessed()
        |> Game.mark_team_point()
        # start next phase
        |> Game.set_next_phase()
        |> make_all_words_guessed()

      # team a do 1 point
      assert %{winner: ^team_b, phases: []} = Game.mark_team_point(game)
    end
  end

  describe "switch_team/1" do
    test "should switch the current team", %{code: code} do
      players = [player | _] = build_list(4, :player)

      game =
        %{teams: [team_a, team_b]} =
        player
        |> Game.new(code)
        |> Game.start(players)
        |> send_all_words(players)

      assert %{teams: [^team_b, ^team_a]} = Game.switch_teams(game)
    end
  end

  defp send_all_words(game, players) do
    Enum.reduce(players, game, fn player, game ->
      Game.send_words(game, words_list(3), player.id)
    end)
  end

  defp make_all_words_guessed(game) do
    Map.update!(game, :remaining_words, fn _ -> words_list(1) end)
  end
end
