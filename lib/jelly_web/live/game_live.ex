defmodule JellyWeb.GameLive do
  use JellyWeb, :live_view

  alias Jelly.Guess

  def render(assigns) do
    ~H"""
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
          <p :if={@summary && get_my_team(@summary, @player.id)} class="h3">
            Your team is {get_my_team(@summary, @player.id).name}
          </p>
          <div :if={@timer}><.timer timer={@timer} /></div>
        </div>

        <.game_stage
          player={@player}
          words_form={@words_form}
          clipboard={url(@socket, ~p"/game/#{@summary.code}")}
          {@summary}
        />
        <div :if={debug_mode_enabled?()}>
          <.input
            type="toggle"
            name="debug_mode"
            label="Debug Mode"
            value={false}
            phx-click={JS.toggle(to: "#debug")}
          />
          <pre id="debug" class="hidden"> {inspect(%{summary: @summary}, pretty: true) } </pre>
        </div>
      </:main>
    </.layout>
    """
  end

  def game_stage(%{winner: winner} = assigns) when not is_nil(winner) do
    ~H"""
    <div class="vertical-center">
      <p class="text">🏆 The winner is</p>
      <p class="h1">Team {@winner}</p>
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
        <p class="text">
          Remember, your team will also <br /> have to guess these words 🤪
        </p>
        <.simple_form for={@words_form} phx-change="validate_words" phx-submit="submit_words">
          <.input
            field={@words_form[:word_1]}
            placeholder="fill in word 1"
            autocomplete="off"
          />
          <.input
            field={@words_form[:word_2]}
            placeholder="fill in word 2"
            autocomplete="off"
          />
          <.input
            field={@words_form[:word_3]}
            placeholder="fill in word 3"
            autocomplete="off"
          />
          <.button>Done</.button>
        </.simple_form>
      </div>
      <div :if={@player.id in @sent_words} class="flex flex-col gap-3 text-center">
        <p class="h2">Words done!</p>
        <p class="text">Waiting for {length(@sent_words)} / {length(@players)}</p>
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
          {to_string(@next_phase) |> String.capitalize()}
        </p>
      </div>
      <div>
        <p class="h1 mb-4">Phase finished!</p>
        <%= for team <-@teams do %>
          <p class="h3 mb-4">
            Team {team.name} guessed {get_points(team.points, @next_phase)}
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
          {to_string(@current_phase) |> String.capitalize()}
        </p>
      </div>
      <div>
        <p class="h2 mb-4">It's your turn!</p>
        <p class="text mb-1">Your word is</p>
        <p class="h1 mb-4">{@current_word}</p>
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
          {to_string(@current_phase) |> String.capitalize()}
        </p>
      </div>
      <div>
        <p class="h2 mb-4">
          <%= if my_team?(assigns, @player.id) do %>
            Your team is playing!
          <% else %>
            The team {@current_team.name} is playing!
          <% end %>
        </p>
        <p class="text mb-1">Who is playing</p>
        <p class="h1">
          {find_current_player(@players, @current_player).nickname}
        </p>
      </div>
    </div>
    """
  end

  defp timer(assigns) do
    ~H"""
    <div class="flex gap-2 text-gray-50">
      <Heroicons.clock class="w-7 my-auto" />
      <p class="text-2xl font-bold">{@timer}</p>
    </div>
    """
  end

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
           timer: nil,
           words_form: to_words_form(%{})
         )}

      _ ->
        socket = put_flash(socket, :error, "Game no longer available")
        {:ok, redirect(socket, to: "/session/delete")}
    end
  end

  def handle_event("start", _params, socket) do
    players = Map.values(socket.assigns.presences)

    case Guess.define_teams(socket.assigns.game_code, players) do
      {:error, :not_enough_players} ->
        {:noreply, put_flash(socket, :error, "Need 4 players to start")}

      {:ok, summary} ->
        {:noreply, assign(socket, summary: summary)}
    end
  end

  def handle_event("restart", _params, socket) do
    Guess.restart(socket.assigns.game_code)
    {:noreply, socket}
  end

  def handle_event("validate_words", params, socket) do
    {:noreply, assign(socket, words_form: to_words_form(params["words"]))}
  end

  def handle_event("submit_words", params, socket) do
    words = params["words"]

    case validate_words(words) do
      %{valid?: true} ->
        {:ok, summary} =
          Guess.put_words(socket.assigns.game_code, Map.values(words), socket.assigns.player.id)

        {:noreply, assign(socket, summary: summary, words_form: to_words_form(%{}))}

      _ ->
        {:noreply, assign(socket, words_form: to_words_form(words))}
    end
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

  def handle_info({:timer, nil}, socket) do
    {:noreply, assign(socket, :timer, nil)}
  end

  def handle_info({:timer, count}, socket) do
    count = System.convert_time_unit(count, :millisecond, :second)
    {:noreply, assign(socket, :timer, count)}
  end

  def handle_info({:shutdown, _summary}, socket) do
    socket = put_flash(socket, :error, "Game no longer available")
    {:noreply, redirect(socket, to: ~p"/session/delete")}
  end

  defp get_my_team(summary, player_id) do
    summary.teams
    |> Enum.find(fn team -> player_id in team.players end)
  end

  defp my_team?(summary, player_id) do
    case {get_my_team(summary, player_id), summary.current_team} do
      {%{name: player_team_name}, %{name: current_team_name}} ->
        player_team_name == current_team_name

      _ ->
        false
    end
  end

  defp find_current_player(players, player_id) do
    Enum.find(players, &(&1.id == player_id))
  end

  defp get_points(points, next_phase) do
    case next_phase do
      :mimicry -> Keyword.get(points, :password, 0)
      :one_password -> Keyword.get(points, :mimicry, 0)
    end
  end

  defp validate_words(words) do
    types = %{word_1: :string, word_2: :string, word_3: :string}

    {%{}, types}
    |> Ecto.Changeset.cast(words, Map.keys(types))
    |> Ecto.Changeset.validate_required(Map.keys(types))
  end

  defp to_words_form(words) do
    words
    |> validate_words()
    |> to_form(as: :words, action: :validate)
  end

  defp debug_mode_enabled?, do: Application.get_env(:jelly, :game_debug_enabled?, false)
end
