defmodule JellyWeb.FormComponent do
  @moduledoc false
  use JellyWeb, :live_component
  import Ecto.Changeset

  def update(assigns, socket) do
    params = %{game_code: assigns.game_code}

    socket =
      assign(socket,
        action: assigns.action,
        form: to_form(changeset(params, assigns.action), as: :data)
      )

    {:ok, socket}
  end

  def render(assigns) do
    # todo: adjust form validation to only changed field
    ~H"""
    <div phx-mounted={JS.focus_first(to: "form")}>
      <.form class="form" for={@form} phx-submit="submit" phx-change="validate" phx-target={@myself}>
        <.input
          name="nickname"
          field={@form[:nickname]}
          phx-debounce="1000"
          placeholder="some cool nickname"
          autocomplete="off"
        />
        <%= if @action == "join" do %>
          <.input
            :if={@action == "join"}
            name="game_code"
            phx-debounce="1000"
            field={@form[:game_code]}
            placeholder="put the game code"
            autocomplete="off"
          />
          <.button class="button-dark" phx-disable-with="Joining...">Join Game</.button>
        <% else %>
          <.button class="button-dark" phx-disable-with="Creating...">Create Game</.button>
        <% end %>
      </.form>
    </div>
    """
  end

  def handle_event("submit", params, socket) do
    action = socket.assigns.action

    case validate_form(params, action) do
      %{errors: [_ | _]} = changeset ->
        {:noreply, assign(socket, form: to_form(changeset, as: :data))}

      _ ->
        send(self(), {action, params})
        {:noreply, socket}
    end
  end

  def handle_event("validate", params, socket) do
    changeset = validate_form(params, socket.assigns.action)
    {:noreply, assign(socket, form: to_form(changeset, as: :data))}
  end

  defp validate_form(params, action) do
    changeset(params, action)
    |> Map.put(:action, :validate)
  end

  defp changeset(params, action) do
    {%{}, %{nickname: :string, game_code: :string}}
    |> cast(params, [:nickname, :game_code])
    |> validate_required(:nickname)
    |> validate_length(:nickname, min: 3, max: 100)
    |> validate_join(action)
  end

  defp validate_join(changeset, action) do
    if action == "join" do
      changeset
      |> validate_length(:game_code, min: 10, max: 100)
      |> validate_required(:game_code)
    else
      changeset
    end
  end
end
