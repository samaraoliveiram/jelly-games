defmodule JellyWeb.HomeLive do
  use JellyWeb, :live_view
  import JellyWeb.Components.Logo

  alias Phoenix.LiveView.JS
  alias Jelly.Guess

  def mount(_params, _session, socket) do
    socket = assign(socket, action: nil, game_code: nil)
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
          <.live_component
            id="form"
            module={JellyWeb.FormComponent}
            action={@action}
            game_code={@game_code}
          />
        </div>
      <% end %>
    </div>
    """
  end

  def handle_info({"new", params}, socket) do
    {:ok, game_code} = Guess.new()
    %{"nickname" => nickname} = params

    {:noreply, redirect(socket, to: "/session/new?game_code=#{game_code}&nickname=#{nickname}")}
  end

  def handle_info({"join", params}, socket) do
    %{"game_code" => game_code, "nickname" => nickname} = params

    case Guess.get(game_code) do
      {:ok, _} ->
        {:noreply,
         redirect(socket, to: "/session/new?game_code=#{game_code}&nickname=#{nickname}")}

      {:error, :not_found} ->
        socket =
          put_flash(socket, :error, "Game was not found, check if the game code is correct")

        {:noreply, socket}
    end
  end

  def handle_params(%{"action" => action} = params, _, socket) do
    game_code = params["game_code"]
    {:noreply, assign(socket, action: action, game_code: game_code)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end
end
