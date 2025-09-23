defmodule JellyWeb.GameLive do
  use JellyWeb, :live_view

  alias Jelly.GameServer

  def mount(%{"id" => game_code}, _session, socket) do
    if connected?(socket) do
      GameServer.subscribe(game_code)
    end

    case GameServer.get(game_code) do
      {:ok, summary} ->
        {:ok,
         assign(socket,
           presences: %{},
           current_players: get_current_players(summary.players),
           summary: summary,
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
            <p :if={@my_team} class="h3">
              Your team is <%= @my_team %>
            </p>
            <div :if={@timer}><.timer timer={@timer} /></div>
          </div>

          <.game_stage
            {@summary}
            current_players={@current_players}
            player={@player}
            my_team={@my_team}
            clipboard={url(@socket, ~p"/game/#{@summary.code}")}
          />
        </:main>
      </.layout>
    </div>
    """
  end

  def game_stage(%{winner: winner} = assigns) when not is_nil(winner) do
    ~H"""
    <div class="vertical-center">
      <p class="text">🏆 The winner is</p>
      <p class="h1">Team <%= @winner %></p>
      <p class="text">Congratulations!</p>
      <.button phx-click="restart">Restart</.button>
    </div>
    """
  end

  def game_stage(%{current_phase: :defining_teams} = assigns) do
    ~H"""
    <div class="vertical-center">
      <p class="h2">Invite your friends</p>
      <.clipboard code={@code} clipboard={@clipboard} />
      <p class="text">Invite at least 3 friends</p>
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
      <div
        :if={@player.id not in @sent_words}
        phx-mounted={JS.focus_first(to: "form")}
        class="w-3/4 mx-auto max-w-xs flex flex-col gap-3 text-center"
      >
        <p class="h2">
          Write words for your <br />friends to guess
        </p>
        <.form class="form" for={@form} phx-submit="put_words">
          <.input
            field={@form[:word_1]}
            pattern="[A-Za-z]*"
            required
            placeholder="put some smart word"
            autocomplete="off"
          />
          <.input
            field={@form[:word_2]}
            pattern="[A-Za-z]*"
            required
            placeholder="put some smart word"
            autocomplete="off"
          />
          <.input
            field={@form[:word_3]}
            pattern="[A-Za-z]*"
            required
            placeholder="put some smart word"
            autocomplete="off"
          />
          <.button>Done</.button>
        </.form>
        <p class="text">
          Remember, your team will also <br /> have to guess these words 🤪
        </p>
      </div>
      <div :if={@player.id in @sent_words} class="flex flex-col gap-3 text-center">
        <p class="h2">Words done!</p>
        <p class="text">Waiting for <%= length(@sent_words) %> / <%= length(@players) %></p>
      </div>
    </div>
    """
  end

  def game_stage(%{current_phase: :scores} = assigns) do
    ~H"""
    <div class="game-info">
      <div>
        <p class="text mb-2">The next phase is</p>
        <p class="h2">
          <%= to_string(@next_phase) |> String.capitalize() %>
        </p>
      </div>
      <div>
        <p class="h1 mb-4">Phase Finished!</p>
        <%= for team <-@teams do %>
          <p class="h3 mb-4">
            Team <%= team.name %> guessed <%= get_points(team.points, @next_phase) %>
          </p>
        <% end %>
        <.button phx-click="next_phase">Continue</.button>
      </div>
    </div>
    """
  end

  def game_stage(%{current_player: current_player, player: player} = assigns)
      when player.id == current_player do
    ~H"""
    <div class="game-info">
      <div>
        <p class="text pb-2">The phase is</p>
        <p class="h1">
          <%= to_string(@current_phase) |> String.capitalize() %>
        </p>
      </div>
      <div>
        <p class="h2 mb-4">It's your turn!</p>
        <p class="text mb-1">Your word is</p>
        <p class="h1 mb-4"><%= @current_word %></p>
        <.button phx-click="point">Guessed</.button>
      </div>
    </div>
    """
  end

  def game_stage(assigns) do
    ~H"""
    <div class="game-info">
      <div>
        <p class="text pb-2">The phase is</p>
        <p class="h1">
          <%= to_string(@current_phase) |> String.capitalize() %>
        </p>
      </div>
      <div>
        <p class="h2 mb-4">
          <%= if @current_team == @my_team do %>
            Your team is playing!
          <% else %>
            The team <%= @current_team %> is playing!
          <% end %>
        </p>
        <p class="text mb-1">Who is playing</p>
        <p class="h1">
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

  def handle_event("start", _params, socket) do
    players = Map.values(socket.assigns.presences)

    case GameServer.define_teams(socket.assigns.game_code, players) do
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
    {:ok, summary} = GameServer.restart(socket.assigns.game_code)
    {:noreply, assign(socket, my_team: nil, summary: summary)}
  end

  def handle_event("put_words", params, socket) do
    {:ok, summary} =
      GameServer.put_words(socket.assigns.game_code, Map.values(params), socket.assigns.player.id)

    {:noreply, assign(socket, summary: summary)}
  end

  def handle_event("point", _, socket) do
    {:ok, summary} = GameServer.mark_point(socket.assigns.game_code)
    {:noreply, assign(socket, summary: summary)}
  end

  def handle_event("next_phase", _, socket) do
    GameServer.next_phase(socket.assigns.game_code)
    {:noreply, socket}
  end

  def handle_info({:game_updated, summary}, socket) do
    socket =
      if socket.assigns.my_team == nil && summary.teams != [] do
        assign(socket, my_team: get_my_team(summary.teams, socket.assigns.player.id))
      else
        socket
      end

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

  defp get_points(points, next_phase) do
    case next_phase do
      :mimicry -> Keyword.get(points, :password, 0)
      :one_password -> Keyword.get(points, :mimicry, 0)
    end
  end
end
