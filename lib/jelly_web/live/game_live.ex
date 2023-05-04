defmodule JellyWeb.GameLive do
  use JellyWeb, :live_view

  alias Jelly.Guess

  def mount(%{"id" => game_code}, _session, socket) do
    if connected?(socket) do
      Guess.subscribe(game_code)
    end

    case Guess.get(game_code) do
      {:ok, summary} ->
        {:ok,
         assign(socket,
           presences: %{},
           summary: summary,
           words_done: false,
           timer: 0,
           my_team: get_my_team(summary.teams, socket.assigns.player.id)
         )}

      _ ->
        socket = put_flash(socket, :error, "Game no longer available")
        {:ok, redirect(socket, to: "/session/delete")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="screen-centered flex flex-col p-9 sm:p-16 md:p-24">
      <.link
        navigate={~p"/session/delete"}
        class="flex sm:justify-end mb-1 text-lg font-light text-gray-50"
      >
        exit <Heroicons.x_mark class="w-6 my-auto" />
      </.link>
      <div class="w-full grid gap-y-4 sm:gap-x-4 grid-cols-1 sm:grid-cols-3 grid-rows-6 sm:grid-rows-1 h-[94%]">
        <div class="panel">
          <.live_component
            id="presences"
            module={JellyWeb.PresencesComponent}
            game_code={@game_code}
            player={@player}
          />
        </div>
        <div class="panel sm:col-span-2 row-span-5 sm:row-span-1">
          <div :if={@summary.winner == nil}>
            <.button :if={@summary.current_phase == :defining_teams} phx-click="start">Start</.button>
            <.words_form :if={@summary.current_phase == :word_selection} words_done={@words_done} />
            <div :if={@summary.current_phase in [:password, :mimicry, :one_password]}>
              <.timer :if={@timer > 0} timer={@timer} />
              <p>Your team: Team <%= @my_team %></p>
              <p>Phase: <%= @summary.current_phase %></p>
              <p>Team playing: <%= @summary.current_team %></p>
              <p>
                Current player: <%= get_in(@players, [@summary.current_player, Access.key!(:nickname)]) %>
              </p>
              <div :if={@player.id == @summary.current_player}>
                <p class="text-lg">É a sua vez!</p>
                <p class="text-xl"><%= @summary.current_word %></p>
                <.button phx-click="point">Correct guess</.button>
              </div>
            </div>
            <div :if={@summary.current_phase == :scores}>
              <.points teams={@summary.teams} />
              <.button phx-click="next_phase">Next Phase</.button>
            </div>
          </div>
          <div :if={@summary.winner != nil}>
            <p class="4xl">Winner: Team <%= @summary.winner %></p>
            <.points teams={@summary.teams} />
            <.button phx-click="restart">Restart Game</.button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp words_form(assigns) do
    assigns =
      assign(assigns,
        form: to_form(%{"word_1" => "", "word_2" => "", "word_3" => ""}),
        as: :words_data
      )

    ~H"""
    <div>
      <.form class="form" for={@form} phx-submit="put_words">
        <.input field={@form[:word_1]} required disabled={@words_done} />
        <.input field={@form[:word_2]} required disabled={@words_done} />
        <.input field={@form[:word_3]} required disabled={@words_done} />
        <.button class="button-dark" disabled={@words_done}>Submit words</.button>
      </.form>
    </div>
    """
  end

  defp timer(assigns) do
    ~H"""
    <div>
      <p><%= @timer %></p>
    </div>
    """
  end

  defp points(assigns) do
    ~H"""
    <p>Team points</p>
    <%= for team <-@teams do %>
      <p>Team <%= team.name %></p>
      <p :for={{key, value} <- team.points}>
        <%= to_string(key) %>
        <%= value %>
      </p>
    <% end %>
    """
  end

  def handle_event("start", _params, socket) do
    players = Map.values(socket.assigns.presences)

    case Guess.define_teams(socket.assigns.game_code, players) do
      {:error, :not_enough_players} ->
        {:noreply, put_flash(socket, :error, "Need 4 players to start")}

      {:ok, summary} ->
        my_team = get_my_team(summary.teams, socket.assigns.player.id)
        {:noreply, assign(socket, summary: summary, my_team: my_team)}
    end
  end

  def handle_event("restart", _params, socket) do
    {:ok, summary} = Guess.restart(socket.assigns.game_code)
    {:noreply, assign(socket, words_done: false, summary: summary)}
  end

  def handle_event("put_words", params, socket) do
    {:ok, summary} = Guess.put_words(socket.assigns.game_code, Map.values(params))
    {:noreply, assign(socket, summary: summary, words_done: true)}
  end

  def handle_event("point", _, socket) do
    {:ok, summary} = Guess.mark_point(socket.assigns.game_code)
    {:noreply, assign(socket, summary: summary)}
  end

  def handle_event("next_phase", _, socket) do
    Guess.next_phase(socket.assigns.game_code)
    {:noreply, socket}
  end

  def handle_info({:game_updated, summary}, socket) do
    {:noreply, assign(socket, summary: summary)}
  end

  def handle_info(%{event: "presence_diff", payload: payload}, socket) do
    send_update(JellyWeb.PresencesComponent, id: "presences", payload: payload)
    {:noreply, socket}
  end

  def handle_info({:presences, presences}, socket) do
    {:noreply, assign(socket, :presences, presences)}
  end

  def handle_info({:timer, count}, socket) do
    count = System.convert_time_unit(count, :millisecond, :second)
    {:noreply, assign(socket, :timer, count)}
  end

  def handle_info({:shutdown, _summary}, socket) do
    socket = put_flash(socket, :error, "Game no longer available")
    {:noreply, redirect(socket, to: ~p"/session/delete")}
  end

  defp get_my_team(teams, player_id) do
    team = Enum.find(teams, fn team -> player_id in team.players end)
    team && team.name
  end
end
