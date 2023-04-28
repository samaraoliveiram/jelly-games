defmodule JellyWeb.GameLive do
  use JellyWeb, :live_view

  alias Jelly.Guess

  def mount(%{"id" => game_code}, _session, socket) do
    if connected?(socket) do
      Guess.subscribe(game_code)
    end

    case Guess.get(game_code) do
      {:ok, summary} ->
        {:ok, assign(socket, players: %{}, summary: summary, words_done: false, timer: 0)}

      _ ->
        socket = put_flash(socket, :error, "Game no longer available")
        {:ok, redirect(socket, to: "/session/delete")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="h-full p-10">
      <.button phx-click="exit">Exit</.button>
      <div class="grid gap-y-4 sm:gap-x-4 grid-cols-1 sm:grid-cols-3 ">
        <div class="panel">
          <.live_component
            id="presences"
            module={JellyWeb.PresencesComponent}
            game_code={@game_code}
            player={@player}
          />
        </div>
        <div class="panel col-span-2">
          <div :if={@summary.winner == nil}>
            <.button :if={@summary.current_phase == :defining_teams} phx-click="start">Start</.button>
            <.words_form :if={@summary.current_phase == :word_selection} words_done={@words_done} />
            <div :if={@summary.current_phase in [:password, :mimicry, :one_password]}>
              <.timer :if={@timer > 0} timer={@timer} />
              <p>Phase: <%= @summary.current_phase %></p>
              <p>Current team: <%= @summary.current_team %></p>
              <p>
                Current player: <%= get_in(@players, [@summary.current_player, Access.key!(:nickname)]) %>
              </p>
              <div :if={@player.id == @summary.current_player}>
                <p class="text-lg">É a sua vez!</p>
                <p class="text-xl"><%= @summary.current_word %></p>
                <.button phx-click="point">Correct guess</.button>
              </div>
            </div>
          </div>
          <div :if={@summary.winner != nil}>
            <p class="4xl">Winner: <%= @summary.winner %></p>
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

  def handle_event("exit", _params, socket) do
    {:noreply, redirect(socket, to: ~p"/session/delete")}
  end

  def handle_event("start", _params, socket) do
    players = Map.values(socket.assigns.players)

    case Guess.define_teams(socket.assigns.game_code, players) do
      {:error, :not_enough_players} ->
        {:noreply, put_flash(socket, :error, "Need 4 players to start")}

      {:ok, summary} ->
        {:noreply, assign(socket, summary: summary)}
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

  def handle_info({:game_updated, summary}, socket) do
    {:noreply, assign(socket, summary: summary)}
  end

  def handle_info(%{event: "presence_diff", payload: payload}, socket) do
    send_update(JellyWeb.PresencesComponent, id: "presences", payload: payload)
    {:noreply, socket}
  end

  def handle_info({:presences, players}, socket) do
    # players = Map.merge(socket.assigns.players, players)
    {:noreply, assign(socket, :players, players)}
  end

  def handle_info({:timer, count}, socket) do
    count = System.convert_time_unit(count, :millisecond, :second)
    {:noreply, assign(socket, :timer, count)}
  end

  def handle_info({:shutdown, _summary}, socket) do
    socket = put_flash(socket, :error, "Game no longer available")
    {:noreply, redirect(socket, to: ~p"/session/delete")}
  end
end