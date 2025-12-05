defmodule RailwayApp.Repo.Migrations.AddEnvironmentIdToIncidents do
  use Ecto.Migration

  def change do
    alter table(:incidents) do
      add :environment_id, :string
    end
  end
end
