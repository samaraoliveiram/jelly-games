defmodule Jelly.Game.Notifier do
  @moduledoc """
  Abstraction for subscribe and publish game events
  """

  require Logger

  def subscribe(game_code) do
    Phoenix.PubSub.subscribe(Jelly.PubSub, "game-#{game_code}")
  end

  def broadcast(game_code, message) do
    Phoenix.PubSub.broadcast(Jelly.PubSub, "game-#{game_code}", message)
  end
end
