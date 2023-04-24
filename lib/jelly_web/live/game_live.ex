defmodule JellyWeb.GameLive do
  use JellyWeb, :live_view
  alias Jelly.Guess

  def mount(%{"id" => game_code}, _session, socket) do
    if connected?(socket) do
      Guess.subscribe(game_code)
    end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.button phx-click="exit">Exit</.button>
      <.live_component
        id="presences"
        module={JellyWeb.PresencesComponent}
        game_code={@game_code}
        player={@player}
      />
    </div>
    """
  end

  def handle_event("exit", _params, socket) do
    {:noreply, redirect(socket, to: ~p"/session/delete")}
  end

  def handle_info(%{event: "presence_diff", payload: payload}, socket) do
    send_update(JellyWeb.PresencesComponent, id: "presences", payload: payload)
    {:noreply, socket}
  end

  def handle_info({:timeout, _summary}, socket) do
    socket = put_flash(socket, :error, "Game ended for timeout")
    {:noreply, redirect(socket, to: ~p"/session/delete")}
  end

  def handle_info(message, socket) do
    IO.inspect(message, label: "MENSAGEM RECEBIDA")
    {:noreply, socket}
  end
end
