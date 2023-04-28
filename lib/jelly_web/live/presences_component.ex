defmodule JellyWeb.PresencesComponent do
  @moduledoc """
  Parent should implement two handle_info calls:
   1. to receive %{event: "presence_diff", payload: payload} and send to child using send_update
   2. to receive {:presences, presences} to receive the updated presence list
  """

  use JellyWeb, :live_component
  alias JellyWeb.Presence

  @topic "player-track-"

  def update(%{payload: diff}, socket) do
    socket =
      socket
      |> remove_presences(diff.leaves)
      |> add_presences(diff.joins)

    send_to_parent(socket.assigns.presences)

    {:ok, socket}
  end

  def update(%{game_code: game_code, player: player}, socket) do
    # socket = assign(socket, player: assigns.player, game_code: assigns.game_code)
    topic = @topic <> game_code

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Jelly.PubSub, topic)
      Presence.track(self(), topic, player.id, player)
    end

    presences =
      Presence.list(@topic <> game_code)
      |> format_presence_to_map()

    send_to_parent(presences)

    socket = assign(socket, :presences, presences)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <ul>
        <li :for={{_player_id, data} <- @presences}>
          <%= data.nickname %>
        </li>
      </ul>
    </div>
    """
  end

  defp format_presence_to_map(presences) do
    Enum.into(presences, %{}, fn {player_id, %{metas: [data | _]}} ->
      {player_id, data}
    end)
  end

  defp remove_presences(socket, leaves) do
    player_ids = Enum.map(leaves, fn {player_id, _} -> player_id end)
    assign(socket, presences: Map.drop(socket.assigns.presences, player_ids))
  end

  defp add_presences(socket, joins) do
    assign(socket, presences: Map.merge(socket.assigns.presences, format_presence_to_map(joins)))
  end

  defp send_to_parent(presences) do
    send(self(), {:presences, presences})
  end
end
