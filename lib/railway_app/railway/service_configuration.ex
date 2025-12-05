defmodule RailwayApp.Railway.ServiceConfiguration do
  @moduledoc """
  Manages per-service monitoring configuration.

  This schema stores configurable settings for Railway service monitoring,
  including polling intervals, batch sizes, log level filters, and reconnection
  parameters. Supports the configurable requirements from FR-003 and FR-004.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "service_configurations" do
    field :project_id, :string
    field :service_id, :string
    field :service_name, :string
    field :enabled, :boolean, default: true
    field :polling_interval_seconds, :integer, default: 30
    field :batch_size, :integer, default: 100
    field :batch_window_seconds, :integer, default: 10
    field :log_level_filter, :string, default: "INFO"
    field :auto_reconnect, :boolean, default: true
    field :max_retry_attempts, :integer, default: 10
    field :retention_hours, :integer, default: 24
    field :severity_score, :integer, virtual: true

    timestamps()
  end

  @doc """
  Builds a changeset for service configuration.
  """
  def changeset(service_configuration, attrs) do
    service_configuration
    |> cast(attrs, [
      :service_id,
      :service_name,
      :enabled,
      :polling_interval_seconds,
      :batch_size,
      :batch_window_seconds,
      :log_level_filter,
      :auto_reconnect,
      :max_retry_attempts,
      :retention_hours
    ])
    |> validate_required([:service_id])
    |> validate_length(:service_id, max: 255)
    |> validate_length(:service_name, max: 255)
    |> validate_number(:polling_interval_seconds,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 60
    )
    |> validate_number(:batch_size, greater_than_or_equal_to: 10, less_than_or_equal_to: 1000)
    |> validate_number(:batch_window_seconds,
      greater_than_or_equal_to: 5,
      less_than_or_equal_to: 300
    )
    |> validate_inclusion(:log_level_filter, ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"])
    |> validate_number(:max_retry_attempts,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 20
    )
    # Max 7 days
    |> validate_number(:retention_hours, greater_than_or_equal_to: 1, less_than_or_equal_to: 168)
    |> unique_constraint(:service_id)
    |> set_log_level_severity()
  end

  @doc """
  Builds a changeset for creating a new service configuration.
  """
  def new_configuration_changeset(service_id, service_name \\ nil) do
    %__MODULE__{}
    |> change()
    |> put_change(:service_id, service_id)
    |> put_change(:service_name, service_name || service_id)
    |> put_change(:enabled, true)
    |> put_change(:polling_interval_seconds, 30)
    |> put_change(:batch_size, 100)
    |> put_change(:batch_window_seconds, 10)
    |> put_change(:log_level_filter, "INFO")
    |> put_change(:auto_reconnect, true)
    |> put_change(:max_retry_attempts, 10)
    |> put_change(:retention_hours, 24)
    |> validate_required([:service_id])
    |> unique_constraint(:service_id)
  end

  @doc """
  Builds a changeset for enabling/disabling monitoring.
  """
  def toggle_changeset(service_configuration, enabled) do
    service_configuration
    |> change()
    |> put_change(:enabled, enabled)
  end

  @doc """
  Builds a changeset for updating polling configuration.
  """
  def polling_changeset(service_configuration, polling_interval_seconds) do
    service_configuration
    |> change()
    |> put_change(:polling_interval_seconds, polling_interval_seconds)
    |> validate_number(:polling_interval_seconds,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 60
    )
  end

  @doc """
  Builds a changeset for updating batch configuration.
  """
  def batch_changeset(service_configuration, batch_size, batch_window_seconds) do
    service_configuration
    |> change()
    |> put_change(:batch_size, batch_size)
    |> put_change(:batch_window_seconds, batch_window_seconds)
    |> validate_number(:batch_size, greater_than_or_equal_to: 10, less_than_or_equal_to: 1000)
    |> validate_number(:batch_window_seconds,
      greater_than_or_equal_to: 5,
      less_than_or_equal_to: 300
    )
    |> validate_batch_window_compatibility(batch_size, batch_window_seconds)
  end

  @doc """
  Builds a changeset for updating log level filter.
  """
  def log_level_changeset(service_configuration, log_level_filter) do
    service_configuration
    |> change()
    |> put_change(:log_level_filter, String.upcase(log_level_filter))
    |> validate_inclusion(:log_level_filter, ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"])
    |> set_log_level_severity()
  end

  @doc """
  Builds a changeset for updating reconnection configuration.
  """
  def reconnection_changeset(service_configuration, auto_reconnect, max_retry_attempts) do
    service_configuration
    |> change()
    |> put_change(:auto_reconnect, auto_reconnect)
    |> put_change(:max_retry_attempts, max_retry_attempts)
    |> validate_number(:max_retry_attempts,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 20
    )
  end

  @doc """
  Builds a changeset for updating retention configuration.
  """
  def retention_changeset(service_configuration, retention_hours) do
    service_configuration
    |> change()
    |> put_change(:retention_hours, retention_hours)
    |> validate_number(:retention_hours, greater_than_or_equal_to: 1, less_than_or_equal_to: 168)
  end

  @doc """
  Returns true if the configuration is enabled and valid.
  """
  def enabled?(%__MODULE__{enabled: true}), do: true
  def enabled?(%__MODULE__{}), do: false

  @doc """
  Returns the minimum log severity level as an integer.
  """
  def min_severity(%__MODULE__{log_level_filter: log_level}) do
    case String.upcase(log_level) do
      "DEBUG" -> 1
      "INFO" -> 2
      "WARN" -> 3
      "ERROR" -> 4
      "FATAL" -> 5
      # Default to INFO
      _ -> 2
    end
  end

  @doc """
  Returns true if a log level meets the filter criteria.
  """
  def passes_log_level_filter?(%__MODULE__{log_level_filter: filter}, log_level) do
    filter_severity = min_severity(%__MODULE__{log_level_filter: filter})
    log_severity = log_level_severity(log_level)
    log_severity >= filter_severity
  end

  @doc """
  Calculates optimal batch size based on configuration and system load.
  """
  def optimal_batch_size(
        %__MODULE__{batch_size: batch_size, batch_window_seconds: window_seconds},
        events_per_second \\ 10
      ) do
    max_events_in_window = events_per_second * window_seconds
    min(batch_size, max_events_in_window)
  end

  @doc """
  Returns retention duration in milliseconds.
  """
  def retention_duration_ms(%__MODULE__{retention_hours: hours}) do
    hours * 60 * 60 * 1000
  end

  @doc """
  Returns polling interval in milliseconds.
  """
  def polling_interval_ms(%__MODULE__{polling_interval_seconds: seconds}) do
    seconds * 1000
  end

  @doc """
  Validates that the batch configuration is reasonable for typical workloads.
  """
  def reasonable_batch_configuration?(%__MODULE__{
        batch_size: batch_size,
        batch_window_seconds: window_seconds
      }) do
    # Avoid extremely small batches or very long windows
    batch_size >= 10 and batch_size <= 1000 and window_seconds >= 5 and window_seconds <= 300
  end

  def reasonable_batch_configuration?(%__MODULE__{}), do: false

  @doc """
  Formats configuration for display or API responses.
  """
  def format_for_display(%__MODULE__{} = config) do
    %{
      service_id: config.service_id,
      service_name: config.service_name,
      enabled: config.enabled,
      polling_interval_seconds: config.polling_interval_seconds,
      batch_size: config.batch_size,
      batch_window_seconds: config.batch_window_seconds,
      log_level_filter: config.log_level_filter,
      auto_reconnect: config.auto_reconnect,
      max_retry_attempts: config.max_retry_attempts,
      retention_hours: config.retention_hours,
      reasonable_batch_config: reasonable_batch_configuration?(config)
    }
  end

  @doc """
  Creates a map of configuration suitable for application config.
  """
  def to_application_config(%__MODULE__{} = config) do
    %{
      service_id: config.service_id,
      enabled: config.enabled,
      polling_interval_seconds: config.polling_interval_seconds,
      batch_min_size: 10,
      batch_max_size: config.batch_size,
      batch_window_seconds: config.batch_window_seconds,
      log_level_filter: config.log_level_filter,
      auto_reconnect: config.auto_reconnect,
      max_retry_attempts: config.max_retry_attempts,
      retention_hours: config.retention_hours
    }
  end

  # Private functions

  defp set_log_level_severity(changeset) do
    case get_field(changeset, :log_level_filter) do
      nil ->
        changeset

      level ->
        severity =
          case String.upcase(level) do
            "DEBUG" -> 1
            "INFO" -> 2
            "WARN" -> 3
            "ERROR" -> 4
            "FATAL" -> 5
            _ -> 2
          end

        put_change(changeset, :severity_score, severity)
    end
  end

  defp validate_batch_window_compatibility(changeset, batch_size, batch_window_seconds) do
    # Validate that batch size and window are compatible
    # For example, a very small batch with a very long window might not be optimal
    if batch_size < 50 and batch_window_seconds > 180 do
      add_error(
        changeset,
        :batch_window_seconds,
        "very long window with small batch size may be inefficient"
      )
    else
      changeset
    end
  end

  defp log_level_severity(level) when is_binary(level) do
    case String.upcase(level) do
      "DEBUG" -> 1
      "INFO" -> 2
      "WARN" -> 3
      "ERROR" -> 4
      "FATAL" -> 5
      _ -> 2
    end
  end

  defp log_level_severity(_), do: 2
end
