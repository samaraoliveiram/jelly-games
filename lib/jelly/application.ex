defmodule Jelly.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      JellyWeb.Telemetry,
      # Start the Ecto repository
      Jelly.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Jelly.PubSub},
      # Start Finch
      {Finch, name: Jelly.Finch},
      # Start the Endpoint (http/https)
      JellyWeb.Endpoint,
      # Starts Jelly Registry
      {Registry, keys: :unique, name: Jelly.GameRegistry},
      # Starts Jelly Supervisor
      {DynamicSupervisor, name: Jelly.DynamicSupervisor},
      JellyWeb.Presence
    ]

    :ets.new(:games_table, [:public, :named_table])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Jelly.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JellyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
