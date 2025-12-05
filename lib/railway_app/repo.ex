defmodule RailwayApp.Repo do
  use Ecto.Repo,
    otp_app: :railway_app,
    adapter: Ecto.Adapters.Postgres
end
