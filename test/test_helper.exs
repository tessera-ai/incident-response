skip_db = System.get_env("SKIP_DB") == "true"

if skip_db do
  ExUnit.configure(exclude: [:db])
end

# Ensure the application (and Repo) are started for DB-backed tests
unless skip_db do
  {:ok, _} = Application.ensure_all_started(:railway_app)
end

ExUnit.start()

# Only set up Ecto sandbox if database is not skipped
unless skip_db do
  try do
    Ecto.Adapters.SQL.Sandbox.mode(RailwayApp.Repo, :manual)
  rescue
    DBConnection.ConnectionError ->
      IO.puts("\n⚠️  Database not available - skipping sandbox setup")
      IO.puts("   Unit tests will run, but integration tests requiring database will fail\n")
  end
end
