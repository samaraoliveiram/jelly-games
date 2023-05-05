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
           current_players: get_current_players(summary.players),
           summary: summary,
           words_done: false,
           timer: nil,
           my_team: get_my_team(summary.teams, socket.assigns.player.id)
         )}

      _ ->
        socket = put_flash(socket, :error, "Game no longer available")
        {:ok, redirect(socket, to: "/session/delete")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="screen-centered">
      <.layout>
        <:action>
          <.link class="flex" navigate={~p"/session/delete"}>
            exit <Heroicons.x_mark class="w-6 my-auto" />
          </.link>
        </:action>
        <:sidebar>
          <.live_component
            id="presences"
            module={JellyWeb.PresencesComponent}
            game_code={@game_code}
            player={@player}
          />
        </:sidebar>
        <:main>
          <div class="flex justify-between items-center">
            <p :if={@my_team} class="text-sm font-semibold text-gray-50">
              Your team is <%= @my_team %>
            </p>
            <div :if={@timer}><.timer timer={@timer} /></div>
          </div>

          <.game_stage
            {@summary}
            current_players={@current_players}
            clipboard={url(@socket, ~p"/game/#{@summary.code}")}
          />
        </:main>
      </.layout>
    </div>
    """
  end

  def game_stage(%{current_phase: :defining_teams} = assigns) do
    ~H"""
    <div class="vertical-center">
      <p class="text-gray-50 text-xl font-bold leading-7 ">Invite your friends</p>
      <div class="clipboard">
        <p class="truncate tracking-[0.4em]"><%= @code %></p>
        <button id="clipboard" data-content={@clipboard} phx-hook="Clipboard">
          <Heroicons.clipboard class="w-6 my-auto" />
        </button>
      </div>
      <p class="text-xs text-gray-50">Invite at least 3 friends</p>
      <.button phx-click="start">Start</.button>
    </div>
    """
  end

  def game_stage(%{current_phase: :word_selection} = assigns) do
    assigns =
      assign(assigns,
        form: to_form(%{"word_1" => "", "word_2" => "", "word_3" => ""}),
        as: :words_data
      )

    ~H"""
    <div class="vertical-center">
      <p class="text-gray-50 text-xl font-bold leading-7 text-center">
        Write words for your <br />friends to guess
      </p>
      <div phx-mounted={JS.focus_first(to: "form")} class="w-3/4 mx-auto max-w-xs">
        <.form class="form" for={@form} phx-submit="put_words">
          <.input
            field={@form[:word_1]}
            required
            placeholder="put some smart word"
            autocomplete="off"
          />
          <.input
            field={@form[:word_2]}
            required
            placeholder="put some smart word"
            autocomplete="off"
          />
          <.input
            field={@form[:word_3]}
            required
            placeholder="put some smart word"
            autocomplete="off"
          />
          <.button>Done</.button>
        </.form>
      </div>
      <p class="text-xs text-gray-50 text-center">
        Remember, your team will also <br /> have to guess these words 🤪
      </p>
    </div>
    """
  end

  def game_stage(assigns) do
    ~H"""
    <div class="vertical-center text-gray-50 text-center flex flex-col gap-16">
      <div>
        <p class="text-xs pb-2">The phase is</p>
        <p class=" text-2xl font-bold">
          <%= to_string(@current_phase) |> String.capitalize() %>
        </p>
      </div>
      <div>
        <p class="text-xl font-bold">The team <%= @current_team %> is playing!</p>
        <p class="text-xs ">Who is playing</p>
        <p class=" text-2xl font-bold">
          <%= get_in(@current_players, [
            @current_player,
            Access.key!(:nickname)
          ]) %>
        </p>
      </div>
    </div>
    """
  end

  defp timer(assigns) do
    ~H"""
    <div class="flex gap-2 text-gray-50">
      <Heroicons.clock class="w-7 my-auto" />
      <p class="text-2xl font-bold"><%= @timer %></p>
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

        {:noreply,
         assign(socket,
           summary: summary,
           my_team: my_team,
           current_players: socket.assigns.presences
         )}
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

  defp get_current_players(players) do
    Enum.into(players, %{}, fn player -> {player.id, player} end)
  end
end
