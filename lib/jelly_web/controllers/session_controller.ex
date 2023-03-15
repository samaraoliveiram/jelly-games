defmodule JellyWeb.SessionController do
  use JellyWeb, :controller

  def create(conn, %{"player" => name, "lobby_id" => lobby_id}) do
    player_id = generate_auth_token(conn, name)

    conn
    |> put_session(:player, name: name, id: player_id)
    |> put_session(:lobby_id, lobby_id)
    |> redirect(to: ~p"/lobby")
  end

  defp generate_auth_token(conn, player) do
    Phoenix.Token.sign(conn, "player auth", player)
  end
end
