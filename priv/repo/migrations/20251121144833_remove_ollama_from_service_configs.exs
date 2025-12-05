defmodule RailwayApp.Repo.Migrations.RemoveOllamaFromServiceConfigs do
  use Ecto.Migration

  def up do
    # Update any existing records that have ollama as provider
    execute "UPDATE service_configs SET llm_provider = 'auto' WHERE llm_provider = 'ollama'"

    # Add a check constraint to prevent future ollama values
    execute "ALTER TABLE service_configs ADD CONSTRAINT check_llm_provider CHECK (llm_provider IN ('openai', 'anthropic', 'auto'))"
  end

  def down do
    execute "ALTER TABLE service_configs DROP CONSTRAINT check_llm_provider"
  end
end
