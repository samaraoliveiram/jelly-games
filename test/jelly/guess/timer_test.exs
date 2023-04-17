defmodule Jelly.Guess.TimerTest do
  use ExUnit.Case
  alias Jelly.Guess.{Game, Timer, Notifier}

  setup do
    %{code: Game.gen_code()}
  end

  test "should start server", %{code: code} do
    opts = [period: 2, on_timeout: fn -> nil end]

    assert {:ok, _pid} = Timer.start_link(code, opts)
  end

  test "should start timer", %{code: code} do
    opts = [period: 2, on_timeout: fn -> nil end]
    Timer.start_link(code, opts)
    Notifier.subscribe(code)

    assert :ok = Timer.start(code)
    assert_receive {:timer, 2}
    assert_receive {:timer, 1}
    assert_receive {:timer, 0}
  end

  test "should not start timer if already started", %{code: code} do
    opts = [period: 1000, on_timeout: fn -> nil end]
    Timer.start_link(code, opts)
    Timer.start(code)

    assert :already_started = Timer.start(code)
  end

  test "should run callback when finish timer", %{code: code} do
    test = self()
    opts = [period: 1, on_timeout: fn -> send(test, :callback) end]

    Timer.start_link(code, opts)
    Notifier.subscribe(code)
    Timer.start(code)

    assert_receive {:timer, 0}
    assert_receive :callback
  end

  test "should cancel timer", %{code: code} do
    opts = [period: 1000, on_timeout: fn -> nil end]
    Timer.start_link(code, opts)
    Notifier.subscribe(code)
    Timer.start(code)

    assert :ok = Timer.cancel(code)
    assert_receive {:timer, 0}
  end

  test "should restart timer", %{code: code} do
    opts = [period: 1000, on_timeout: fn -> nil end]
    Timer.start_link(code, opts)
    Notifier.subscribe(code)
    Timer.start(code)

    assert :ok = Timer.restart(code)

    assert_receive {:timer, 0}
    assert_receive {:timer, 1000}
  end

  test "should restart timer when canceled", %{code: code} do
    opts = [period: 1000, on_timeout: fn -> nil end]
    Timer.start_link(code, opts)
    Notifier.subscribe(code)
    Timer.start(code)
    Timer.cancel(code)

    assert :ok = Timer.restart(code)

    assert_receive {:timer, 0}
    assert_receive {:timer, 1000}
  end
end
