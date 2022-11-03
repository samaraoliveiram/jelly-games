defmodule Jelly.Repo do
  use Ecto.Repo,
    otp_app: :jelly,
    adapter: Ecto.Adapters.Postgres
end
