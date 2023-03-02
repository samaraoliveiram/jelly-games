defmodule Jelly.Lobby do
  use GenServer

  alias Jelly.LobbySupervisor

  @code_length 10

  defstruct players: [], code: nil
  @type code :: binary()
  @type t :: %__MODULE__{code: code(), players: list()}

  @spec create(binary()) :: t()
  def create(player) do
    code = to_string(:rand.uniform(@code_length))

    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [code, player]},
      restart: :transient
    }

    case DynamicSupervisor.start_child(LobbySupervisor, spec) do
      {:ok, _pid} -> {:ok, code}
      error -> error
    end
  end

  @spec join(code(), binary()) :: {:ok, t()} | {:error, :not_found}
  def join(code, player) do
    case GenServer.whereis(via_tuple(code)) do
      nil -> {:error, :not_found}
      _ -> GenServer.call(via_tuple(code), {:join, player})
    end
  end

  @spec get(binary()) :: {:ok, t()} | {:error, :not_found}
  def get(code) do
    GenServer.call(via_tuple(code), :get)
  end

  @spec get(binary()) :: {:ok, t()} | {:error, :not_found}
  def close(code) do
    GenServer.stop(via_tuple(code), :close)
  end

  # GenServer code

  def start_link(code, player) do
    GenServer.start_link(__MODULE__, {code, player}, name: via_tuple(code))
  end

  def init({code, players}) do
    lobby = %__MODULE__{players: [players], code: code}
    {:ok, lobby}
  end

  def handle_call({:join, player}, _, lobby) do
    lobby = Map.update(lobby, :players, [], fn players -> [player | players] end)
    {:reply, {:ok, lobby}, lobby}
  end

  def handle_call(:get, _, lobby) do
    {:reply, lobby, lobby}
  end

  def handle_info(:end, _, lobby) do
    {:stop, :normal, lobby}
  end

  defp via_tuple(code) do
    {:via, Registry, {Jelly.LobbyRegistry, code}}
  end
end
