defmodule Jelly.Guess.Player do
  @moduledoc false

  defstruct nickname: nil, avatar: nil, id: nil

  @type t :: %__MODULE__{
          nickname: binary(),
          avatar: binary()
        }

  @spec new(binary(), binary()) :: t()
  def new(nickname, avatar \\ "user") do
    %__MODULE__{
      nickname: nickname,
      avatar: avatar,
      id: Ecto.UUID.generate()
    }
  end
end
