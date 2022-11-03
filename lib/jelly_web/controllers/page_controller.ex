defmodule JellyWeb.PageController do
  use JellyWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
