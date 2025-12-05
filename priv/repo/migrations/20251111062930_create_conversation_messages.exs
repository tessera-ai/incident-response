defmodule RailwayApp.Repo.Migrations.CreateConversationMessages do
  use Ecto.Migration

  def change do
    create table(:conversation_messages, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :session_id, references(:conversation_sessions, type: :uuid, on_delete: :delete_all),
        null: false

      add :role, :string, null: false
      add :content, :text, null: false
      add :timestamp, :utc_datetime, null: false
      add :action_ref, :uuid

      timestamps(type: :utc_datetime)
    end

    create index(:conversation_messages, [:session_id, :timestamp])
    create index(:conversation_messages, [:action_ref])
  end
end
