defmodule JellyWeb.GameLiveTest do
  use JellyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jelly.Guess
  alias Jelly.Guess.Game

  setup do
    {:ok, game_code} = Guess.new()
    %{game_code: game_code}
  end

  describe "mount" do
    test "connects to existing game", ctx do
      {:ok, view, _html} = setup_game_session(ctx.conn, ctx.game_code)

      assert has_element?(view, "button", "Start")
      assert render(view) =~ "Invite your friends"
    end

    test "redirects when game does not exist", %{conn: conn} do
      assert {:error, {:redirect, %{flash: flash}}} = setup_game_session(conn, "invalid-code")

      assert flash["error"] == "Game no longer available"
    end
  end

  describe "starting game" do
    test "cannot start without at least 4 players", ctx do
      {:ok, view, _html} = setup_game_session(ctx.conn, ctx.game_code)

      view
      |> element("button", "Start")
      |> render_click()

      assert render(view) =~ "Need 4 players to start"
    end

    test "game starts with 4 players and word selection form appears", ctx do
      views =
        ctx.conn
        |> setup_four_players(ctx.game_code)

      hd(views)
      |> element("button", "Start")
      |> render_click()

      views
      |> Enum.each(fn view ->
        assert render(view) =~ "Your team is"
        assert has_element?(view, "input[name='word_1']")
        assert has_element?(view, "input[name='word_2']")
        assert has_element?(view, "input[name='word_3']")
        assert has_element?(view, "button", "Done")
      end)
    end
  end

  describe "word selection phase" do
    test "first phase starts when all players submit words", ctx do
      {[playing_view], guessing_views} =
        ctx.conn
        |> setup_four_players(ctx.game_code)
        |> start_game_and_submit_words()
        |> split_playing_and_guessing()

      Enum.each(guessing_views, fn view ->
        html = render(view)
        assert html =~ "The phase is" and html =~ "is playing"
        refute view_is_playing?(view)
      end)

      assert view_is_playing?(playing_view)
    end
  end

  describe "gameplay" do
    test "guessing a word moves to next player", ctx do
      {[playing_view], guessing_views} =
        ctx.conn
        |> setup_four_players(ctx.game_code)
        |> start_game_and_submit_words()
        |> split_playing_and_guessing()

      playing_view
      |> element("button", "Guessed")
      |> render_click()

      {[new_player_view], _rest} = split_playing_and_guessing(guessing_views)

      refute view_is_playing?(playing_view)
      assert view_is_playing?(new_player_view)
    end

    test "after guessing all words phase finishes", ctx do
      views =
        ctx.conn
        |> setup_four_players(ctx.game_code)
        |> start_game_and_submit_words()
        |> guess_all_phase_words()

      assert Enum.all?(views, fn view ->
               html = render(view)
               html =~ "Phase finished!" and has_element?(view, "button", "Continue")
             end)
    end

    test "can go to next phase", ctx do
      [view | _] =
        ctx.conn
        |> setup_four_players(ctx.game_code)
        |> start_game_and_submit_words()
        |> guess_all_phase_words()

      view
      |> element("button", "Continue")
      |> render_click()

      html = render(view)
      assert html =~ "The phase is"
    end

    test "after finishing all phases winner is shown", ctx do
      [view | _] =
        ctx.conn
        |> setup_four_players(ctx.game_code)
        |> start_game_and_submit_words()
        |> guess_all_phases()

      html = render(view)
      assert html =~ "The winner is"
    end

    test "can restart game after winner is shown", ctx do
      [view | _] =
        ctx.conn
        |> setup_four_players(ctx.game_code)
        |> start_game_and_submit_words()
        |> guess_all_phases()

      view
      |> element("button", "Restart")
      |> render_click()

      assert render(view) =~ "Invite your friends"
    end
  end

  defp setup_four_players(conn, game_code) do
    Enum.map(1..4, fn _ ->
      {:ok, view, _html} = setup_game_session(conn, game_code)
      view
    end)
  end

  defp start_game_and_submit_words(views) do
    views
    |> hd()
    |> element("button", "Start")
    |> render_click()

    for view <- views do
      view
      |> form("form", %{word_1: "word1", word_2: "word2", word_3: "word3"})
      |> render_submit()
    end

    views
  end

  defp setup_game_session(conn, game_code) do
    player = Jelly.GameFixtures.player_fixture()

    conn
    |> get(~p"/session/new", %{nickname: player.nickname, game_code: game_code})
    |> live(~p"/game/#{game_code}")
  end

  defp split_playing_and_guessing(views) do
    Enum.split_with(views, fn view ->
      view_is_playing?(view)
    end)
  end

  defp view_is_playing?(view) do
    has_element?(view, "p", "It's your turn!") and has_element?(view, "button", "Guessed")
  end

  defp guess_all_phase_words(views) do
    amount = length(views) * 3

    for _ <- 1..amount do
      {[playing_view], _guessing_views} = split_playing_and_guessing(views)

      playing_view
      |> element("button", "Guessed")
      |> render_click()
    end

    views
  end

  defp guess_all_phases(views) do
    # Complete all guessing phases (eg password, mimicry, one_password)
    phases_amount = Game.guessing_phases() |> length()

    for _ <- 1..phases_amount do
      [view | _] = guess_all_phase_words(views)

      if has_element?(view, "button", "Continue") do
        view
        |> element("button", "Continue")
        |> render_click()
      end
    end

    views
  end
end
