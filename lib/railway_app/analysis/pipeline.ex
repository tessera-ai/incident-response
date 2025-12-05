defmodule RailwayApp.Analysis.Pipeline do
  @moduledoc """
  Wires up PubSub topics and handles incident broadcast logic.
  """

  use GenServer
  require Logger

  alias RailwayApp.Alerts.SlackNotifier

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Subscribe to incident events
    Phoenix.PubSub.subscribe(RailwayApp.PubSub, "incidents:new")

    {:ok, %{}}
  end

  @impl true
  def handle_info({:incident_detected, incident}, state) do
    Logger.info("Pipeline received new incident: #{incident.id}")

    # Record incident detection
    :telemetry.execute(
      [:railway_agent, :incident, :detected],
      %{count: 1},
      %{severity: incident.severity, service_id: incident.service_id}
    )

    # Send Slack notification and measure latency
    start_time = System.monotonic_time()

    Task.Supervisor.start_child(RailwayApp.TaskSupervisor, fn ->
      case SlackNotifier.send_incident_alert(incident) do
        {:ok, _response} ->
          # Measure alert latency (SC-001)
          latency = System.monotonic_time() - start_time

          :telemetry.execute(
            [:railway_agent, :incident, :alert_latency],
            %{duration: latency},
            %{severity: incident.severity, service_id: incident.service_id}
          )

          Logger.info("Slack notification sent for incident #{incident.id}")

        {:error, reason} ->
          Logger.error("Failed to send Slack notification: #{inspect(reason)}")
      end
    end)

    # Broadcast to LiveView dashboard
    Phoenix.PubSub.broadcast(
      RailwayApp.PubSub,
      "dashboard:incidents",
      {:new_incident, incident}
    )

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unhandled message in Pipeline: #{inspect(msg)}")
    {:noreply, state}
  end
end
