# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     RailwayApp.Repo.insert!(%RailwayApp.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

import Ecto.Query
alias RailwayApp.Repo
alias RailwayApp.ServiceConfig

# Seed initial service configurations
# These can be customized based on your Railway services

# Only seed if the table is empty
if Repo.aggregate(ServiceConfig, :count) == 0 do
  IO.puts("Seeding initial service configurations...")

  # Example service config - customize based on your Railway project
  %ServiceConfig{}
  |> ServiceConfig.changeset(%{
    service_id: "default-service",
    service_name: "Default Service",
    auto_remediation_enabled: true,
    memory_scale_default: 2048,
    replica_scale_default: 2,
    llm_provider: "auto",
    confidence_threshold: 0.7
  })
  |> Repo.insert!()

  IO.puts("✓ Seeded service configurations")
else
  IO.puts("Service configurations already exist, skipping seed")
end
