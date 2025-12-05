defmodule RailwayApp.Repo.Migrations.CreateConversationSessions do
  use Ecto.Migration

  def change do
    create table(:conversation_sessions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :incident_id, references(:incidents, type: :uuid, on_delete: :nilify_all)
      add :channel, :string, null: false
      add :channel_ref, :string, null: false
      add :participant_id, :string, null: false
      add :started_at, :utc_datetime, null: false
      add :closed_at, :utc_datetime
      add :context, :map

      timestamps(type: :utc_datetime)
    end

    create index(:conversation_sessions, [:incident_id])
    create index(:conversation_sessions, [:channel_ref])
  end
end
