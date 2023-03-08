defmodule JellyWeb.LobbyLive.Show do
  use JellyWeb, :live_view

  alias JellyWeb.LobbyPresence
  alias Jelly.PubSub

  @presence "jelly:presence"

  def mount(_, session, socket) do
    %{"player" => player, "lobby_id" => lobby_id} = session

    if connected?(socket) do
      {:ok, _} =
        LobbyPresence.track(self(), @presence, player[:id], %{
          name: player[:name],
          joinet_at: :os.system_time(:seconds)
        })

      Phoenix.PubSub.subscribe(PubSub, @presence)
    end

    socket =
      socket
      |> assign(:player, player)
      |> assign(:players, %{})
      |> assign(:lobby_id, lobby_id)
      |> handle_joins(LobbyPresence.list(@presence))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="text-xl text-center font-bold">Lobby code: <%= @lobby_id %></div>
    <div :for={{player_id, player} <- @players} id={player_id}><%= player.name %></div>
    """
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    {
      :noreply,
      socket
      |> handle_leaves(diff.leaves)
      |> handle_joins(diff.joins)
    }
  end

  defp handle_joins(socket, joins) do
    IO.inspect(joins)

    Enum.reduce(joins, socket, fn {player_id, %{metas: [player_info | _]}}, socket ->
      players = Map.put(socket.assigns.players, player_id, player_info)
      assign(socket, :players, players)
    end)
  end

  defp handle_leaves(socket, leaves) do
    Enum.reduce(leaves, socket, fn {player, _}, socket ->
      assign(socket, :players, Map.delete(socket.assigns.players, player))
    end)
  end
end
