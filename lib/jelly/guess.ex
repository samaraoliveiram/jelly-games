defmodule Jelly.Guess do
  @moduledoc """
  Game Server API
  It subscribes the caller automatically when server is started, then all events
  will be broadcasted
  """
  use GenServer
  alias Jelly.Guess.Notifier
  alias Jelly.Guess.{Game, Player, Timer}

  @timeout :timer.minutes(10)
  @supervisor Jelly.DynamicSupervisor
  @timer :timer.seconds(60)

  @spec new :: {:ok, binary()} | DynamicSupervisor.on_start_child()
  def new() do
    code = Game.gen_code()

    case DynamicSupervisor.start_child(@supervisor, child_spec(code)) do
      {:ok, _} -> {:ok, code}
      error -> error
    end
  end

  def subscribe(code) do
    Notifier.subscribe(code)
  end

  def get(code) do
    response = GenServer.whereis(register_name(code))

    if is_pid(response) do
      GenServer.call(register_name(code), :get)
    else
      {:error, :not_found}
    end
  end

  def exist?(code) do
    nil != GenServer.whereis(register_name(code))
  end

  @spec define_teams(binary(), [Player.t()]) :: {:ok, map()} | {:error, any()}
  def define_teams(code, players) do
    if length(players) >= 4 do
      GenServer.call(register_name(code), {:define_teams, players})
    else
      {:error, :not_enough_players}
    end
  end

  @spec put_words(binary(), [binary()], binary()) :: {:ok, map()} | {:error, any()}
  def put_words(code, words, player_id) do
    if length(words) >= 3 do
      GenServer.call(register_name(code), {:put_words, words, player_id})
    else
      {:error, :not_enough_words}
    end
  end

  @spec mark_point(binary()) :: {:ok, map()} | any()
  def mark_point(code), do: GenServer.call(register_name(code), :mark_point)

  def next_phase(code), do: GenServer.cast(register_name(code), :next_phase)

  @spec switch_team(binary()) :: {:ok, map()} | any()
  def switch_team(code), do: GenServer.cast(register_name(code), :switch_team)

  def restart(code), do: GenServer.call(register_name(code), :restart)

  @doc false
  def start_link(code) do
    game =
      case :ets.lookup(:games_table, code) do
        [] ->
          game = Game.new(code)
          update_backup(game)
          game

        [{^code, game}] ->
          game
      end

    GenServer.start_link(__MODULE__, game, name: register_name(code))
  end

  defp register_name(code) do
    {:via, Registry, {Jelly.GameRegistry, code}}
  end

  # Server code
  @impl true
  def init(game) do
    Timer.start_link(game.code, period: @timer, on_timeout: fn -> switch_team(game.code) end)
    Process.send_after(self(), :timeout, :timer.minutes(60))
    {:ok, game, @timeout}
  end

  @impl true
  def handle_call(:get, _, game) do
    {:reply, {:ok, summary(game)}, game, @timeout}
  end

  @impl true
  def handle_call({:define_teams, players}, _, game) do
    game = Game.define_teams(game, players)

    handle_instructions(game, broadcast: :game_updated)

    update_backup(game)
    {:reply, {:ok, summary(game)}, game, @timeout}
  end

  @impl true
  def handle_call({:put_words, words, player_id}, _, game) do
    updated_game = Game.put_words(game, words, player_id)

    if different_phase?(updated_game, game) do
      handle_instructions(updated_game, broadcast: :game_updated, timer: :start)
    else
      handle_instructions(updated_game, broadcast: :game_updated)
    end

    update_backup(updated_game)
    {:reply, {:ok, summary(updated_game)}, updated_game, @timeout}
  end

  @impl true
  def handle_call(:mark_point, _, game) do
    updated_game = Game.mark_team_point(game)

    messages =
      cond do
        updated_game.winner != nil ->
          [timer: :cancel, broadcast: :game_updated]

        different_phase?(updated_game, game) ->
          [timer: :cancel, broadcast: :game_updated]

        true ->
          [broadcast: :game_updated]
      end

    handle_instructions(updated_game, messages)

    update_backup(updated_game)

    {:reply, {:ok, summary(updated_game)}, updated_game, @timeout}
  end

  @impl true
  def handle_call(:restart, _, game) do
    game = Game.new(game.code)
    handle_instructions(game, broadcast: :game_updated)

    {:reply, {:ok, summary(game)}, game, @timeout}
  end

  def handle_cast(:next_phase, game) do
    game = Game.set_next_phase(game)
    handle_instructions(game, broadcast: :game_updated, timer: :start)

    {:noreply, game, @timeout}
  end

  @impl true
  def handle_cast(:switch_team, game) do
    game = Game.switch_teams(game)

    handle_instructions(game, broadcast: :game_updated, timer: :restart)
    update_backup(game)
    {:noreply, game, @timeout}
  end

  @impl true
  def handle_info(:timeout, game) do
    handle_instructions(game, broadcast: :shutdown)
    {:stop, {:shutdown, :timeout}, game}
  end

  @impl true
  def terminate({:shutdown, :timeout}, game) do
    # terminate is not garantee to be called, maybe define later a TTL for ETS
    # backup is deleted only in a normal exit
    delete_backup(game.code)
    :ok
  end

  def terminate(_reason, _game) do
    :ok
  end

  defp update_backup(game), do: :ets.insert(:games_table, {game.code, game})

  defp delete_backup(code), do: :ets.delete(:games_table, code)

  defp handle_instructions(game, instructions) do
    Enum.each(instructions, fn instruction ->
      case instruction do
        {:broadcast, message} ->
          Notifier.broadcast(game.code, {message, summary(game)})

        {:timer, message} ->
          timer(message, game)
      end
    end)
  end

  defp timer(instruction, game) do
    case instruction do
      :start -> Timer.start(game.code)
      :restart -> Timer.restart(game.code)
      :cancel -> Timer.cancel(game.code)
    end
  end

  defp summary(game) do
    current_team = List.first(game.teams, %{})

    %{
      code: game.code,
      teams: game.teams,
      players: game.players,
      sent_words: Map.get(game, :sent_words, []),
      current_phase: List.first(game.phases),
      next_phase: Enum.at(game.phases, 1),
      current_team: Map.get(current_team, :name),
      current_player: Map.get(current_team, :remaining_players, []) |> List.first(%{}),
      current_word: List.first(game.remaining_words),
      winner: game.winner
    }
  end

  defp different_phase?(new_game, old_game) do
    length(new_game.phases) != length(old_game.phases)
  end

  defp child_spec(code) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [code]},
      restart: :transient
    }
  end
end
