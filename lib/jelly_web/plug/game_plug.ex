defmodule JellyWeb.GamePlug do
  @moduledoc false
  import Plug.Conn
  import Phoenix.Controller

  def redirect_if_has_player(conn, _opts) do
    player = get_session(conn, :player)
    game_code = get_session(conn, :game_code)

    if player && game_code do
      conn
      |> redirect(to: "/game/#{game_code}")
      |> halt
    else
      conn
    end
  end

  def require_player(conn, _opts) do
    player = get_session(conn, :player)
    game_code = get_session(conn, :game_code)

    if player && game_code do
      conn
    else
      game_code = conn.params["id"] || ""

      conn
      |> redirect(to: "/?action=join&game_code=#{game_code}")
      |> halt
    end
  end

  def on_mount(:ensure_has_game_info, params, session, socket) do
    socket = mount_game(session, socket)
    game_code = socket.assigns.game_code

    # game_code != params["id"] ->
    #   socket = put_flash(socket, :error, "You are already on a game")
    #   socket = redirect(socket, to: "/?action=join&game_code=#{game_code}")
    #   {:halt, socket}

    if socket.assigns.player && game_code do
      {:cont, socket}
    else
      game_code = params["id"] || ""
      socket = redirect(socket, to: "/?action=join&game_code=#{game_code}")
      {:halt, socket}
    end
  end

  defp mount_game(session, socket) do
    Phoenix.Component.assign_new(socket, :player, fn ->
      session["player"]
    end)
    |> Phoenix.Component.assign_new(:game_code, fn ->
      session["game_code"]
    end)
  end
end
