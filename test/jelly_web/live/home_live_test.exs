defmodule JellyWeb.HomeLiveTest do
  use JellyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jelly.Guess

  describe "/" do
    test "renders new and join links", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, ~s'[href="/new"]', "New")
      assert has_element?(view, ~s'[href="/join"]', "Join")
    end

    test "renders form when selecting new game", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> element(~s'[href="/new"]')
      |> render_click()

      assert_patch(view, ~p"/new")

      assert has_element?(view, "form")
      assert has_element?(view, "input[name=nickname]")
      refute has_element?(view, "input[name=game_code]")
      assert has_element?(view, "button", "New")
    end

    test "renders form for join game", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> element(~s'[href="/join"]')
      |> render_click()

      assert_patch(view, ~p"/join")

      assert has_element?(view, "form")
      assert has_element?(view, "input[name=nickname]")
      assert has_element?(view, "input[name=game_code]")
      assert has_element?(view, "button", "Join")
    end

    test "back button returns to index", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/new")

      view
      |> element("button", "Back")
      |> render_click()

      assert_patch(view, ~p"/")

      {:ok, view, _html} = live(conn, "/join")

      view
      |> element("button", "Back")
      |> render_click()

      assert_patch(view, ~p"/")
      refute has_element?(view, "button", "Back")
    end
  end

  describe "new game" do
    test "successfully creates a new game", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/new")

      view
      |> form("form", %{nickname: "test"})
      |> render_submit()

      {path, _flash} = assert_redirect view
      assert path =~ ~r"/session/new"
    end

    test "renders form errors when invalid input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/new")

      view
      |> form("form")
      |> render_change(%{nickname: "a"})

      assert has_element?(view, "p", "should be at least 3 character(s)")
    end
  end

  describe "join game" do
    test "successfully joins a game", %{conn: conn} do
      {:ok, game_code} = Guess.new()
      {:ok, view, _html} = live(conn, "/join")

      view
      |> form("form", %{nickname: "test", game_code: game_code})
      |> render_submit()

      {path, _flash} = assert_redirect view
      assert path =~ ~r"/session/new"
    end

    test "renders form errors when invalid input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/join")

      view
      |> form("form")
      |> render_change(%{nickname: "a"})

      assert has_element?(view, "p", "should be at least 3 character(s)")
    end

    test "shows error when joining a non-existent game", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/join")

      view
      |> form("form", %{nickname: "test", game_code: "non-existent"})
      |> render_submit()

      assert render(view) =~ "Game not found"
    end
  end
end
