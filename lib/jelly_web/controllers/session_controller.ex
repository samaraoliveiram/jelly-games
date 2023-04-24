defmodule JellyWeb.SessionController do
  use JellyWeb, :controller

  def new(conn, params) do
    %{"nickname" => nickname, "game_code" => game_code} = params

    player = Jelly.Guess.Player.new(nickname)

    conn
    |> put_session(:player, player)
    |> put_session(:game_code, game_code)
    |> redirect(to: ~p"/game/#{game_code}")
  end

  def delete(conn, _) do
    conn
    |> delete_session(:player)
    |> delete_session(:game_code)
    |> redirect(to: "/")
  end
end
