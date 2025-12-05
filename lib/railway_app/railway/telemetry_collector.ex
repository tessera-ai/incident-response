defmodule RailwayApp.Railway.TelemetryCollector do
  @moduledoc """
  Collects and reports telemetry metrics for Railway WebSocket connections
  and log processing as specified in requirements.

  Metrics Collected:
  - SC-001: Alert latency (incident detection to Slack notification)
  - SC-003: Remediation latency (action request to completion)
  - SC-004: Command latency (conversational command to response)
  - Connection health and performance metrics
  - Log ingestion and processing metrics
  """

  use GenServer
  require Logger

  # 15 seconds
  @metrics_collection_interval 15_000

  defmodule State do
    @moduledoc false
    defstruct connection_metrics: %{},
              incident_metrics: %{},
              remediation_metrics: %{},
              conversation_metrics: %{},
              system_metrics: %{},
              last_collection: nil
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Record a WebSocket connection event.
  """
  def record_connection_event(project_id, service_id, event, metadata \\ %{}) do
    :telemetry.execute([:railway_agent, :websocket, event], metadata, %{
      project_id: project_id,
      service_id: service_id,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Record an incident detection event.
  """
  def record_incident_detected(incident_id, severity, metadata \\ %{}) do
    :telemetry.execute(
      [:railway_agent, :incident, :detected],
      %{
        incident_id: incident_id,
        severity: severity,
        timestamp: DateTime.utc_now()
      },
      metadata
    )
  end

  @doc """
  Record an incident resolution event.
  """
  def record_incident_resolved(incident_id, resolution_time_ms, metadata \\ %{}) do
    :telemetry.execute(
      [:railway_agent, :incident, :resolved],
      %{
        incident_id: incident_id,
        resolution_time_ms: resolution_time_ms,
        timestamp: DateTime.utc_now()
      },
      metadata
    )
  end

  @doc """
  Record a remediation execution event.
  """
  def record_remediation_executed(action_type, execution_time_ms, status, metadata \\ %{}) do
    :telemetry.execute(
      [:railway_agent, :remediation, :executed],
      %{
        action_type: action_type,
        execution_time_ms: execution_time_ms,
        status: status,
        timestamp: DateTime.utc_now()
      },
      metadata
    )
  end

  @doc """
  Record a conversation command event.
  """
  def record_conversation_command(command, response_time_ms, metadata \\ %{}) do
    :telemetry.execute(
      [:railway_agent, :conversation, :command],
      %{
        command: command,
        response_time_ms: response_time_ms,
        timestamp: DateTime.utc_now()
      },
      metadata
    )
  end

  @doc """
  Record log processing metrics.
  """
  def record_log_processing(count, processing_time_ms, metadata \\ %{}) do
    :telemetry.execute(
      [:railway_agent, :logs, :processed],
      %{
        count: count,
        processing_time_ms: processing_time_ms,
        timestamp: DateTime.utc_now()
      },
      metadata
    )
  end

  @doc """
  Get current metrics summary.
  """
  def get_metrics_summary do
    GenServer.call(__MODULE__, :get_metrics_summary)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Subscribe to telemetry events
    :telemetry.attach_many(
      "railway-telemetry-collector",
      [
        [:railway_agent, :websocket, :connected],
        [:railway_agent, :websocket, :disconnected],
        [:railway_agent, :websocket, :message_received],
        [:railway_agent, :incident, :detected],
        [:railway_agent, :incident, :resolved],
        [:railway_agent, :remediation, :executed],
        [:railway_agent, :conversation, :command],
        [:railway_agent, :logs, :processed]
      ],
      &handle_telemetry_event/4,
      nil
    )

    # Schedule periodic metrics collection
    schedule_metrics_collection()

    state = %State{
      last_collection: DateTime.utc_now()
    }

    Logger.info("Railway telemetry collector started")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_metrics_summary, _from, state) do
    summary = %{
      connections: summarize_connection_metrics(state.connection_metrics),
      incidents: summarize_incident_metrics(state.incident_metrics),
      remediation: summarize_remediation_metrics(state.remediation_metrics),
      conversation: summarize_conversation_metrics(state.conversation_metrics),
      system: summarize_system_metrics(state.system_metrics),
      last_updated: state.last_collection
    }

    {:reply, summary, state}
  end

  @impl true
  def handle_info(:collect_metrics, state) do
    new_state = collect_and_store_metrics(state)
    schedule_metrics_collection()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private Functions

  defp handle_telemetry_event(event_name, measurements, metadata, _config) do
    GenServer.cast(__MODULE__, {:telemetry_event, event_name, measurements, metadata})
  end

  @impl true
  def handle_cast({:telemetry_event, event_name, measurements, metadata}, state) do
    new_state = process_telemetry_event(state, event_name, measurements, metadata)
    {:noreply, new_state}
  end

  defp process_telemetry_event(
         state,
         [:railway_agent, :websocket, event_type],
         _measurements,
         metadata
       ) do
    service_key = "#{metadata.project_id}:#{metadata.service_id}"

    connection_metrics =
      Map.put_new(state.connection_metrics, service_key, %{
        connected_at: nil,
        disconnected_at: nil,
        message_count: 0,
        last_message_at: nil,
        total_downtime_ms: 0
      })

    updated_metrics =
      case event_type do
        :connected ->
          updated_conn_metrics = %{
            connection_metrics[service_key]
            | connected_at: DateTime.utc_now(),
              message_count: 0
          }

          new_conn_metrics = Map.put(state.connection_metrics, service_key, updated_conn_metrics)

          # Report to Telemetry for metrics collection
          :telemetry.execute(
            [:railway_agent, :websocket, :connected],
            %{
              count: 1
            },
            %{service_id: metadata.service_id}
          )

          {updated_conn_metrics, %{state | connection_metrics: new_conn_metrics}}

        :disconnected ->
          updated_conn_metrics = %{
            connection_metrics[service_key]
            | disconnected_at: DateTime.utc_now()
          }

          new_conn_metrics = Map.put(state.connection_metrics, service_key, updated_conn_metrics)

          # Report to Telemetry for metrics collection
          :telemetry.execute(
            [:railway_agent, :websocket, :disconnected],
            %{
              count: 1
            },
            %{service_id: metadata.service_id}
          )

          {updated_conn_metrics, %{state | connection_metrics: new_conn_metrics}}

        :message_received ->
          updated_conn_metrics = %{
            connection_metrics[service_key]
            | message_count: connection_metrics[service_key].message_count + 1,
              last_message_at: DateTime.utc_now()
          }

          new_conn_metrics = Map.put(state.connection_metrics, service_key, updated_conn_metrics)

          {updated_conn_metrics, %{state | connection_metrics: new_conn_metrics}}

        _ ->
          {connection_metrics[service_key], state}
      end

    # Update state with the processed metrics
    %{state | connection_metrics: Map.put(state.connection_metrics, service_key, updated_metrics)}
  end

  defp process_telemetry_event(
         state,
         [:railway_agent, :incident, event_type],
         measurements,
         metadata
       ) do
    # Get incident_id from metadata instead of measurements
    incident_id = Map.get(metadata, :incident_id)

    # Skip processing if no incident_id is provided
    if is_nil(incident_id) do
      Logger.warning("Missing incident_id in telemetry event metadata: #{inspect(metadata)}", %{})
      state
    else
      case event_type do
        :detected ->
          updated_incident_metrics =
            Map.put(state.incident_metrics, incident_id, %{
              detected_at: DateTime.utc_now(),
              severity: Map.get(metadata, :severity),
              resolved_at: nil,
              resolution_time_ms: nil,
              metadata: metadata
            })

          %{state | incident_metrics: updated_incident_metrics}

        :resolved ->
          existing_incident = Map.get(state.incident_metrics, incident_id, %{})

          updated_incident_metrics =
            Map.put(state.incident_metrics, incident_id, %{
              existing_incident
              | resolved_at: DateTime.utc_now(),
                resolution_time_ms: Map.get(measurements, :resolution_time_ms)
            })

          %{state | incident_metrics: updated_incident_metrics}
      end
    end
  end

  defp process_telemetry_event(
         state,
         [:railway_agent, :remediation, :executed],
         measurements,
         metadata
       ) do
    remediation_id = System.unique_integer([:positive]) |> to_string()

    updated_remediation_metrics =
      Map.put(state.remediation_metrics, remediation_id, %{
        action_type: measurements.action_type,
        execution_time_ms: measurements.execution_time_ms,
        status: measurements.status,
        timestamp: measurements.timestamp,
        metadata: metadata
      })

    %{state | remediation_metrics: updated_remediation_metrics}
  end

  defp process_telemetry_event(
         state,
         [:railway_agent, :conversation, :command],
         measurements,
         metadata
       ) do
    conversation_id = System.unique_integer([:positive]) |> to_string()

    updated_conversation_metrics =
      Map.put(state.conversation_metrics, conversation_id, %{
        command: measurements.command,
        response_time_ms: measurements.response_time_ms,
        timestamp: measurements.timestamp,
        metadata: metadata
      })

    %{state | conversation_metrics: updated_conversation_metrics}
  end

  defp process_telemetry_event(
         state,
         [:railway_agent, :logs, :processed],
         measurements,
         _metadata
       ) do
    updated_system_metrics =
      Map.put(state.system_metrics, :logs_processed, %{
        total_count:
          (state.system_metrics[:logs_processed][:total_count] || 0) + measurements.count,
        total_processing_time_ms:
          (state.system_metrics[:logs_processed][:total_processing_time_ms] || 0) +
            measurements.processing_time_ms,
        last_batch_at: measurements.timestamp
      })

    %{state | system_metrics: updated_system_metrics}
  end

  defp process_telemetry_event(state, _event_name, _measurements, _metadata) do
    state
  end

  defp schedule_metrics_collection do
    Process.send_after(self(), :collect_metrics, @metrics_collection_interval)
  end

  defp collect_and_store_metrics(state) do
    # Collect WebSocket connection stats
    connection_stats = RailwayApp.Railway.WebSocketSupervisor.connection_stats()

    # Update connection metrics based on current stats
    updated_connection_metrics =
      update_connection_metrics_from_stats(
        state.connection_metrics,
        connection_stats
      )

    # Metrics are collected and held in memory. For long-term persistence,
    # consider storing to database or external metrics service.

    %{state | connection_metrics: updated_connection_metrics, last_collection: DateTime.utc_now()}
  end

  defp update_connection_metrics_from_stats(current_metrics, connection_stats) do
    Enum.reduce(connection_stats, current_metrics, fn %{
                                                        id: id,
                                                        alive?: alive,
                                                        connected?: connected
                                                      },
                                                      acc ->
      # Extract project_id and service_id from the connection ID
      case parse_connection_id(id) do
        {:ok, project_id, service_id} ->
          service_key = "#{project_id}:#{service_id}"

          current_metric =
            Map.get(acc, service_key, %{
              connected_at: nil,
              disconnected_at: nil,
              message_count: 0,
              last_message_at: nil,
              total_downtime_ms: 0
            })

          updated_metric =
            case {alive, connected} do
              {true, true} ->
                # Connection is healthy
                if is_nil(current_metric.connected_at) do
                  %{current_metric | connected_at: DateTime.utc_now()}
                else
                  current_metric
                end

              {false, _} ->
                # Connection is dead
                if current_metric.connected_at && is_nil(current_metric.disconnected_at) do
                  %{current_metric | disconnected_at: DateTime.utc_now()}
                else
                  current_metric
                end

              _ ->
                current_metric
            end

          Map.put(acc, service_key, updated_metric)

        {:error, _} ->
          acc
      end
    end)
  end

  defp parse_connection_id(
         <<"websocket_", project_id::binary-size(36), "_", service_id::binary-size(36)>>
       ) do
    {:ok, project_id, service_id}
  end

  defp parse_connection_id(_), do: {:error, :invalid_format}

  # Summary functions for API responses

  defp summarize_connection_metrics(metrics) do
    total_connections = map_size(metrics)

    active_connections =
      Enum.count(metrics, fn {_key, metric} ->
        metric.connected_at && is_nil(metric.disconnected_at)
      end)

    %{
      total: total_connections,
      active: active_connections,
      inactive: total_connections - active_connections,
      uptime_percentage:
        if(total_connections > 0, do: active_connections / total_connections * 100, else: 0)
    }
  end

  defp summarize_incident_metrics(metrics) do
    total_incidents = map_size(metrics)
    resolved_incidents = Enum.count(metrics, fn {_key, metric} -> metric.resolved_at end)

    %{
      total: total_incidents,
      resolved: resolved_incidents,
      active: total_incidents - resolved_incidents,
      average_resolution_time_ms: calculate_average_resolution_time(metrics)
    }
  end

  defp summarize_remediation_metrics(metrics) do
    total_remediations = map_size(metrics)

    successful_remediations =
      Enum.count(metrics, fn {_key, metric} -> metric.status == :success end)

    %{
      total: total_remediations,
      successful: successful_remediations,
      failed: total_remediations - successful_remediations,
      success_rate:
        if(total_remediations > 0,
          do: successful_remediations / total_remediations * 100,
          else: 0
        ),
      average_execution_time_ms: calculate_average_execution_time(metrics)
    }
  end

  defp summarize_conversation_metrics(metrics) do
    total_conversations = map_size(metrics)

    %{
      total: total_conversations,
      average_response_time_ms: calculate_average_conversation_time(metrics)
    }
  end

  defp summarize_system_metrics(metrics) do
    log_processing = Map.get(metrics, :logs_processed, %{})

    %{
      logs_processed_total: Map.get(log_processing, :total_count, 0),
      average_processing_time_ms:
        if(Map.get(log_processing, :total_count, 0) > 0,
          do:
            Map.get(log_processing, :total_processing_time_ms, 0) /
              Map.get(log_processing, :total_count, 1),
          else: 0
        )
    }
  end

  defp calculate_average_resolution_time(metrics) do
    resolved_metrics =
      Enum.filter(metrics, fn {_key, metric} ->
        metric.resolved_at && metric.resolution_time_ms
      end)

    if length(resolved_metrics) > 0 do
      total_time =
        resolved_metrics
        |> Enum.map(fn {_key, metric} -> metric.resolution_time_ms end)
        |> Enum.sum()

      total_time / length(resolved_metrics)
    else
      0
    end
  end

  defp calculate_average_execution_time(metrics) do
    if map_size(metrics) > 0 do
      total_time =
        metrics
        |> Enum.map(fn {_key, metric} -> metric.execution_time_ms end)
        |> Enum.sum()

      total_time / map_size(metrics)
    else
      0
    end
  end

  defp calculate_average_conversation_time(metrics) do
    if map_size(metrics) > 0 do
      total_time =
        metrics
        |> Enum.map(fn {_key, metric} -> metric.response_time_ms end)
        |> Enum.sum()

      total_time / map_size(metrics)
    else
      0
    end
  end
end
