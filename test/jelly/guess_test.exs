defmodule Jelly.GuessTest do
  use ExUnit.Case
  import Jelly.GuessFactory

  alias Jelly.Guess

  test "new/0 should return the game code of the server" do
    assert {:ok, _game_code} = Guess.new()
  end

  describe "get/1" do
    test "should return the game pid if exists" do
      {:ok, game_code} = Guess.new()
      assert {:ok, _pid} = Guess.get(game_code)
    end

    test "should return :not_found if the game doesn't exist" do
      assert {:error, :not_found} = Guess.get("some_code")
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
      Guess.subscribe(game_code)

      assert {:ok, %{teams: [_ | _]}} = Guess.define_teams(game_code, players)
      assert_received {:game_updated, %{teams: [_ | _]}}
    end
  end

  describe "put_words/3" do
    test "should return error if words < 3" do
      players = [player | _] = build_list(4, :player)
      words = words_list(2)

      {:ok, game_code} = Guess.new()
      Guess.define_teams(game_code, players)

      assert {:error, :not_enough_words} = Guess.put_words(game_code, words, player.id)
    end

    test "should return an updated state " do
      players = [player | _] = build_list(4, :player)
      words = words_list(3)

      {:ok, game_code} = Guess.new()
      Guess.define_teams(game_code, players)

      assert {:ok, _} = Guess.put_words(game_code, words, player.id)
    end

    test "should broadcast game updated every time player sent words" do
      players = build_list(4, :player)
      {:ok, game_code} = Guess.new()
      Guess.subscribe(game_code)
      {:ok, %{current_phase: old_phase}} = Guess.define_teams(game_code, players)
      put_words(game_code, players)

      # stat game event
      assert_received {:game_updated, _}

      assert_received {:game_updated, %{current_phase: ^old_phase, sent_words: sent_words}}
      assert length(sent_words) == 1
      assert_received {:game_updated, %{current_phase: ^old_phase, sent_words: sent_words}}
      assert length(sent_words) == 2
      assert_received {:game_updated, %{current_phase: ^old_phase, sent_words: sent_words}}
      assert length(sent_words) == 3
      assert_received {:game_updated, %{current_phase: :password, sent_words: sent_words}}
      assert length(sent_words) == 4
    end

    test "should move phase when all words are filled" do
      players = build_list(4, :player)
      {:ok, game_code} = Guess.new()
      Guess.subscribe(game_code)
      {:ok, %{current_phase: old_phase}} = Guess.define_teams(game_code, players)
      put_words(game_code, players)

      assert_received {:game_updated, %{current_phase: ^old_phase}}
      assert_received {:game_updated, %{current_phase: :password}}
    end
  end

  describe "mark_point/1 " do
    test "should return an updated state with the team points" do
      players = build_list(4, :player)
      {:ok, game_code} = Guess.new()
      Guess.subscribe(game_code)
      Guess.define_teams(game_code, players)
      put_words(game_code, players)
      Guess.mark_point(game_code)

      assert_received {:game_updated, _}
      assert_received {:game_updated, _}
      assert_received {:game_updated, _}
      assert_received {:game_updated, _}
      assert_received {:game_updated, _}
      assert_received {:game_updated, %{teams: [%{points: points} | _]}}
      assert Keyword.values(points) |> Enum.sum() == 1
    end

    test "when end pool of words should cancel timer" do
      players = build_list(4, :player)
      {:ok, game_code} = Guess.new()
      Guess.subscribe(game_code)
      Guess.define_teams(game_code, players)
      put_words(game_code, players)
      Enum.each(1..12, fn _ -> Guess.mark_point(game_code) end)

      assert_received {:timer, 0}
      assert_received {:game_updated, _}
    end

    test "when have winner should cancel timer and broadcast end_game" do
      players = build_list(4, :player)
      {:ok, game_code} = Guess.new()
      Guess.subscribe(game_code)
      Guess.define_teams(game_code, players)
      put_words(game_code, players)
      Enum.each(1..12, fn _ -> Guess.mark_point(game_code) end)
      Guess.next_phase(game_code)
      Enum.each(1..12, fn _ -> Guess.mark_point(game_code) end)
      Guess.next_phase(game_code)
      Enum.each(1..11, fn _ -> Guess.mark_point(game_code) end)

      assert {:ok, %{winner: winner}} = Guess.mark_point(game_code)
      assert winner
      assert_received {:game_updated, _}
    end
  end

  describe "restart/1" do
    test "should send a new empty state" do
      players = build_list(4, :player)
      {:ok, game_code} = Guess.new()
      Guess.subscribe(game_code)
      Guess.define_teams(game_code, players)
      {:ok, old_state} = Guess.get(game_code)
      {:ok, empty_state} = Guess.restart(game_code)

      assert old_state != empty_state
      assert %{teams: [], winner: nil} = empty_state
    end
  end

  describe "switch_team/1" do
    test "should broadcast an updated state with a differente current team playing" do
      players = build_list(4, :player)
      {:ok, game_code} = Guess.new()
      Guess.subscribe(game_code)
      Guess.define_teams(game_code, players)

      Guess.switch_team(game_code)
      assert_receive {:game_updated, %{current_team: previous_team}}
      assert_receive {:game_updated, %{current_team: next_team}}
      assert previous_team != next_team
    end
  end

  describe "backup test" do
    test "should restore state after server crash" do
      Process.flag(:trap_exit, true)
      game_code = "game_code"

      {:ok, pid} = Guess.start_link(game_code)

      Guess.define_teams(game_code, build_list(4, :player))
      Process.exit(pid, :kaboom)

      assert_receive {:EXIT, ^pid, :kaboom}

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

  defp put_words(game_code, players) do
    Enum.each(players, fn player ->
      Guess.put_words(game_code, words_list(3), player.id)
    end)
  end
end
