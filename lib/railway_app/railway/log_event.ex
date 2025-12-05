defmodule RailwayApp.Railway.LogEvent do
  @moduledoc """
  Represents a normalized log event from Railway services.

  This schema stores structured log data received from Railway WebSocket subscriptions,
  including timestamps, service identifiers, log levels, and processing metadata.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "log_events" do
    field :service_id, :string
    field :timestamp, :utc_datetime
    field :level, :string
    field :message, :string
    field :raw_metadata, :map, default: %{}
    field :processed_at, :utc_datetime
    field :service_name, :string
    field :environment_id, :string
    field :source, :string
    field :severity_score, :integer, default: 1

    timestamps()
  end

  @doc """
  Builds a changeset for a log event.
  """
  def changeset(log_event, attrs) do
    log_event
    |> cast(attrs, [
      :service_id,
      :timestamp,
      :level,
      :message,
      :raw_metadata,
      :processed_at,
      :service_name,
      :environment_id,
      :source,
      :severity_score
    ])
    |> validate_required([:service_id, :timestamp, :level, :message])
    |> validate_inclusion(:level, ["debug", "info", "warn", "error", "fatal"])
    |> validate_length(:service_id, max: 255)
    |> validate_length(:message, max: 10_000)
    |> validate_length(:service_name, max: 255)
    |> validate_length(:environment_id, max: 255)
    |> validate_length(:source, max: 100)
    |> validate_number(:severity_score, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_timestamp()
    |> set_severity_score()
  end

  @doc """
  Builds a changeset for creating a log event from raw Railway log data.
  """
  def from_raw_log_changeset(raw_log) do
    %__MODULE__{}
    |> change()
    |> put_change(:service_id, Map.get(raw_log, "serviceId"))
    |> put_change(:timestamp, parse_timestamp(Map.get(raw_log, "timestamp")))
    |> put_change(:level, String.downcase(Map.get(raw_log, "level", "info")))
    |> put_change(:message, Map.get(raw_log, "message"))
    |> put_change(:raw_metadata, Map.get(raw_log, "metadata", %{}))
    |> put_change(:service_name, Map.get(raw_log, "serviceName"))
    |> put_change(:environment_id, Map.get(raw_log, "environmentId"))
    |> put_change(:source, Map.get(raw_log, "source"))
    |> validate_required([:service_id, :timestamp, :level, :message])
    |> validate_inclusion(:level, ["debug", "info", "warn", "error", "fatal"])
    |> set_severity_score()
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

  defp set_severity_score(changeset) do
    case get_field(changeset, :level) do
      "debug" -> put_change(changeset, :severity_score, 1)
      "info" -> put_change(changeset, :severity_score, 2)
      "warn" -> put_change(changeset, :severity_score, 3)
      "error" -> put_change(changeset, :severity_score, 4)
      "fatal" -> put_change(changeset, :severity_score, 5)
      _ -> changeset
    end
  end

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(timestamp_string) when is_binary(timestamp_string) do
    case DateTime.from_iso8601(timestamp_string) do
      {:ok, dt} -> dt
      {:error, _} -> nil
    end
  end

  defp parse_timestamp(%DateTime{} = dt), do: dt
  defp parse_timestamp(_), do: nil

  @doc """
  Returns the log level as an atom for easier pattern matching.
  """
  def level_atom(%__MODULE__{level: level}) do
    String.to_atom(level)
  end

  @doc """
  Returns true if the log level meets or exceeds the minimum severity.
  """
  def meets_severity?(%__MODULE__{severity_score: score}, minimum_score) do
    score >= minimum_score
  end

  @doc """
  Formats the log event for display purposes.
  """
  def format_for_display(%__MODULE__{} = log_event) do
    %{
      id: log_event.id,
      service: log_event.service_name || log_event.service_id,
      timestamp: log_event.timestamp,
      level: String.upcase(log_event.level),
      message: String.slice(log_event.message, 0, 200) |> String.trim_trailing(),
      severity: log_event.severity_score
    }
  end
end
