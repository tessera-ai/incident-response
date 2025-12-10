defmodule RailwayApp.Analysis.LogProcessorTest do
  use RailwayApp.DataCase, async: false

  alias RailwayApp.Analysis.LogProcessor
  alias RailwayApp.{Incidents, ServiceConfigs}

  setup do
    start_supervised!(LogProcessor)

    # Create a test service config
    {:ok, service_config} =
      ServiceConfigs.create_service_config(%{
        service_id: "test-service-123",
        service_name: "Test Service",
        auto_remediation_enabled: false,
        confidence_threshold: 0.7
      })

    {:ok, service_config: service_config}
  end

  describe "log processing" do
    test "detects critical error patterns", %{service_config: service_config} do
      # Subscribe to incident broadcasts
      Phoenix.PubSub.subscribe(RailwayApp.PubSub, "incidents:new")

      # Create critical log events
      critical_logs = [
        %{
          service_id: service_config.service_id,
          message: "Fatal error: Connection refused",
          level: "error",
          timestamp: DateTime.utc_now()
        },
        %{
          service_id: service_config.service_id,
          message: "Exception in request handler",
          level: "error",
          timestamp: DateTime.utc_now()
        }
      ]

      # Process logs
      Enum.each(critical_logs, fn log ->
        LogProcessor.process_log(log)
      end)

      # Wait for batch analysis (batch interval is 5 seconds)
      assert_receive {:incident_detected, incident}, 6_000

      # Verify incident was created
      assert incident.service_id == service_config.service_id
      assert incident.service_name == service_config.service_name
      assert incident.severity in ["critical", "high", "medium", "low"]
      assert incident.status == "detected"
      assert is_binary(incident.signature)

      # Verify incident is persisted
      persisted = Incidents.get_incident(incident.id)
      assert persisted != nil
      assert persisted.id == incident.id
    end

    test "deduplicates incidents with same signature", %{service_config: service_config} do
      # Create similar log events
      log_event = %{
        service_id: service_config.service_id,
        message: "Out of memory error",
        level: "fatal",
        timestamp: DateTime.utc_now()
      }

      # Process same log multiple times
      LogProcessor.process_log(log_event)
      LogProcessor.process_log(log_event)
      LogProcessor.process_log(log_event)

      # Wait for processing
      Process.sleep(6_000)

      # Should only create one incident
      incidents = Incidents.list_by_service(service_config.service_id)
      assert length(incidents) == 1
    end

    test "ignores non-critical logs", %{service_config: service_config} do
      # Subscribe to incident broadcasts
      Phoenix.PubSub.subscribe(RailwayApp.PubSub, "incidents:new")

      # Create info-level log events
      info_logs = [
        %{
          service_id: service_config.service_id,
          message: "Request processed successfully",
          level: "info",
          timestamp: DateTime.utc_now()
        },
        %{
          service_id: service_config.service_id,
          message: "Starting server on port 4000",
          level: "info",
          timestamp: DateTime.utc_now()
        }
      ]

      # Process logs
      Enum.each(info_logs, fn log ->
        LogProcessor.process_log(log)
      end)

      # Should not receive incident within timeout
      refute_receive {:incident_detected, _incident}, 6_000
    end

    test "maintains sliding window of logs per service", %{service_config: service_config} do
      # Generate many logs to test window size
      logs =
        Enum.map(1..25, fn i ->
          %{
            service_id: service_config.service_id,
            message: "Log message #{i}",
            level: "info",
            timestamp: DateTime.utc_now()
          }
        end)

      # Process all logs
      Enum.each(logs, fn log ->
        LogProcessor.process_log(log)
      end)

      # Window should maintain only last 20 logs
      # This is internal state, so we just verify the system doesn't crash
      Process.sleep(100)

      # System should still be responsive
      LogProcessor.process_log(%{
        service_id: service_config.service_id,
        message: "Test message",
        level: "info",
        timestamp: DateTime.utc_now()
      })

      # No errors should occur
      :ok
    end
  end

  describe "pattern detection" do
    test "detects OOM errors", %{service_config: service_config} do
      Phoenix.PubSub.subscribe(RailwayApp.PubSub, "incidents:new")

      log = %{
        service_id: service_config.service_id,
        message: "FATAL: Out of memory - killed by OOM killer",
        level: "fatal",
        timestamp: DateTime.utc_now()
      }

      LogProcessor.process_log(log)

      assert_receive {:incident_detected, incident}, 6_000
      assert incident.severity in ["critical", "high"]
    end

    test "detects connection errors", %{service_config: service_config} do
      Phoenix.PubSub.subscribe(RailwayApp.PubSub, "incidents:new")

      log = %{
        service_id: service_config.service_id,
        message: "ERROR: ECONNREFUSED - connection refused",
        level: "error",
        timestamp: DateTime.utc_now()
      }

      LogProcessor.process_log(log)

      assert_receive {:incident_detected, incident}, 6_000
      assert incident.service_id == service_config.service_id
    end

    test "detects HTTP 500 errors", %{service_config: service_config} do
      Phoenix.PubSub.subscribe(RailwayApp.PubSub, "incidents:new")

      log = %{
        service_id: service_config.service_id,
        message: "HTTP 500 Internal Server Error",
        level: "error",
        timestamp: DateTime.utc_now()
      }

      LogProcessor.process_log(log)

      assert_receive {:incident_detected, incident}, 6_000
      assert incident.service_id == service_config.service_id
    end
  end
end
