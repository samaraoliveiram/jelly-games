defmodule Jelly.GameServerTest do
  use ExUnit.Case
  import Jelly.GameFactory

  alias Jelly.GameServer
  @min_amount_of_players 4

  test "new/0 should return the game code of the server" do
    assert {:ok, _game_code} = build(:player) |> GameServer.new()
  end

  describe "get/1" do
    test "should return the game pid if exists" do
      {:ok, game_code} = build(:player) |> GameServer.new()
      assert {:ok, _pid} = GameServer.get(game_code)
    end

    test "should return :not_found if the game doesn't exist" do
      assert {:error, :not_found} = GameServer.get("some_code")
    end
  end

  describe "start/2" do
    test "should return error if players < 4" do
      players = [player | _] = build_list(3, :player)

      {:ok, game_code} = GameServer.new(player)

      assert {:error, :not_enough_players} = GameServer.start(game_code, players)
    end

    test "should return an updated state with defined teams" do
      players = [player | _] = build_list(4, :player)

      {:ok, game_code} = GameServer.new(player)
      GameServer.subscribe(game_code)

      assert {:ok, %{teams: [_ | _]}} = GameServer.start(game_code, players)
      assert_received {:game_updated, %{teams: [_ | _]}}
    end
  end

  describe "send_words/3" do
    test "should return error if words < 3" do
      players = [player | _] = build_list(@min_amount_of_players, :player)
      words = words_list(2)

      {:ok, game_code} = GameServer.new(player)
      GameServer.start(game_code, players)

      assert {:error, :not_enough_words} = GameServer.send_words(game_code, words, player.id)
    end

    test "should return an updated state with words sent" do
      players = [%{id: player_id} = player | _] = build_list(@min_amount_of_players, :player)
      words = words_list(3)

      {:ok, game_code} = GameServer.new(player)
      GameServer.subscribe(game_code)
      GameServer.start(game_code, players)

      assert {:ok, %{sent_words: [^player_id]}} =
               GameServer.send_words(game_code, words, player_id)

      assert_received {:game_updated, %{sent_words: [^player_id]}}
    end

    test "should move phase when all words are filled" do
      players = [player | _] = build_list(@min_amount_of_players, :player)

      {:ok, game_code} = GameServer.new(player)
      GameServer.subscribe(game_code)
      {:ok, %{current_phase: old_phase}} = GameServer.start(game_code, players)
      send_words_for_each_player(game_code, players)

      for _ <- 0..3 do
        assert_received {:game_updated, _}
      end

      assert_received {:timer, _}
      assert_received {:game_updated, %{current_phase: new_phase}}
      assert old_phase != new_phase
    end
  end

  describe "mark_point/1 " do
    test "should return an updated state with the team points" do
      players = [player | _] = build_list(@min_amount_of_players, :player)
      {:ok, game_code} = GameServer.new(player)
      GameServer.subscribe(game_code)
      GameServer.start(game_code, players)
      send_words_for_each_player(game_code, players)
      GameServer.mark_point(game_code)

      for _ <- 0..@min_amount_of_players do
        assert_received {:game_updated, _}
      end

      assert_received {:game_updated, %{teams: [%{points: points} | _]}}
      assert Keyword.values(points) |> Enum.sum() == 1
    end

    test "when end pool of words should cancel timer" do
      players = [player | _] = build_list(@min_amount_of_players, :player)
      {:ok, game_code} = GameServer.new(player)
      GameServer.subscribe(game_code)
      GameServer.start(game_code, players)
      send_words_for_each_player(game_code, players)
      Enum.each(1..12, fn _ -> GameServer.mark_point(game_code) end)

      assert_received {:timer, 0}
      assert_received {:game_updated, _}
    end

    test "when have winner should cancel timer and broadcast end_game" do
      players = [player | _] = build_list(@min_amount_of_players, :player)
      {:ok, game_code} = GameServer.new(player)
      GameServer.subscribe(game_code)
      GameServer.start(game_code, players)
      send_words_for_each_player(game_code, players)
      Enum.each(1..12, fn _ -> GameServer.mark_point(game_code) end)
      GameServer.next_phase(game_code)
      Enum.each(1..12, fn _ -> GameServer.mark_point(game_code) end)
      GameServer.next_phase(game_code)
      Enum.each(1..11, fn _ -> GameServer.mark_point(game_code) end)

      assert {:ok, %{winner: winner}} = GameServer.mark_point(game_code)
      assert winner
      assert_received {:game_updated, _}
    end
  end

  describe "restart/1" do
    test "should send a new empty state" do
      players = [player | _] = build_list(@min_amount_of_players, :player)
      {:ok, game_code} = GameServer.new(player)
      GameServer.subscribe(game_code)
      GameServer.start(game_code, players)
      {:ok, old_state} = GameServer.get(game_code)
      {:ok, empty_state} = GameServer.restart(game_code)

      assert old_state != empty_state
      assert %{teams: [], winner: nil} = empty_state
    end
  end

  describe "switch_team/1" do
    test "should broadcast an updated state with a differente current team playing" do
      players = [player | _] = build_list(@min_amount_of_players, :player)
      {:ok, game_code} = GameServer.new(player)
      GameServer.subscribe(game_code)
      GameServer.start(game_code, players)

      GameServer.switch_team(game_code)
      assert_receive {:game_updated, %{current_team: previous_team}}
      assert_receive {:game_updated, %{current_team: next_team}}
      assert previous_team != next_team
    end
  end

  describe "backup test" do
    test "should restore state after server crash" do
      Process.flag(:trap_exit, true)
      players = [player | _] = build_list(@min_amount_of_players, :player)
      game_code = "game_code"

      {:ok, pid} = GameServer.start_link(game_code, player)

      GameServer.start(game_code, players)
      Process.exit(pid, :kaboom)

      assert_receive {:EXIT, ^pid, :kaboom}

      {:ok, pid} = GameServer.start_link(game_code, player)
      assert hd(:sys.get_state(pid).phases) == :word_selection
    end

    test "should not restore state after a timeout" do
      Process.flag(:trap_exit, true)
      players = [player | _] = build_list(@min_amount_of_players, :player)
      game_code = "game_code_2"

      {:ok, pid} = GameServer.start_link(game_code, player)
      Process.monitor(pid)

      GameServer.start(game_code, players)
      send(pid, :timeout)
      assert_receive {:DOWN, _, _, ^pid, _}

      {:ok, pid} = GameServer.start_link(game_code, player)
      assert hd(:sys.get_state(pid).phases) == :defining_teams
    end
  end

  defp send_words_for_each_player(game_code, players) do
    Enum.each(players, fn player -> GameServer.send_words(game_code, words_list(3), player.id) end)
  end
end
