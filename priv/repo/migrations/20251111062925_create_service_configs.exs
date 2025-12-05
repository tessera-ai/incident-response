defmodule RailwayApp.Repo.Migrations.CreateServiceConfigs do
  use Ecto.Migration

  def change do
    create table(:service_configs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :service_id, :string, null: false
      add :service_name, :string, null: false
      add :auto_remediation_enabled, :boolean, default: true, null: false
      add :memory_scale_default, :integer
      add :replica_scale_default, :integer

      add :llm_provider, :string,
        default: "auto",
        null: false,
        comment: "LLM provider: openai, anthropic, auto"

      add :confidence_threshold, :float, default: 0.7, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:service_configs, [:service_id])
  end
end
