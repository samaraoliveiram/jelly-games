get_game_live_processes = fn ->
  Process.list()
  |> Enum.filter(fn pid ->
    {_, value} = Process.info(pid, {:dictionary, :"$initial_call"})
    value == {JellyWeb.GameLive, :mount, 3}
  end)
end

get_current_player_from_pids = fn pids ->
  pids
  |> Enum.map(fn pid ->
    :sys.get_state(pid).socket.assigns.summary.current_player
  end)
end
