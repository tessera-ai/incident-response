defmodule RailwayApp.Railway.WebSocketSupervisor do
  @moduledoc """
  Dynamic supervisor for Railway WebSocket connections.
  Manages individual WebSocket clients for each service being monitored.
  """

  use DynamicSupervisor
  require Logger

  @name __MODULE__

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: @name)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Start a WebSocket connection for a specific service.
  """
  def start_service_connection(project_id, service_id, token, opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, "wss://backboard.railway.app/graphql/v2")
    environment_id = Keyword.get(opts, :environment_id)

    child_spec = %{
      id: :"websocket_#{project_id}_#{service_id}",
      start: {
        RailwayApp.Railway.WebSocketClient,
        :start_link,
        [
          [
            project_id: project_id,
            service_id: service_id,
            environment_id: environment_id,
            token: token,
            endpoint: endpoint
          ]
        ]
      },
      restart: :transient,
      type: :worker
    }

    case DynamicSupervisor.start_child(@name, child_spec) do
      {:ok, pid} ->
        Logger.info("Started WebSocket connection for service #{service_id}")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.info("WebSocket connection for service #{service_id} already running")
        {:ok, pid}

      {:error, reason} ->
        Logger.error(
          "Failed to start WebSocket connection for service #{service_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Stop a WebSocket connection for a specific service.
  """
  def stop_service_connection(project_id, service_id) do
    child_id = :"websocket_#{project_id}_#{service_id}"

    case DynamicSupervisor.terminate_child(@name, child_id) do
      :ok ->
        Logger.info("Stopped WebSocket connection for service #{service_id}")
        :ok

      {:error, :not_found} ->
        Logger.warning("WebSocket connection for service #{service_id} not found", %{})
        {:error, :not_found}

      {:error, reason} ->
        Logger.error(
          "Failed to stop WebSocket connection for service #{service_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Get the PID of a WebSocket connection for a specific service.
  """
  def get_connection_pid(project_id, service_id) do
    child_id = :"websocket_#{project_id}_#{service_id}"

    case Registry.lookup(RailwayApp.Registry, child_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  List all active WebSocket connections.
  """
  def list_connections do
    DynamicSupervisor.which_children(@name)
    |> Enum.map(fn {id, pid, _, _} ->
      %{id: id, pid: pid}
    end)
  end

  @doc """
  Check if a service connection is active.
  """
  def connection_active?(project_id, service_id) do
    case get_connection_pid(project_id, service_id) do
      {:ok, _pid} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Subscribe to logs for a specific service.
  """
  def subscribe_to_logs(project_id, service_id, opts \\ []) do
    case get_connection_pid(project_id, service_id) do
      {:ok, pid} ->
        RailwayApp.Railway.WebSocketClient.subscribe_to_logs(pid, service_id, opts)
        {:ok, pid}

      {:error, :not_found} ->
        {:error, :connection_not_found}
    end
  end

  @doc """
  Unsubscribe from logs for a specific subscription.
  """
  def unsubscribe_from_logs(project_id, service_id, subscription_id) do
    case get_connection_pid(project_id, service_id) do
      {:ok, pid} ->
        RailwayApp.Railway.WebSocketClient.unsubscribe_from_logs(pid, subscription_id)
        :ok

      {:error, :not_found} ->
        {:error, :connection_not_found}
    end
  end

  @spec restart_service_connection(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, pid()} | {:error, term()}
  @doc """
  Restart a WebSocket connection for a service.
  """
  def restart_service_connection(project_id, service_id, token, opts \\ []) do
    # Get the PID first so we can monitor it
    pid =
      case get_connection_pid(project_id, service_id) do
        {:ok, pid} -> pid
        _ -> nil
      end

    if pid do
      ref = Process.monitor(pid)
      # Stop the existing connection
      stop_service_connection(project_id, service_id)

      # Wait for the process to actually terminate
      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} ->
          :ok
      after
        5000 ->
          Process.demonitor(ref, [:flush])

          Logger.warning(
            "Timed out waiting for WebSocket process #{inspect(pid)} to terminate",
            %{}
          )
      end
    else
      # Just try to stop to be safe (idempotent)
      stop_service_connection(project_id, service_id)
    end

    start_service_connection(project_id, service_id, token, opts)
  end

  @doc """
  Get connection statistics for all active connections.
  """
  def connection_stats do
    list_connections()
    |> Enum.map(fn %{id: id, pid: pid} ->
      %{
        id: id,
        pid: pid,
        alive?: Process.alive?(pid),
        connected?: RailwayApp.Railway.WebSocketClient.connected?(pid)
      }
    end)
  end

  @doc """
  Stop all WebSocket connections.
  """
  def stop_all_connections do
    list_connections()
    |> Enum.each(fn %{id: id} ->
      DynamicSupervisor.terminate_child(@name, id)
    end)

    Logger.info("Stopped all WebSocket connections")
  end
end
