defmodule Jelly.Guess.Timer do
  @moduledoc """
  Implements a timer using GenServer were receive a total time in milliseconds,
  sends a message every second until the total time is 0, and implements the
  possibility to restart or cancel the timer
  """
  use GenServer
  import Jelly.Guess.Notifier
  require Logger

  @interval Application.compile_env(:jelly, :timer_interval) || 1_000

  @type option :: {:period, number()} | {:on_timeout, function()}

  @spec start_link(binary(), list(option)) :: GenServer.on_start()
  def start_link(code, opts) do
    GenServer.start_link(__MODULE__, {code, opts}, name: register_code(code))
  end

  def start(code), do: GenServer.call(register_code(code), :start_timer)

  def cancel(code), do: GenServer.call(register_code(code), :cancel_timer)

  def restart(code) do
    GenServer.call(register_code(code), :cancel_timer)
    GenServer.call(register_code(code), :start_timer)
  end

  def init({code, opts}) do
    {:ok,
     %{
       timer: nil,
       period: Keyword.fetch!(opts, :period),
       code: code,
       counter: nil,
       on_timeout: Keyword.fetch!(opts, :on_timeout)
     }}
  end

  def handle_call(:start_timer, _from, state) do
    if state.timer == nil do
      counter = state.period
      Logger.info("Start timer for the period: #{state.period}ms")
      {:ok, timer} = :timer.send_interval(@interval, :tick)
      broadcast(state.code, {:timer, counter})

      {:reply, :ok, %{state | timer: timer, counter: counter}}
    else
      {:reply, :already_started, state}
    end
  end

  def handle_call(:cancel_timer, _from, state) do
    if state.timer do
      :timer.cancel(state.timer)
      Logger.info("Canceled timer")
      broadcast(state.code, {:timer, 0})

      {:reply, :ok, %{state | timer: nil}}
    else
      {:reply, :not_started, state}
    end
  end

  # def handle_call(:restart_timer, _from, state) do
  #   counter = state.period

  #   {:ok, timer} =
  #     if state.timer == nil do
  #       Logger.info("Start timer for the period: #{state.period}ms")
  #       :timer.send_interval(@interval, :tick)
  #     else
  #       :timer.cancel(state.timer)
  #       Logger.info("Canceled timer")
  #       Logger.info("Start timer for the period: #{state.period}ms")
  #       :timer.send_interval(@interval, :tick)
  #     end

  #   broadcast(state.code, {:timer, counter})
  #   {:reply, :ok, %{state | timer: timer, counter: counter}}
  # end

  def handle_info(:tick, state) do
    counter = state.counter - @interval
    Logger.info("Timer counter: #{counter}")
    broadcast(state.code, {:timer, counter})

    case counter do
      0 ->
        Logger.info("Finished timer")
        :timer.cancel(state.timer)
        state.on_timeout.()

        {:noreply, %{state | timer: nil}}

      _ ->
        {:noreply, %{state | counter: counter}}
    end
  end

  defp register_code(code) do
    {:via, Registry, {Jelly.GameRegistry, {:timer, code}}}
  end
end
