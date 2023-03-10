defmodule JellyWeb.LobbyLive.Show do
  use JellyWeb, :live_view

  alias JellyWeb.LobbyPresence
  alias Jelly.PubSub
  import JellyWeb.Components.Icons

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
    <div class="lobby">
      <div class="player-panel">
        <div class="text-center pb-4">Players: <%= Kernel.map_size(@players) %>/20</div>
        <div :for={{player_id, player} <- @players} id={player_id} class="player">
          <.player />
          <a class={
            if @player[:name] == player.name, do: "current-player player-name", else: "player-name"
          }>
            <%= player.name %>
          </a>
        </div>
      </div>
      <div class="lobby-body">
        <div class="text-sm text-slate-700 text-center">Lobby code: <%= @lobby_id %></div>
        <div class="how-to-play">
          <div class="text-xl font-bold text-center p-3">How to play?</div>
          <ul>
            <li>
              When the game is started:
              <ol class="list-disc">
                <li>The players are split into equal teams</li>
                <li>Each player will write 3 words</li>
              </ol>
            </li>
            <li>The game have 3 rounds</li>
            <li>
              Each round has a theme:
              <ol class="list-decimal">
                <li>password</li>
                <li>mimicry</li>
                <li>one-password</li>
              </ol>
            </li>
            <li>A player will receive a word and the team will have to guess in a turn</li>
            <li>Each turn have 1 minute</li>
            <li>Each correct guess is worth 1 point</li>
            <li>When a turn end the next team plays</li>
            <li>The round ends when all the words are guessed</li>
            <li>The winner of the game is the team with more points</li>
          </ul>
        </div>
      </div>
    </div>
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
