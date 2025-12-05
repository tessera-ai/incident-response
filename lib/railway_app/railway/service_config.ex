defmodule RailwayApp.Railway.ServiceConfig do
  @moduledoc """
  Helper module for parsing and managing Railway service configurations.
  Supports both individual service configuration and bulk monitoring via environment variables.
  """

  require Logger

  def parse_monitored_services do
    projects_str = System.get_env("RAILWAY_MONITORED_PROJECTS") || ""
    environments_str = System.get_env("RAILWAY_MONITORED_ENVIRONMENTS") || ""
    services_str = System.get_env("RAILWAY_MONITORED_SERVICES") || ""

    projects =
      if projects_str != "" do
        projects_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
      else
        []
      end

    environments =
      if environments_str != "" do
        environments_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
      else
        # Default to production
        ["production"]
      end

    services =
      if services_str != "" do
        services_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
      else
        []
      end

    # Create service combinations (cartesian product of projects x environments x services)
    case {projects, environments, services} do
      {[], [], []} ->
        Logger.warning(
          "No RAILWAY_MONITORED_PROJECTS, RAILWAY_MONITORED_ENVIRONMENTS, or RAILWAY_MONITORED_SERVICES configured",
          %{}
        )

        []

      {[], [env], []} ->
        Logger.warning(
          "RAILWAY_MONITORED_ENVIRONMENTS set but no RAILWAY_MONITORED_PROJECTS - defaulting to current project",
          %{}
        )

        current_project = System.get_env("RAILWAY_PROJECT_ID")

        if current_project do
          [%{project_id: current_project, environment_id: env, service_id: nil}]
        else
          []
        end

      {[project], [], []} ->
        [%{project_id: project, environment_id: "production", service_id: nil}]

      {[project], [env], []} ->
        [%{project_id: project, environment_id: env, service_id: nil}]

      {projects, environments, []} ->
        # No services specified - create project/environment combinations without service IDs
        for proj <- projects, env <- environments do
          %{project_id: proj, environment_id: env, service_id: nil}
        end

      {projects, environments, services} ->
        # Full cartesian product: projects x environments x services
        for proj <- projects, env <- environments, svc <- services do
          %{project_id: proj, environment_id: env, service_id: svc}
        end
    end
  end

  @doc """
  Get current Railway project (where this app is deployed).
  """
  def current_project do
    System.get_env("RAILWAY_PROJECT_ID")
  end

  @doc """
  Get current Railway environment (where this app is deployed).
  """
  def current_environment do
    System.get_env("RAILWAY_ENVIRONMENT_ID")
  end

  @doc """
  Get WebSocket endpoint configuration.
  """
  def websocket_endpoint do
    System.get_env("RAILWAY_WS_ENDPOINT") || "wss://backboard.railway.app/graphql/v2"
  end

  @doc """
  Get GraphQL endpoint configuration.
  """
  def graphql_endpoint do
    System.get_env("RAILWAY_GRAPHQL_ENDPOINT") || "https://backboard.railway.app/graphql/v2"
  end

  @doc """
  Get Railway API token.
  """
  def api_token do
    System.get_env("RAILWAY_API_TOKEN")
  end

  @doc """
  Format service configuration for logging.
  """
  def format_for_log(service) do
    "#{service.project_id}/#{service.environment_id}"
  end
end
