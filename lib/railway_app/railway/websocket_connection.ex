defmodule RailwayApp.Railway.WebSocketConnection do
  @moduledoc """
  Manages WebSocket connection state for Railway services.

  This schema tracks the status and health of WebSocket connections to Railway's
  GraphQL API, including connection attempts, heartbeat status, and error handling.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "websocket_connections" do
    field :service_id, :string
    field :endpoint, :string
    field :status, :string, default: "disconnected"
    field :last_heartbeat, :utc_datetime
    field :connection_attempts, :integer, default: 0
    field :last_error, :string
    field :backoff_interval, :integer, default: 5000

    timestamps()
  end

  @doc """
  Builds a changeset for a WebSocket connection.
  """
  def changeset(websocket_connection, attrs) do
    websocket_connection
    |> cast(attrs, [
      :service_id,
      :endpoint,
      :status,
      :last_heartbeat,
      :connection_attempts,
      :last_error,
      :backoff_interval
    ])
    |> validate_required([:service_id, :endpoint, :status])
    |> validate_inclusion(:status, ["connected", "disconnected", "connecting", "error"])
    |> validate_length(:service_id, max: 255)
    |> validate_length(:endpoint, max: 500)
    |> validate_number(:connection_attempts, greater_than_or_equal_to: 0)
    |> validate_number(:backoff_interval,
      greater_than_or_equal_to: 1000,
      less_than_or_equal_to: 300_000
    )
    |> validate_heartbeat()
  end

  @doc """
  Builds a changeset for creating a new WebSocket connection.
  """
  def new_connection_changeset(service_id, endpoint \\ "wss://backboard.railway.app/graphql/v2") do
    %__MODULE__{}
    |> change()
    |> put_change(:service_id, service_id)
    |> put_change(:endpoint, endpoint)
    |> put_change(:status, "disconnected")
    |> put_change(:connection_attempts, 0)
    |> put_change(:backoff_interval, 5000)
    |> validate_required([:service_id, :endpoint, :status])
  end

  @doc """
  Builds a changeset for updating connection status.
  """
  def status_changeset(websocket_connection, status, error \\ nil) do
    websocket_connection
    |> change()
    |> put_change(:status, status)
    |> put_change(:last_error, error)
    |> validate_inclusion(:status, ["connected", "disconnected", "connecting", "error"])
  end

  @doc """
  Builds a changeset for recording a connection attempt.
  """
  def attempt_changeset(websocket_connection) do
    current_attempts = websocket_connection.connection_attempts || 0

    websocket_connection
    |> change()
    |> put_change(:connection_attempts, current_attempts + 1)
    |> put_change(:status, "connecting")
    |> calculate_backoff_interval(current_attempts + 1)
  end

  @doc """
  Builds a changeset for recording a successful connection.
  """
  def success_changeset(websocket_connection) do
    websocket_connection
    |> change()
    |> put_change(:status, "connected")
    |> put_change(:last_error, nil)
    |> put_change(:connection_attempts, 0)
    |> put_change(:backoff_interval, 5000)
    |> put_change(:last_heartbeat, DateTime.utc_now())
  end

  @doc """
  Builds a changeset for recording a connection failure.
  """
  def failure_changeset(websocket_connection, error) do
    websocket_connection
    |> change()
    |> put_change(:status, "error")
    |> put_change(:last_error, error)
    |> calculate_backoff_interval(websocket_connection.connection_attempts + 1)
  end

  @doc """
  Builds a changeset for updating heartbeat.
  """
  def heartbeat_changeset(websocket_connection) do
    websocket_connection
    |> change()
    |> put_change(:last_heartbeat, DateTime.utc_now())
    |> put_change(:status, "connected")
    |> validate_heartbeat()
  end

  # Private functions

  defp validate_heartbeat(changeset) do
    case get_field(changeset, :last_heartbeat) do
      nil ->
        changeset

      %DateTime{} = dt ->
        # Ensure heartbeat is within reasonable time window (not too far in future)
        now = DateTime.utc_now()

        if DateTime.compare(dt, now) == :gt do
          add_error(changeset, :last_heartbeat, "cannot be in the future")
        else
          changeset
        end

      _ ->
        add_error(changeset, :last_heartbeat, "must be a valid DateTime")
    end
  end

  defp calculate_backoff_interval(changeset, attempts) do
    # Exponential backoff: 5s * 2^(attempts-1), max 60s
    base_interval = 5000
    max_interval = 60_000

    backoff =
      min(base_interval * :math.pow(2, attempts - 1), max_interval)
      |> round()

    put_change(changeset, :backoff_interval, backoff)
  end

  @doc """
  Returns true if the connection is healthy.
  """
  def healthy?(%__MODULE__{status: "connected"}), do: true
  def healthy?(%__MODULE__{last_heartbeat: nil}), do: false

  def healthy?(%__MODULE__{last_heartbeat: last_heartbeat}) do
    # Consider healthy if heartbeat was within last 2 minutes
    DateTime.compare(DateTime.add(last_heartbeat, 120, :second), DateTime.utc_now()) == :gt
  end

  def healthy?(_), do: false

  @doc """
  Returns true if the connection should be retried.
  """
  def should_retry?(%__MODULE__{status: "disconnected"}), do: true
  def should_retry?(%__MODULE__{status: "error"}), do: true
  def should_retry?(%__MODULE__{}), do: false

  @doc """
  Returns the next retry timestamp based on backoff interval.
  """
  def next_retry_at(%__MODULE__{backoff_interval: backoff_interval}) do
    DateTime.add(DateTime.utc_now(), backoff_interval, :millisecond)
  end

  @doc """
  Returns connection status formatted for display.
  """
  def status_display(%__MODULE__{} = connection) do
    %{
      service_id: connection.service_id,
      status: connection.status,
      last_heartbeat: connection.last_heartbeat,
      connection_attempts: connection.connection_attempts,
      backoff_interval: connection.backoff_interval,
      last_error: connection.last_error,
      healthy: healthy?(connection)
    }
  end
end
