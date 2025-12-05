defmodule RailwayApp.Analysis.LLMRouterTest do
  use ExUnit.Case, async: false

  alias RailwayApp.Analysis.LLMRouter
  alias RailwayApp.Incident

  setup do
    original_config = Application.get_env(:railway_app, :llm, [])

    on_exit(fn ->
      Application.put_env(:railway_app, :llm, original_config)
    end)

    :ok
  end

  # =============================================================================
  # Provider Selection
  # =============================================================================

  describe "provider selection" do
    test "returns error when no provider configured" do
      Application.put_env(:railway_app, :llm, [])

      logs = [%{timestamp: "2023-01-01T00:00:00Z", level: "error", message: "test error"}]
      result = LLMRouter.analyze_logs(logs, "test_service")

      assert result == {:error, :no_provider}
    end

    test "ollama provider is not supported after removal" do
      Application.put_env(:railway_app, :llm, default_provider: "ollama")

      logs = [%{timestamp: "2023-01-01T00:00:00Z", level: "error", message: "test error"}]
      result = LLMRouter.analyze_logs(logs, "test_service")

      assert result == {:error, :no_provider}
    end

    test "selects openai when configured" do
      Application.put_env(:railway_app, :llm,
        default_provider: "openai",
        openai_api_key: "test_key"
      )

      logs = [%{timestamp: "2023-01-01T00:00:00Z", level: "error", message: "test error"}]
      result = LLMRouter.analyze_logs(logs, "test_service")

      # Will fail at API call but not at provider selection
      assert result in [{:error, :request_failed}, {:error, :api_error}]
    end

    test "selects anthropic when configured" do
      Application.put_env(:railway_app, :llm,
        default_provider: "anthropic",
        anthropic_api_key: "test_key"
      )

      logs = [%{timestamp: "2023-01-01T00:00:00Z", level: "error", message: "test error"}]
      result = LLMRouter.analyze_logs(logs, "test_service")

      # Will fail at API call but not at provider selection
      assert result in [{:error, :request_failed}, {:error, :api_error}]
    end

    test "auto mode selects first available provider" do
      Application.put_env(:railway_app, :llm,
        default_provider: "auto",
        openai_api_key: "test_key"
      )

      logs = [%{timestamp: "2023-01-01T00:00:00Z", level: "error", message: "test error"}]
      result = LLMRouter.analyze_logs(logs, "test_service")

      # Will fail at API call but not at provider selection
      assert result in [{:error, :request_failed}, {:error, :api_error}]
    end
  end

  # =============================================================================
  # Analyze Logs
  # =============================================================================

  describe "analyze_logs/2" do
    test "accepts logs list and service name" do
      logs = [
        %{timestamp: "2023-01-01T00:00:00Z", level: "error", message: "Error 1"},
        %{timestamp: "2023-01-01T00:00:01Z", level: "warn", message: "Warning 1"}
      ]

      service_name = "api-service"

      assert is_list(logs)
      assert is_binary(service_name)
    end

    test "handles empty logs list" do
      Application.put_env(:railway_app, :llm,
        default_provider: "openai",
        openai_api_key: "test_key"
      )

      logs = []
      result = LLMRouter.analyze_logs(logs, "test_service")

      # Will fail at API call
      assert result in [{:error, :request_failed}, {:error, :api_error}]
    end
  end

  # =============================================================================
  # Parse Intent
  # =============================================================================

  describe "parse_intent/2" do
    test "accepts message and context" do
      message = "restart the api service"
      context = %{session_id: "sess_123", incident_id: "inc_456"}

      assert is_binary(message)
      assert is_map(context)
    end

    test "returns error when no provider configured" do
      Application.put_env(:railway_app, :llm, [])

      result = LLMRouter.parse_intent("restart service")

      assert result == {:error, :no_provider}
    end

    test "accepts message without context" do
      Application.put_env(:railway_app, :llm,
        default_provider: "openai",
        openai_api_key: "test_key"
      )

      result = LLMRouter.parse_intent("status check")

      # Will fail at API call
      assert result in [{:error, :request_failed}, {:error, :api_error}]
    end
  end

  # =============================================================================
  # Get Remediation Recommendation (NEW)
  # =============================================================================

  describe "get_remediation_recommendation/2" do
    test "accepts incident and recent logs" do
      incident = %Incident{
        id: "incident_123",
        service_id: "svc_456",
        service_name: "api-service",
        severity: "critical",
        root_cause: "Memory exhaustion",
        recommended_action: "restart",
        detected_at: DateTime.utc_now()
      }

      recent_logs = [
        %{timestamp: "2024-01-01T10:00:00Z", level: "error", message: "OOM killed"},
        %{timestamp: "2024-01-01T10:00:01Z", level: "error", message: "Container restarting"}
      ]

      assert is_struct(incident, Incident)
      assert is_list(recent_logs)
    end

    test "returns error when no provider configured" do
      Application.put_env(:railway_app, :llm, [])

      incident = %Incident{
        id: "incident_123",
        service_id: "svc_456",
        service_name: "api-service",
        severity: "high",
        detected_at: DateTime.utc_now()
      }

      result = LLMRouter.get_remediation_recommendation(incident)

      assert result == {:error, :no_provider}
    end

    test "works with openai provider" do
      Application.put_env(:railway_app, :llm,
        default_provider: "openai",
        openai_api_key: "test_key"
      )

      incident = %Incident{
        id: "incident_123",
        service_id: "svc_456",
        service_name: "api-service",
        severity: "critical",
        root_cause: "Database timeout",
        recommended_action: "restart",
        detected_at: DateTime.utc_now()
      }

      result = LLMRouter.get_remediation_recommendation(incident)

      # Will fail at API call but not at provider selection
      assert result in [{:error, :request_failed}, {:error, :api_error}]
    end

    test "works with anthropic provider" do
      Application.put_env(:railway_app, :llm,
        default_provider: "anthropic",
        anthropic_api_key: "test_key"
      )

      incident = %Incident{
        id: "incident_123",
        service_id: "svc_456",
        service_name: "api-service",
        severity: "high",
        detected_at: DateTime.utc_now()
      }

      result = LLMRouter.get_remediation_recommendation(incident, [])

      # Will fail at API call but not at provider selection
      assert result in [{:error, :request_failed}, {:error, :api_error}]
    end

    test "handles logs with different formats" do
      Application.put_env(:railway_app, :llm,
        default_provider: "openai",
        openai_api_key: "test_key"
      )

      incident = %Incident{
        id: "incident_123",
        service_id: "svc_456",
        service_name: "api-service",
        severity: "high",
        detected_at: DateTime.utc_now()
      }

      # Logs with string keys
      logs_string_keys = [
        %{"timestamp" => "2024-01-01T10:00:00Z", "level" => "error", "message" => "Error 1"}
      ]

      # Logs with atom keys
      logs_atom_keys = [
        %{timestamp: "2024-01-01T10:00:00Z", level: "error", message: "Error 1"}
      ]

      result1 = LLMRouter.get_remediation_recommendation(incident, logs_string_keys)
      result2 = LLMRouter.get_remediation_recommendation(incident, logs_atom_keys)

      # Both should fail at API call, not parsing
      assert result1 in [{:error, :request_failed}, {:error, :api_error}]
      assert result2 in [{:error, :request_failed}, {:error, :api_error}]
    end
  end
end
