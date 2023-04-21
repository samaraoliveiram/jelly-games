defmodule JellyWeb.Plug.PlayerSession do
  use JellyWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  # def require_player(conn, _opts) do
  #   if conn.assigns[:current_player] do
  #     conn
  #   else
  #     # todo: store the game code and fill the input
  #     conn
  #     |> redirect(to: ~p"/?action=join")
  #     |> halt()
  #   end
  # end

  def fetch_player(conn) do
    IO.inspect(conn.flash(label: "CONN"))

    conn
  end

  def init(opts), do: opts
  def call(conn, _opts), do: conn
end
