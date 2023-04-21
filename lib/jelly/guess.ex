defmodule Jelly.Guess do
  @moduledoc """
  Game Server API
  It subscribes the caller automatically when server is started, then all events
  will be broadcasted
  """
  use GenServer
  import Jelly.Guess.Notifier
  alias Jelly.Guess.{Game, Player, Timer}

  @timeout 300_000
  @supervisor Jelly.DynamicSupervisor
  @timer 60_000

  @spec new :: {:ok, binary()}
  def new() do
    code = Game.gen_code()
    DynamicSupervisor.start_child(@supervisor, child_spec(code))
    subscribe(code)
    {:ok, code}
  end

  def get(code) do
    response = GenServer.whereis(register_name(code))

    if is_pid(response) do
      {:ok, response}
    else
      {:error, :not_found}
    end
  end

  @spec define_teams(binary(), [Player.t()]) :: {:ok, map()} | {:error, any()}
  def define_teams(code, players) do
    if length(players) >= 4 do
      GenServer.call(register_name(code), {:define_teams, players})
    else
      {:error, :not_enough_players}
    end
  end

  @spec put_words(binary(), [binary()]) :: {:ok, map()} | {:error, any()}
  def put_words(code, words) do
    if length(words) >= 3 do
      GenServer.call(register_name(code), {:put_words, words})
    else
      {:error, :not_enough_words}
    end
  end

  @spec mark_point(binary()) :: {:ok, map()} | any()
  def mark_point(code), do: GenServer.call(register_name(code), :mark_point)

  @spec switch_team(binary()) :: {:ok, map()} | any()
  def switch_team(code), do: GenServer.call(register_name(code), :switch_team)

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
    {:ok, game, @timeout}
  end

  @impl true
  def handle_call({:define_teams, players}, _, game) do
    game = Game.define_teams(game, players)

    handle_instructions(game, [{:broadcast, :move_phase}])

    update_backup(game)
    {:reply, {:ok, summary(game)}, game, @timeout}
  end

  @impl true
  def handle_call({:put_words, words}, _, game) do
    updated_game = Game.put_words(game, words)

    if different_phase?(updated_game, game) do
      handle_instructions(updated_game, [{:broadcast, :move_phase}, {:timer, :start}])
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
          [broadcast: :mark_point, broadcast: :end_game]

        different_phase?(updated_game, game) ->
          [timer: :cancel, broadcast: :mark_point, broadcast: :move_phase]

        true ->
          [broadcast: :mark_point]
      end

    handle_instructions(updated_game, messages)

    update_backup(updated_game)

    {:reply, {:ok, summary(updated_game)}, updated_game, @timeout}
  end

  @impl true
  def handle_call(:switch_team, _, game) do
    game = Game.switch_teams(game)

    handle_instructions(game, [{:broadcast, :switch_team}, {:timer, :restart}])
    update_backup(game)
    {:reply, {:ok, summary(game)}, game, @timeout}
  end

  @impl true
  def handle_info(:timeout, game) do
    {:stop, {:shutdown, :timeout}, game}
  end

  @impl true
  def terminate({:shutdown, :timeout}, %{code: code}) do
    # terminate is not garantee to be called, maybe define later a TTL for ETS
    delete_backup(code)
    :ok
  end

  defp update_backup(game), do: :ets.insert(:games_table, {game.code, game})

  defp delete_backup(code), do: :ets.delete(:games_table, code)

  defp handle_instructions(game, instructions) do
    Enum.each(instructions, fn instruction ->
      case instruction do
        {:broadcast, message} ->
          broadcast(game.code, {message, summary(game)})

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
    current_team = List.first(game.teams)

    %{
      code: game.code,
      teams: game.teams,
      current_phase: List.first(game.phases),
      current_team: current_team.name,
      current_player: List.first(current_team.remaining_players).id,
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
