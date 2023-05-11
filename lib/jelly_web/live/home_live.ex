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
    <div class="screen-centered">
      <div
        class={[
          "flex flex-col w-full",
          @action == nil &&
            "scale-0 transition-transform ease-in-out duration-1000"
        ]}
        phx-mounted={JS.add_class("scale-100")}
      >
        <div class="pb-4 drop-shadow-2xl">
          <.logo />
        </div>
        <%= if @action == nil do %>
          <div class="form w-3/4 mx-auto max-w-xs pt-4 text-center">
            <.link id="new" class="h1 link-animation" navigate={~p"/?action=new"}>
              New
            </.link>
            <.link id="join" class="h1 link-animation" navigate={~p"/?action=join"}>
              Join
            </.link>
          </div>
        <% else %>
          <div class="w-3/4 mx-auto max-w-xs pt-4">
            <.link navigate="/" class="text-gray-900 w-">
              <Heroicons.chevron_left class="w-7 mb-2 " />
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
