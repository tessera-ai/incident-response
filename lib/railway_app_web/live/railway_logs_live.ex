defmodule RailwayAppWeb.RailwayLogsLive do
  @moduledoc """
  LiveView for real-time Railway log streaming with performance monitoring
  and incident detection as specified in requirements.

  Key Features:
  - SC-001: Real-time log display with subscription management
  - SC-002: WebSocket connection status indicator
  - SC-004: Incident detection and alert latency tracking
  - SC-005: Configurable log level filtering and search
  """

  use RailwayAppWeb, :live_view
  require Logger

  @default_log_level "info"
  @max_display_logs 100

  def mount(%{"project_id" => project_id, "service_id" => service_id} = _params, _session, socket) do
    # Verify user has access to this project/service
    if authorized?(project_id, socket) do
      # Subscribe to real-time log updates for this service
      Phoenix.PubSub.subscribe(RailwayApp.PubSub, "railway:logs:#{service_id}")

      # Subscribe to connection status updates
      Phoenix.PubSub.subscribe(RailwayApp.PubSub, "railway:connections:#{project_id}")

      # Initialize connection manager if not already running
      start_connection_manager_if_needed(project_id)

      socket =
        socket
        |> assign(:project_id, project_id)
        |> assign(:service_id, service_id)
        |> assign(:logs, [])
        |> assign(:filtered_logs, [])
        |> assign(:connection_status, :disconnected)
        |> assign(:subscription_count, 0)
        |> assign(:log_level_filter, @default_log_level)
        |> assign(:search_query, "")
        |> assign(:auto_scroll, true)
        |> assign(:show_incidents, false)
        |> assign(:incidents, [])
        |> assign(:metrics, %{
          total_logs: 0,
          error_count: 0,
          warning_count: 0,
          last_log_time: nil,
          logs_per_minute: 0
        })
        |> assign(:loading, true)

      # Start monitoring this service
      start_service_monitoring(project_id, service_id)

      {:ok, socket}
    else
      {:ok, redirect(socket, to: "/unauthorized")}
    end
  end

  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Railway Logs - #{socket.assigns.service_id}")
  end

  defp apply_action(socket, :settings, _params) do
    socket
    |> assign(:page_title, "Log Settings - #{socket.assigns.service_id}")
  end

  # Event Handlers

  def handle_event("toggle_auto_scroll", _params, socket) do
    new_auto_scroll = !socket.assigns.auto_scroll

    {:noreply, assign(socket, :auto_scroll, new_auto_scroll)}
  end

  def handle_event("filter_by_level", %{"level" => level}, socket) do
    socket =
      socket
      |> assign(:log_level_filter, level)
      |> apply_filters()

    {:noreply, socket}
  end

  def handle_event("search_logs", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> apply_filters()

    {:noreply, socket}
  end

  def handle_event("clear_logs", _params, socket) do
    socket =
      socket
      |> assign(:logs, [])
      |> assign(:filtered_logs, [])
      |> assign(:metrics, %{
        total_logs: 0,
        error_count: 0,
        warning_count: 0,
        last_log_time: nil,
        logs_per_minute: 0
      })

    {:noreply, socket}
  end

  def handle_event("toggle_incidents", _params, socket) do
    new_show_incidents = !socket.assigns.show_incidents

    {:noreply, assign(socket, :show_incidents, new_show_incidents)}
  end

  def handle_event("start_monitoring", _params, socket) do
    start_service_monitoring(socket.assigns.project_id, socket.assigns.service_id)

    {:noreply, put_flash(socket, :info, "Started monitoring service")}
  end

  def handle_event("stop_monitoring", _params, socket) do
    stop_service_monitoring(socket.assigns.project_id, socket.assigns.service_id)

    {:noreply, put_flash(socket, :info, "Stopped monitoring service")}
  end

  def handle_event("reconnect_service", _params, socket) do
    RailwayApp.Railway.ConnectionManager.reconnect_service(
      socket.assigns.project_id,
      socket.assigns.service_id
    )

    {:noreply, put_flash(socket, :info, "Attempting to reconnect...")}
  end

  # PubSub Handlers

  def handle_info({:log_event, log_event}, socket) do
    if log_event.service_id == socket.assigns.service_id do
      new_socket =
        socket
        |> add_log_entry(log_event)
        |> update_metrics(log_event)
        |> check_for_incidents(log_event)
        |> apply_filters()

      # Auto-scroll if enabled
      if new_socket.assigns.auto_scroll do
        push_event(new_socket, "scroll_to_bottom", %{})
      end

      {:noreply, new_socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:connection_status, status}, socket) do
    {:noreply, assign(socket, :connection_status, status)}
  end

  def handle_info({:subscription_count, count}, socket) do
    {:noreply, assign(socket, :subscription_count, count)}
  end

  def handle_info({:incident_detected, incident}, socket) do
    new_incidents = [incident | socket.assigns.incidents]

    socket =
      socket
      # Keep last 10 incidents
      |> assign(:incidents, Enum.take(new_incidents, 10))
      |> put_flash(:error, "Incident detected: #{incident.description}")

    {:noreply, socket}
  end

  # Private Functions

  defp authorized?(_project_id, socket) do
    # Implement authorization logic here
    # For now, assume authorized if user is logged in
    socket.assigns.current_user != nil
  end

  defp start_connection_manager_if_needed(project_id) do
    case Process.whereis(:"connection_manager_#{project_id}") do
      nil ->
        DynamicSupervisor.start_child(
          RailwayApp.Supervisor,
          {RailwayApp.Railway.ConnectionManager, project_id: project_id}
        )

      _pid ->
        :already_started
    end
  end

  defp start_service_monitoring(project_id, service_id) do
    config = %{
      auto_subscribe: true,
      log_retention_hours: 24,
      state_poll_interval: 30_000,
      websocket_endpoint:
        System.get_env("RAILWAY_WEBSOCKET_ENDPOINT", "wss://backboard.railway.app/graphql/v2")
    }

    RailwayApp.Railway.ConnectionManager.start_service_monitoring(
      project_id,
      service_id,
      config
    )
  end

  defp stop_service_monitoring(project_id, service_id) do
    RailwayApp.Railway.ConnectionManager.stop_service_monitoring(
      project_id,
      service_id
    )
  end

  defp add_log_entry(socket, log_event) do
    new_log = %{
      id: log_event.id || generate_log_id(),
      timestamp: log_event.timestamp || DateTime.utc_now(),
      level: log_event.level || "info",
      message: log_event.message,
      service_id: log_event.service_id,
      service_name: log_event.service_name,
      severity_score: log_event.severity_score || 1
    }

    updated_logs =
      [new_log | socket.assigns.logs]
      # Keep only the most recent logs
      |> Enum.take(@max_display_logs)

    assign(socket, :logs, updated_logs)
  end

  defp update_metrics(socket, log_event) do
    current_metrics = socket.assigns.metrics

    new_metrics = %{
      current_metrics
      | total_logs: current_metrics.total_logs + 1,
        error_count:
          current_metrics.error_count + if(log_event.level in ["error", "fatal"], do: 1, else: 0),
        warning_count:
          current_metrics.warning_count + if(log_event.level == "warn", do: 1, else: 0),
        last_log_time: log_event.timestamp || DateTime.utc_now(),
        logs_per_minute: calculate_logs_per_minute(current_metrics)
    }

    assign(socket, :metrics, new_metrics)
  end

  defp apply_filters(socket) do
    filtered_logs =
      socket.assigns.logs
      |> filter_by_level(socket.assigns.log_level_filter)
      |> filter_by_search(socket.assigns.search_query)

    assign(socket, :filtered_logs, filtered_logs)
  end

  defp filter_by_level(logs, "all"), do: logs

  defp filter_by_level(logs, level) do
    Enum.filter(logs, fn log ->
      log.level == level or meets_level_requirement?(log.level, level)
    end)
  end

  defp filter_by_search(logs, ""), do: logs

  defp filter_by_search(logs, query) do
    search_term = String.downcase(query)

    Enum.filter(logs, fn log ->
      String.contains?(String.downcase(log.message), search_term) or
        String.contains?(String.downcase(log.service_name || ""), search_term)
    end)
  end

  defp meets_level_requirement?(log_level, filter_level) do
    levels = %{"debug" => 1, "info" => 2, "warn" => 3, "error" => 4, "fatal" => 5}

    levels[log_level] >= levels[filter_level]
  end

  defp check_for_incidents(socket, log_event) do
    # Simple incident detection based on error patterns
    if should_trigger_incident?(log_event) do
      incident = %{
        id: generate_incident_id(),
        service_id: log_event.service_id,
        severity: determine_incident_severity(log_event),
        description: generate_incident_description(log_event),
        triggered_at: DateTime.utc_now(),
        log_id: log_event.id
      }

      # Send to incident detection pipeline
      send(self(), {:incident_detected, incident})

      socket
    else
      socket
    end
  end

  defp should_trigger_incident?(log_event) do
    # Trigger incidents for high-severity logs or repeated errors
    log_event.level in ["error", "fatal"] or
      String.contains?(String.downcase(log_event.message), "critical") or
      String.contains?(String.downcase(log_event.message), "exception")
  end

  defp determine_incident_severity(log_event) do
    case log_event.level do
      "fatal" -> :critical
      "error" -> :high
      "warn" -> :medium
      _ -> :low
    end
  end

  defp generate_incident_description(log_event) do
    "High severity log detected: #{String.slice(log_event.message, 0, 100)}"
  end

  defp calculate_logs_per_minute(_metrics) do
    # This would calculate actual logs per minute based on recent logs
    # For now, return a placeholder
    0
  end

  defp generate_log_id, do: System.unique_integer([:positive]) |> to_string()
  defp generate_incident_id, do: System.unique_integer([:positive]) |> to_string()

  # Render helpers

  def format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M:%S")
  end

  def get_log_level_color("debug"), do: "text-gray-500"
  def get_log_level_color("info"), do: "text-blue-500"
  def get_log_level_color("warn"), do: "text-yellow-500"
  def get_log_level_color("error"), do: "text-red-500"
  def get_log_level_color("fatal"), do: "text-purple-500"
  def get_log_level_color(_), do: "text-gray-500"

  def get_connection_status_icon(:connected), do: "🟢"
  def get_connection_status_icon(:connecting), do: "🟡"
  def get_connection_status_icon(:disconnected), do: "🔴"
  def get_connection_status_icon(:error), do: "❌"
  def get_connection_status_icon(_), do: "⚪"
end
