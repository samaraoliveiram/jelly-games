defmodule JellyWeb.HomeLive do
  use JellyWeb, :live_view
  import JellyWeb.Components.Logo

  alias Phoenix.LiveView.JS
  alias Jelly.Guess

  def render(assigns) do
    ~H"""
    <div class="flex flex-col w-full">
      <div class="pb-4 drop-shadow-2xl">
        <.logo />
      </div>
      <%= if @live_action == :index do %>
        <div class="flex flex-col gap-4 pt-4 text-center" >
          <.link patch={~p"/new"}> New </.link>
          <.link patch={~p"/join"}> Join </.link>
        </div>
      <% else %>
        <div class="flex flex-col gap-4 justify-center mx-auto w-3/4 max-w-xs pt-4">
          <.back phx-click={JS.patch(~p"/")}/>
          <.simple_form for={@form} phx-change="validate" phx-submit="submit">
            <.input
              name="nickname"
              field={@form[:nickname]}
              phx-debounce="700"
              placeholder="some cool nickname"
            />
            <.input
              :if={@live_action == :join}
              name="game_code"
              phx-debounce="500"
              field={@form[:game_code]}
              placeholder="game code"
              autocomplete="off"
            />
            <.button phx-disable-with={(@live_action == :join && "Joining") || "Creating"}>
              {(@live_action == :join && "Join") || "New"}
            </.button>
          </.simple_form>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    socket = assign(socket, game_code: nil)
    {:ok, socket}
  end

  def handle_params(params, _, socket) do
    game_code = params["game_code"]
    action = socket.assigns.live_action

    {:noreply,
     assign(socket,
       game_code: game_code,
       form: to_form(changeset(params, action), as: :data)
     )}
  end

  def handle_event("submit", params, socket) do
    action = socket.assigns.live_action

    case apply_actions(params, action) do
      {:ok, data} ->
        {:noreply, create_or_join_game(action, data, socket)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :data))}
    end
  end

  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, form: validate_form(params, socket.assigns.live_action))}
  end

  defp create_or_join_game(:new, data, socket) do
    case Guess.new() do
      {:ok, game_code} ->
        nickname = data.nickname
        redirect(socket, to: "/session/new?game_code=#{game_code}&nickname=#{nickname}")

      _ ->
        put_flash(socket, :error, "Error while creating game, try again")
    end
  end

  defp create_or_join_game(:join, data, socket) do
    %{game_code: game_code, nickname: nickname} = data

    case Guess.get(game_code) do
      {:ok, _} ->
        redirect(socket, to: "/session/new?game_code=#{game_code}&nickname=#{nickname}")

      {:error, :not_found} ->
        put_flash(socket, :error, "Game not found, check if the game code is correct")
    end
  end

  defp validate_form(params, action) do
    changeset(params, action)
    |> Map.put(:action, :validate)
    |> to_form(as: :data)
  end

  defp changeset(params, action) do
    {%{}, %{nickname: :string, game_code: :string}}
    |> Ecto.Changeset.cast(params, [:nickname, :game_code])
    |> Ecto.Changeset.validate_required(:nickname)
    |> Ecto.Changeset.validate_length(:nickname, min: 3, max: 15)
    |> validate_join(action)
  end

  defp validate_join(changeset, action) do
    if action == "join" do
      changeset
      |> Ecto.Changeset.validate_length(:game_code, min: 10, max: 100)
      |> Ecto.Changeset.validate_required(:game_code)
    else
      changeset
    end
  end

  defp apply_actions(params, action) do
    params
    |> changeset(action)
    |> Ecto.Changeset.apply_action(:validate)
  end
end
