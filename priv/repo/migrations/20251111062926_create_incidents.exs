defmodule RailwayApp.Repo.Migrations.CreateIncidents do
  use Ecto.Migration

  def change do
    create table(:incidents, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :service_id, :string, null: false
      add :service_name, :string, null: false
      add :signature, :string, null: false
      add :severity, :string, null: false
      add :status, :string, null: false, default: "detected"
      add :confidence, :float
      add :root_cause, :text
      add :recommended_action, :string, null: false
      add :reasoning, :text
      add :log_context, :map
      add :detected_at, :utc_datetime, null: false
      add :resolved_at, :utc_datetime
      add :metadata, :map

      add :service_config_id, references(:service_configs, type: :uuid, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:incidents, [:service_id, :signature])
    create index(:incidents, [:service_config_id])
    create index(:incidents, [:status])
    create index(:incidents, [:detected_at])
  end
end
