defmodule RailwayAppWeb.HealthController do
  use RailwayAppWeb, :controller

  @moduledoc """
  Health check endpoint for Railway and monitoring.
  Returns status of critical components.
  """

  swagger_path :index do
    get("/health")
    summary("Get application health status")
    description("Returns the health status of the application and its components")
    produces("application/json")
    response(200, "Success", %Schema{type: "object", "$ref": "#/definitions/HealthResponse"})
  end

  def index(conn, _params) do
    # For Railway health check, just check if the application is running
    # Database connection might fail during cold starts, so we'll be more lenient
    components = %{
      app: "ok",
      database: check_database(),
      log_stream: check_log_stream()
    }

    # For Railway, we consider the app healthy if it can start and respond
    # Database connectivity issues during startup should not cause 503s
    status = "ok"

    conn
    |> put_status(200)
    |> json(%{
      status: status,
      components: components
    })
  end

  defp check_database do
    try do
      case Ecto.Adapters.SQL.query(RailwayApp.Repo, "SELECT 1", [], timeout: 1000) do
        {:ok, _} -> "ok"
        {:error, _} -> "degraded"
      end
    rescue
      DBConnection.ConnectionError -> "degraded"
      _ -> "error"
    end
  end

  defp check_log_stream do
    # Check if the WebSocket client process is running
    case Process.whereis(RailwayApp.Railway.WebSocketClient) do
      nil -> "degraded"
      _pid -> "ok"
    end
  rescue
    _ -> "degraded"
  end
end
