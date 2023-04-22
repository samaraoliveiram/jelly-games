defmodule Jelly.GuessTest do
  use ExUnit.Case
  import Jelly.GuessFactory

  alias Jelly.Guess

  test "new/0 should return the game code of the server" do
    assert {:ok, _game_code} = Guess.new()
  end

  describe "join/1" do
    test "should return the game pid if exists" do
      {:ok, game_code} = Guess.new()
      assert {:ok, _pid} = Guess.join(game_code)
    end

    test "should return :not_found if the game doesn't exist" do
      assert {:error, :not_found} = Guess.join("some_code")
    end
  end

  describe "define_teams/2" do
    test "should return error if players < 4" do
      players = build_list(3, :player)

      {:ok, game_code} = Guess.new()

      assert {:error, :not_enough_players} = Guess.define_teams(game_code, players)
    end

    test "should return an updated state with defined teams" do
      players = build_list(4, :player)

      {:ok, game_code} = Guess.new()

      assert {:ok, %{teams: [_ | _]}} = Guess.define_teams(game_code, players)
      assert_receive {:move_phase, %{teams: [_ | _]}}
    end
  end

  describe "put_words/2" do
    test "should return error if words < 3" do
      players = build_list(4, :player)
      words = words_list(2)

      {:ok, game_code} = Guess.new()
      Guess.define_teams(game_code, players)

      assert {:error, :not_enough_words} = Guess.put_words(game_code, words)
    end

    test "should return an updated state " do
      players = build_list(4, :player)
      words = words_list(3)

      {:ok, game_code} = Guess.new()
      Guess.define_teams(game_code, players)

      assert {:ok, _} = Guess.put_words(game_code, words)
    end

    test "should move phase when all words are filled" do
      players = build_list(4, :player)
      words = words_list(12)

      {:ok, game_code} = Guess.new()
      Guess.define_teams(game_code, players)

      assert {:ok, _} = Guess.put_words(game_code, words)
      assert_receive {:move_phase, _}
    end
  end

  describe "mark_point/1 " do
    test "should return an updated state with the team points" do
      players = build_list(4, :player)
      {:ok, game_code} = Guess.new()
      Guess.define_teams(game_code, players)
      Guess.put_words(game_code, words_list(12))

      assert {:ok, %{teams: [%{points: points} | _]}} = Guess.mark_point(game_code)
      assert Keyword.values(points) |> Enum.sum() == 1
      assert_receive {:mark_point, _}
    end

    test "when different phase should cancel timer and broadcast move_phase" do
      players = build_list(4, :player)
      {:ok, game_code} = Guess.new()
      Guess.define_teams(game_code, players)
      Guess.put_words(game_code, words_list(12))
      Enum.each(1..12, fn _ -> Guess.mark_point(game_code) end)

      assert_receive {:mark_point, _}
      assert_receive {:timer, 0}
      assert_receive {:move_phase, _}
    end

    test "when have winner should cancel timer and broadcast end_game" do
      players = build_list(4, :player)
      {:ok, game_code} = Guess.new()
      Guess.define_teams(game_code, players)
      Guess.put_words(game_code, words_list(12))
      Enum.each(1..12, fn _ -> Guess.mark_point(game_code) end)
      Enum.each(1..12, fn _ -> Guess.mark_point(game_code) end)
      Enum.each(1..11, fn _ -> Guess.mark_point(game_code) end)

      assert {:ok, %{winner: winner}} = Guess.mark_point(game_code)
      assert winner
      assert_receive {:mark_point, _}
      assert_receive {:timer, 0}
      assert_receive {:end_game, _}
    end
  end

  describe "switch_team/1" do
    test "should return an updated state with a differente current team playing" do
      players = build_list(4, :player)
      {:ok, game_code} = Guess.new()
      Guess.define_teams(game_code, players)
      {:ok, %{current_team: previous_team}} = Guess.put_words(game_code, words_list(12))

      assert {:ok, %{current_team: next_team}} = Guess.switch_team(game_code)
      assert previous_team != next_team
      assert_receive {:switch_team, _}
      assert_receive {:timer, _}
    end
  end

  describe "backup test" do
    test "should restore state after server crash" do
      Process.flag(:trap_exit, true)
      game_code = "game_code"

      {:ok, pid} = Guess.start_link(game_code)
      Process.monitor(pid)

      Guess.define_teams(game_code, build_list(4, :player))
      Process.exit(pid, :kaboom)

      assert_receive {:DOWN, _, _, ^pid, _}

      {:ok, pid} = Guess.start_link(game_code)
      assert hd(:sys.get_state(pid).phases) == :word_selection
    end

    test "should not restore state after a timeout" do
      Process.flag(:trap_exit, true)
      game_code = "game_code_2"

      {:ok, pid} = Guess.start_link(game_code)
      Process.monitor(pid)

      Guess.define_teams(game_code, build_list(4, :player))
      send(pid, :timeout)
      assert_receive {:DOWN, _, _, ^pid, _}

      {:ok, pid} = Guess.start_link(game_code)
      assert hd(:sys.get_state(pid).phases) == :defining_teams
    end
  end
end
