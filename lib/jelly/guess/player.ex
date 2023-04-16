defmodule Jelly.Guess.Player do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :nickname, :string
    field :avatar, :string, default: "user"
  end

  @type t :: %__MODULE__{
          nickname: String.t(),
          avatar: String.t()
        }

  @spec new(map()) :: {:ok, Ecto.Schema.t()} | {:error, any()}
  def new(params \\ %{}) do
    %__MODULE__{}
    |> cast(params, [:nickname, :avatar])
    |> validate_required(:nickname)
    |> validate_length(:nickname, min: 3, max: 100)
    |> apply_action(:insert)
  end
end
