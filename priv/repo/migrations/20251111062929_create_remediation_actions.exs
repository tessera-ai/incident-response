defmodule RailwayApp.Repo.Migrations.CreateRemediationActions do
  use Ecto.Migration

  def change do
    create table(:remediation_actions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :incident_id, references(:incidents, type: :uuid, on_delete: :delete_all), null: false
      add :initiator_type, :string, null: false
      add :initiator_ref, :string
      add :action_type, :string, null: false
      add :parameters, :map
      add :requested_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      add :status, :string, null: false, default: "pending"
      add :result_message, :text
      add :failure_reason, :text

      timestamps(type: :utc_datetime)
    end

    create index(:remediation_actions, [:incident_id, :inserted_at])
    create index(:remediation_actions, [:status])
  end
end
