skip_db = System.get_env("SKIP_DB") == "true"

if skip_db do
  ExUnit.configure(exclude: [:db])
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
