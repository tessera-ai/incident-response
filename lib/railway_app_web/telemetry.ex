defmodule RailwayAppWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("railway_app.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("railway_app.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("railway_app.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("railway_app.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("railway_app.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Railway Agent Custom Metrics
      # SC-001: Alert latency (incident detection to Slack notification)
      distribution("railway_agent.incident.alert_latency",
        unit: {:native, :millisecond},
        description: "Time from incident detection to Slack alert sent",
        reporter_options: [buckets: [100, 500, 1000, 5000, 10_000, 30_000, 60_000]]
      ),
      counter("railway_agent.incident.detected",
        tags: [:severity, :service_id],
        description: "Total number of incidents detected"
      ),
      counter("railway_agent.incident.resolved",
        tags: [:status, :service_id],
        description: "Total number of incidents resolved"
      ),

      # SC-003: Remediation latency (action request to completion)
      distribution("railway_agent.remediation.latency",
        unit: {:native, :millisecond},
        description: "Time from remediation request to completion",
        reporter_options: [buckets: [100, 500, 1000, 5000, 10_000, 30_000, 60_000]]
      ),
      counter("railway_agent.remediation.executed",
        tags: [:action_type, :initiator_type, :status],
        description: "Total number of remediation actions executed"
      ),
      counter("railway_agent.remediation.success",
        tags: [:action_type],
        description: "Total number of successful remediation actions"
      ),
      counter("railway_agent.remediation.failure",
        tags: [:action_type],
        description: "Total number of failed remediation actions"
      ),

      # SC-004: Command latency (conversational command to response)
      distribution("railway_agent.conversation.command_latency",
        unit: {:native, :millisecond},
        description: "Time from command received to response sent",
        reporter_options: [buckets: [100, 500, 1000, 5000, 10_000, 30_000, 60_000]]
      ),
      counter("railway_agent.conversation.started",
        tags: [:channel],
        description: "Total number of conversation sessions started"
      ),
      counter("railway_agent.conversation.messages",
        tags: [:role],
        description: "Total number of conversation messages"
      ),

      # System health metrics
      last_value("railway_agent.websocket.connected",
        description: "Railway WebSocket connection status (1=connected, 0=disconnected)"
      ),
      counter("railway_agent.logs.processed",
        tags: [:service_id],
        description: "Total number of log events processed"
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {RailwayAppWeb, :count_users, []}
    ]
  end
end
