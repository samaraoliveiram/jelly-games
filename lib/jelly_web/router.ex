defmodule JellyWeb.Router do
  use JellyWeb, :router

  import JellyWeb.GamePlug

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {JellyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, %{"content-security-policy" => "default-src 'self'"}
    plug :fetch_live_flash
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", JellyWeb do
    pipe_through [:browser, :redirect_if_has_player]

    live "/", HomeLive, :index
    live "/new", HomeLive, :new
    live "/join", HomeLive, :join
  end

  scope "/", JellyWeb do
    pipe_through [:browser, :require_player]

    live_session :has_player, on_mount: {JellyWeb.GamePlug, :ensure_has_game_info} do
      live "/game/:id", GameLive
    end
  end

  scope "/session", JellyWeb do
    pipe_through [:browser]

    get "/new", SessionController, :new
    get "/delete", SessionController, :delete
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
end
