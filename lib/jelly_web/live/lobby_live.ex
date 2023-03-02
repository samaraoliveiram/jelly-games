defmodule JellyWeb.LobbyLive do
  use JellyWeb, :live_view
  alias Jelly.Lobby

  def mount(_params, _session, socket) do
    socket = assign(socket, player: "")
    {:ok, socket}
  end

  def render(assigns) do
    assigns = assign(assigns, form: to_form(%{player: assigns.player}))
    IO.inspect(assigns.form, label: "FORM")
    IO.inspect(assigns.form[:player], label: "FORM")

    ~H"""
    <%= if @live_action != :show do %>
      <div class="text-zinc-900">
        <h1 class="text-5xl font-bold text-center">Welcome to Mimiquinha2000!</h1>
        <div class="flex space-x-4 justify-around p-10">
          <.button class="button h-10 w-32" phx-click={show_modal("new-modal")}>New</.button>
          <.button class="button h-10 w-32" phx-click={show_modal("join-modal")}>Join</.button>
        </div>
      </div>
      <!-- New Modal -->
      <.modal id="new-modal" on_confirm={JS.push("new")}>
        <.simple_form for={@form} phx-submit="new">
          <.input field={@form[:player]} label="Player Name" />
          <.button class="button h-10 w-32">New</.button>
        </.simple_form>
      </.modal>
      <!-- Join Modal -->
      <.modal id="join-modal" on_confirm={JS.push("join")}>
        <.simple_form for={@form} phx-submit="join">
          <.input field={@form[:player]} label="Player Name" />
          <.input field={@form[:lobby_id]} label="Lobby Code" />
          <.button class="button h-10 w-32">Join</.button>
        </.simple_form>
      </.modal>
    <% end %>
    """
  end

  def handle_event("new", %{"player" => player_name}, socket) do
    {:ok, lobby_id} = Lobby.create(player_name)

    socket = assign(socket, player: player_name, lobby_id: lobby_id)

    {:noreply, push_patch(socket, to: ~p"/lobby/#{lobby_id}")}
  end

  def handle_event("join", params, socket) do
    %{"player" => player_name, "lobby_id" => lobby_id} = params

    case Lobby.join(lobby_id, player_name) do
      {:ok, _} ->
        socket = assign(socket, player: player_name, lobby_id: lobby_id)
        {:noreply, push_patch(socket, to: ~p"/lobby/#{lobby_id}")}

      _ ->
        form = to_form(params, errors: [lobby_id: "Invalid code"]) |> IO.inspect(label: "TO_FORM")
        socket = assign(socket, form: form)
        {:noreply, socket}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end
end
