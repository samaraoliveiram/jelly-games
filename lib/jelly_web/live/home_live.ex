defmodule JellyWeb.HomeLive do
  use JellyWeb, :live_view
  import JellyWeb.Components.Logo

  alias Phoenix.LiveView.JS
  alias Jelly.Guess

  def mount(_params, _session, socket) do
    socket = assign(socket, action: nil)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="w-full flex pt-12 pb-4">
        <.logo />
      </div>
      <%= if @action == nil do %>
        <div class="form w-3/4 mx-auto max-w-xs pt-4">
          <button class="button-dark" phx-click={JS.patch("/?action=new")}>
            New Game
          </button>
          <button class="button-dark" phx-click={JS.patch("/?action=join")}>
            Join Game
          </button>
        </div>
      <% else %>
        <div class="w-3/4 mx-auto max-w-xs pt-4">
          <.link phx-click={JS.navigate("/")}>
            <Heroicons.chevron_left class="w-6 mb-4 stroke-purple-700" />
          </.link>
          <.live_component id="form" module={JellyWeb.FormComponent} action={@action} />
        </div>
      <% end %>
    </div>
    """
  end

  def handle_info({"new", params}, socket) do
    case Guess.new() do
      {:ok, game_code} ->
        {:noreply, redirect(socket, to: ~p"/session/new?game_code=#{game_code}&player=#{params}")}

      _error ->
        socket = put_flash(socket, :error, "Something went wrong, try again later")
        {:noreply, socket}
    end
  end

  def handle_info({"join", params}, socket) do
    %{"game_code" => game_code} = params
    player = Map.drop(params, ["game_code"])

    case Guess.get(game_code) do
      {:ok, _} ->
        {:noreply, redirect(socket, to: ~p"/session/new?game_code=#{game_code}&player=#{player}")}

      {:error, :not_found} ->
        socket =
          put_flash(socket, :error, "Game was not found, check if the game code is correct")

        {:noreply, socket}
    end
  end

  def handle_params(%{"action" => action}, _, socket) do
    IO.inspect(action, label: "ACTION UPDATED")
    socket = assign(socket, action: action)
    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end
end
