defmodule JellyWeb.Router do
  use JellyWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {JellyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, %{"content-security-policy" => "default-src 'self'"}
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", JellyWeb do
    pipe_through [:browser, :home_redirect]

    live "/", LobbyLive.Home

    get "/sessions/:player/:lobby_id", SessionController, :create
  end

  scope "/", JellyWeb do
    pipe_through [:browser, :lobby_redirect]
    live "/lobby", LobbyLive.Show
  end

  # Other scopes may use custom stacks.
  # scope "/api", JellyWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:jelly, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: JellyWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  def lobby_redirect(conn, _) do
    case get_session(conn) do
      %{"lobby_id" => _, "player" => _} ->
        conn

      _ ->
        redirect(conn, to: "/")
    end
  end

  def home_redirect(conn, _) do
    case get_session(conn) do
      %{"lobby_id" => _, "player" => _} ->
        redirect(conn, to: "/lobby")

      _ ->
        conn
    end
  end
end
