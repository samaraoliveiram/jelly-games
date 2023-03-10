defmodule JellyWeb.LobbyLive.Home do
  use JellyWeb, :live_view
  alias Jelly.Lobby

  def mount(_params, _session, socket) do
    form_params = %{"player_name" => "", "lobby_id" => ""}
    socket = assign(socket, form: to_form(form_params))
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <%= if @live_action != :show do %>
      <div class="home-body">
        <div class="welcome-text">Welcome to Mimiquinha2000!</div>
        <div class="action-buttons">
          <.button phx-click={show_modal("new-modal")}>New</.button>
          <.button phx-click={show_modal("join-modal")}>Join</.button>
        </div>
      </div>
      <!-- New Modal -->
      <.modal id="new-modal" on_confirm={JS.push("new")}>
        <.simple_form for={@form} phx-submit="new">
          <.input field={@form["player_name"]} label="Player Name" />
          <.button class="button h-10 w-32">New</.button>
        </.simple_form>
      </.modal>
      <!-- Join Modal -->
      <.modal id="join-modal" on_confirm={JS.push("join")}>
        <.simple_form for={@form} phx-submit="join">
          <.input field={@form["player_name"]} label="Player Name" />
          <.input field={@form["lobby_id"]} label="Lobby Code" />
          <.button class="button h-10 w-32">Join</.button>
        </.simple_form>
      </.modal>
    <% end %>
    """
  end

  def handle_event("new", %{"player_name" => player_name}, socket) do
    {:ok, lobby_id} = Lobby.create(player_name)
    {:noreply, redirect(socket, to: ~p"/sessions/#{player_name}/#{lobby_id}")}
  end

  def handle_event("join", params, socket) do
    %{"player_name" => player_name, "lobby_id" => lobby_id} = params

    case Lobby.join(lobby_id, player_name) do
      {:ok, _} ->
        {:noreply, redirect(socket, to: ~p"/sessions/#{player_name}/#{lobby_id}")}

      _ ->
        form = to_form(params, errors: [lobby_id: "Invalid code"])
        socket = assign(socket, form: form)
        {:noreply, socket}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end
end
