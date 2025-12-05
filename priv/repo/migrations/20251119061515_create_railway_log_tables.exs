defmodule RailwayApp.Repo.Migrations.CreateRailwayLogTables do
  use Ecto.Migration

  def change do
    # Log Events table - stores normalized Railway log entries
    create table(:log_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :service_id, :string, null: false, size: 255
      add :timestamp, :utc_datetime, null: false
      add :level, :string, null: false, size: 10
      add :message, :text, null: false
      add :raw_metadata, :map, default: %{}
      add :processed_at, :utc_datetime
      add :batch_id, :binary_id
      add :service_name, :string, size: 255
      add :environment_id, :string, size: 255
      add :source, :string, size: 100
      add :severity_score, :integer, default: 1

      timestamps()
    end

    # WebSocket Connections table - tracks connection state
    create table(:websocket_connections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :service_id, :string, null: false, size: 255
      add :endpoint, :string, null: false
      add :status, :string, null: false, size: 20, default: "disconnected"
      add :last_heartbeat, :utc_datetime
      add :connection_attempts, :integer, default: 0
      add :last_error, :string
      add :backoff_interval, :integer, default: 5000

      timestamps()
    end

    # Ingestion Batches table - groups log events for processing
    create table(:ingestion_batches, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :service_id, :string, null: false, size: 255
      add :event_count, :integer, null: false, default: 0
      add :size_bytes, :integer, null: false, default: 0
      add :status, :string, null: false, size: 20, default: "pending"
      add :processed_at, :utc_datetime
      add :processing_duration_ms, :integer
      add :error_message, :string

      timestamps()
    end

    # Connection Metrics table - stores performance metrics
    create table(:connection_metrics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :service_id, :string, null: false, size: 255
      add :timestamp, :utc_datetime, null: false
      add :uptime_percentage, :float, default: 0.0
      add :events_processed_per_minute, :integer, default: 0
      add :average_latency_ms, :float, default: 0.0
      add :error_rate, :float, default: 0.0
      add :buffer_size, :integer, default: 0
      add :memory_usage_mb, :float, default: 0.0

      timestamps()
    end

    # Service Configuration table - stores per-service settings
    create table(:service_configurations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :service_id, :string, null: false, size: 255, unique: true
      add :service_name, :string, size: 255
      add :enabled, :boolean, default: true
      add :polling_interval_seconds, :integer, default: 30
      add :batch_size, :integer, default: 100
      add :batch_window_seconds, :integer, default: 10
      add :log_level_filter, :string, size: 10, default: "INFO"
      add :auto_reconnect, :boolean, default: true
      add :max_retry_attempts, :integer, default: 10
      add :retention_hours, :integer, default: 24

      timestamps()
    end

    # Create indexes for optimal query performance
    create index(:log_events, [:service_id, :timestamp])
    create index(:log_events, [:batch_id])
    create index(:log_events, [:level])
    create index(:log_events, [:severity_score])

    create index(:websocket_connections, [:service_id, :status])
    create index(:websocket_connections, [:last_heartbeat])

    create index(:ingestion_batches, [:service_id, :inserted_at])
    create index(:ingestion_batches, [:status])

    create index(:connection_metrics, [:service_id, :timestamp])
    create index(:connection_metrics, [:timestamp])

    create index(:service_configurations, [:service_id], unique: true)
    create index(:service_configurations, [:enabled])
  end
end
