defmodule RailwayApp.Railway.ConnectionMetrics do
  @moduledoc """
  Tracks real-time performance metrics for Railway connections.

  This schema stores aggregated metrics including connection uptime, processing
  rates, latency measurements, and system resource usage per the specifications.
  Used for monitoring system health and performance analytics.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "connection_metrics" do
    field :service_id, :string
    field :timestamp, :utc_datetime
    field :uptime_percentage, :float, default: 0.0
    field :events_processed_per_minute, :integer, default: 0
    field :average_latency_ms, :float, default: 0.0
    field :error_rate, :float, default: 0.0
    field :buffer_size, :integer, default: 0
    field :memory_usage_mb, :float, default: 0.0

    timestamps()
  end

  @doc """
  Builds a changeset for connection metrics.
  """
  def changeset(connection_metrics, attrs) do
    connection_metrics
    |> cast(attrs, [
      :service_id,
      :timestamp,
      :uptime_percentage,
      :events_processed_per_minute,
      :average_latency_ms,
      :error_rate,
      :buffer_size,
      :memory_usage_mb
    ])
    |> validate_required([:service_id, :timestamp])
    |> validate_length(:service_id, max: 255)
    |> validate_number(:uptime_percentage,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 100.0
    )
    |> validate_number(:events_processed_per_minute, greater_than_or_equal_to: 0)
    |> validate_number(:average_latency_ms, greater_than_or_equal_to: 0.0)
    |> validate_number(:error_rate, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> validate_number(:buffer_size, greater_than_or_equal_to: 0)
    |> validate_number(:memory_usage_mb, greater_than_or_equal_to: 0.0)
    |> validate_timestamp()
    |> validate_performance_requirements()
  end

  @doc """
  Builds a changeset for creating new metrics.
  """
  def new_metrics_changeset(service_id) do
    %__MODULE__{}
    |> change()
    |> put_change(:service_id, service_id)
    |> put_change(:timestamp, DateTime.utc_now())
    |> put_change(:uptime_percentage, 0.0)
    |> put_change(:events_processed_per_minute, 0)
    |> put_change(:average_latency_ms, 0.0)
    |> put_change(:error_rate, 0.0)
    |> put_change(:buffer_size, 0)
    |> put_change(:memory_usage_mb, 0.0)
    |> validate_required([:service_id, :timestamp])
  end

  @doc """
  Builds a changeset for updating connection uptime metrics.
  """
  def uptime_changeset(metrics, uptime_percentage) do
    metrics
    |> change()
    |> put_change(:uptime_percentage, uptime_percentage)
    |> put_change(:timestamp, DateTime.utc_now())
    |> validate_number(:uptime_percentage,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 100.0
    )
  end

  @doc """
  Builds a changeset for updating processing metrics.
  """
  def processing_metrics_changeset(metrics, events_per_minute, average_latency_ms) do
    metrics
    |> change()
    |> put_change(:events_processed_per_minute, events_per_minute)
    |> put_change(:average_latency_ms, average_latency_ms)
    |> put_change(:timestamp, DateTime.utc_now())
    |> validate_number(:events_processed_per_minute, greater_than_or_equal_to: 0)
    |> validate_number(:average_latency_ms, greater_than_or_equal_to: 0.0)
    |> validate_latency_requirement(average_latency_ms)
  end

  @doc """
  Builds a changeset for updating error rate metrics.
  """
  def error_rate_changeset(metrics, error_rate) do
    metrics
    |> change()
    |> put_change(:error_rate, error_rate)
    |> put_change(:timestamp, DateTime.utc_now())
    |> validate_number(:error_rate, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
  end

  @doc """
  Builds a changeset for updating resource usage metrics.
  """
  def resource_metrics_changeset(metrics, buffer_size, memory_usage_mb) do
    metrics
    |> change()
    |> put_change(:buffer_size, buffer_size)
    |> put_change(:memory_usage_mb, memory_usage_mb)
    |> put_change(:timestamp, DateTime.utc_now())
    |> validate_number(:buffer_size, greater_than_or_equal_to: 0)
    |> validate_number(:memory_usage_mb, greater_than_or_equal_to: 0.0)
    |> validate_memory_requirement(memory_usage_mb)
  end

  @doc """
  Returns true if metrics meet performance requirements per specifications.
  """
  def meets_requirements?(%__MODULE__{} = metrics) do
    meets_latency_requirements?(metrics) and
      meets_memory_requirements?(metrics) and
      meets_throughput_requirements?(metrics)
  end

  @doc """
  Returns true if latency meets <10 second requirement per SC-002.
  """
  def meets_latency_requirements?(%__MODULE__{average_latency_ms: latency}) do
    # 10 seconds in milliseconds
    latency <= 10000
  end

  def meets_latency_requirements?(%__MODULE__{}), do: false

  @doc """
  Returns true if memory usage meets <512MB requirement per plan.md.
  """
  def meets_memory_requirements?(%__MODULE__{memory_usage_mb: memory_mb}) do
    memory_mb <= 512
  end

  def meets_memory_requirements?(%__MODULE__{}), do: false

  @doc """
  Returns true if throughput meets 1000 events/minute requirement per SC-003.
  """
  def meets_throughput_requirements?(%__MODULE__{events_processed_per_minute: events_per_min}) do
    events_per_min >= 1000
  end

  def meets_throughput_requirements?(%__MODULE__{}), do: false

  @doc """
  Returns true if uptime meets 99% requirement per SC-001.
  """
  def meets_uptime_requirements?(%__MODULE__{uptime_percentage: uptime}) do
    uptime >= 99.0
  end

  def meets_uptime_requirements?(%__MODULE__{}), do: false

  @doc """
  Calculates overall health score (0-100) based on all metrics.
  """
  def health_score(%__MODULE__{} = metrics) do
    uptime_score = metrics.uptime_percentage * 0.3
    latency_score = if meets_latency_requirements?(metrics), do: 100, else: 50
    memory_score = if meets_memory_requirements?(metrics), do: 100, else: 50
    throughput_score = if meets_throughput_requirements?(metrics), do: 100, else: 50
    error_score = (100 - metrics.error_rate) * 0.2

    total_score =
      uptime_score + latency_score * 0.2 + memory_score * 0.2 + throughput_score * 0.2 +
        error_score

    min(total_score, 100)
    |> round()
  end

  @doc """
  Returns formatted metrics for display or monitoring.
  """
  def format_for_display(%__MODULE__{} = metrics) do
    %{
      service_id: metrics.service_id,
      timestamp: metrics.timestamp,
      uptime_percentage: metrics.uptime_percentage,
      events_per_minute: metrics.events_processed_per_minute,
      average_latency_ms: metrics.average_latency_ms,
      error_rate: metrics.error_rate,
      buffer_size: metrics.buffer_size,
      memory_usage_mb: metrics.memory_usage_mb,
      health_score: health_score(metrics),
      meets_requirements: meets_requirements?(metrics)
    }
  end

  @doc """
  Aggregates multiple metrics records into a summary.
  """
  def aggregate_metrics(metrics_list) when is_list(metrics_list) do
    if length(metrics_list) == 0 do
      %{
        count: 0,
        avg_uptime: 0.0,
        avg_latency: 0.0,
        avg_events_per_minute: 0,
        avg_error_rate: 0.0,
        max_memory_usage: 0.0,
        max_buffer_size: 0
      }
    else
      count = length(metrics_list)

      %{
        count: count,
        avg_uptime: Enum.sum(Enum.map(metrics_list, & &1.uptime_percentage)) / count,
        avg_latency: Enum.sum(Enum.map(metrics_list, & &1.average_latency_ms)) / count,
        avg_events_per_minute:
          round(Enum.sum(Enum.map(metrics_list, & &1.events_processed_per_minute)) / count),
        avg_error_rate: Enum.sum(Enum.map(metrics_list, & &1.error_rate)) / count,
        max_memory_usage: Enum.max(Enum.map(metrics_list, & &1.memory_usage_mb)),
        max_buffer_size: Enum.max(Enum.map(metrics_list, & &1.buffer_size))
      }
    end
  end

  # Private functions

  defp validate_timestamp(changeset) do
    case get_field(changeset, :timestamp) do
      nil ->
        add_error(changeset, :timestamp, "is required")

      %DateTime{} ->
        changeset

      _ ->
        add_error(changeset, :timestamp, "must be a valid DateTime")
    end
  end

  defp validate_performance_requirements(changeset) do
    latency = get_field(changeset, :average_latency_ms)
    memory = get_field(changeset, :memory_usage_mb)
    events_per_min = get_field(changeset, :events_processed_per_minute)

    changeset
    |> validate_latency_requirement(latency)
    |> validate_memory_requirement(memory)
    |> validate_throughput_requirement(events_per_min)
  end

  defp validate_latency_requirement(changeset, nil), do: changeset

  defp validate_latency_requirement(changeset, latency) when is_number(latency) do
    if latency > 10000 do
      add_error(changeset, :average_latency_ms, "must be <= 10000ms per performance requirements")
    else
      changeset
    end
  end

  defp validate_latency_requirement(changeset, _), do: changeset

  defp validate_memory_requirement(changeset, nil), do: changeset

  defp validate_memory_requirement(changeset, memory_mb) when is_number(memory_mb) do
    if memory_mb > 512 do
      add_error(changeset, :memory_usage_mb, "must be <= 512MB per performance requirements")
    else
      changeset
    end
  end

  defp validate_memory_requirement(changeset, _), do: changeset

  defp validate_throughput_requirement(changeset, nil), do: changeset

  defp validate_throughput_requirement(changeset, events_per_min)
       when is_number(events_per_min) do
    if events_per_min < 1000 do
      add_error(
        changeset,
        :events_processed_per_minute,
        "should be >= 1000 per performance requirements"
      )
    else
      changeset
    end
  end

  defp validate_throughput_requirement(changeset, _), do: changeset
end
