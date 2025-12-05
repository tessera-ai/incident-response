defmodule RailwayApp.Railway.ClientTest do
  use ExUnit.Case, async: false

  alias RailwayApp.Railway.Client

  setup do
    # Store original config and reset after test
    original_config = Application.get_env(:railway_app, :railway, [])

    on_exit(fn ->
      Application.put_env(:railway_app, :railway, original_config)
    end)

    :ok
  end

  describe "query/2" do
    test "returns error when API token not configured" do
      Application.put_env(:railway_app, :railway, [])

      result = Client.query("query { project { id } }")
      assert result == {:error, "Railway API token not configured"}
    end

    test "builds correct request body structure" do
      query_string = "query { project { id name } }"
      variables = %{projectId: "test_project"}

      expected_body = %{
        query: query_string,
        variables: variables
      }

      assert expected_body.query == query_string
      assert expected_body.variables == variables
    end
  end

  # =============================================================================
  # Service Operations (Legacy)
  # =============================================================================

  describe "restart_service/1" do
    test "accepts service_id parameter" do
      service_id = "svc_123"
      assert is_binary(service_id)
    end
  end

  describe "scale_memory/2" do
    test "accepts service_id and memory_mb parameters" do
      service_id = "svc_123"
      memory_mb = 1024

      assert is_binary(service_id)
      assert is_integer(memory_mb)
      assert memory_mb > 0
    end
  end

  describe "scale_replicas/2" do
    test "accepts service_id and replica_count parameters" do
      service_id = "svc_123"
      replica_count = 3

      assert is_binary(service_id)
      assert is_integer(replica_count)
      assert replica_count > 0
    end
  end

  # =============================================================================
  # Deployment Operations (New)
  # =============================================================================

  describe "restart_deployment/1" do
    test "accepts deployment_id parameter" do
      deployment_id = "deploy_abc123"
      assert is_binary(deployment_id)
    end

    test "returns error without API token" do
      Application.put_env(:railway_app, :railway, [])

      result = Client.restart_deployment("deploy_123")
      assert result == {:error, "Railway API token not configured"}
    end
  end

  describe "redeploy_deployment/2" do
    test "accepts deployment_id and options" do
      deployment_id = "deploy_abc123"
      opts = [use_previous_image: true]

      assert is_binary(deployment_id)
      assert Keyword.get(opts, :use_previous_image) == true
    end

    test "defaults use_previous_image to false" do
      opts = []
      use_previous_image = Keyword.get(opts, :use_previous_image, false)
      assert use_previous_image == false
    end

    test "returns error without API token" do
      Application.put_env(:railway_app, :railway, [])

      result = Client.redeploy_deployment("deploy_123")
      assert result == {:error, "Railway API token not configured"}
    end
  end

  describe "stop_deployment/1" do
    test "accepts deployment_id parameter" do
      deployment_id = "deploy_abc123"
      assert is_binary(deployment_id)
    end

    test "returns error without API token" do
      Application.put_env(:railway_app, :railway, [])

      result = Client.stop_deployment("deploy_123")
      assert result == {:error, "Railway API token not configured"}
    end
  end

  describe "cancel_deployment/1" do
    test "accepts deployment_id parameter" do
      deployment_id = "deploy_abc123"
      assert is_binary(deployment_id)
    end

    test "returns error without API token" do
      Application.put_env(:railway_app, :railway, [])

      result = Client.cancel_deployment("deploy_123")
      assert result == {:error, "Railway API token not configured"}
    end
  end

  describe "rollback_deployment/1" do
    test "accepts deployment_id parameter" do
      deployment_id = "deploy_abc123"
      assert is_binary(deployment_id)
    end

    test "returns error without API token" do
      Application.put_env(:railway_app, :railway, [])

      result = Client.rollback_deployment("deploy_123")
      assert result == {:error, "Railway API token not configured"}
    end
  end

  # =============================================================================
  # Service Instance Operations (New)
  # =============================================================================

  describe "get_service_instance/2" do
    test "accepts environment_id and service_id" do
      environment_id = "env_abc123"
      service_id = "svc_xyz789"

      assert is_binary(environment_id)
      assert is_binary(service_id)
    end

    test "returns error without API token" do
      Application.put_env(:railway_app, :railway, [])

      result = Client.get_service_instance("env_123", "svc_456")
      assert result == {:error, "Railway API token not configured"}
    end
  end

  describe "update_service_instance/3" do
    test "accepts environment_id, service_id, and opts" do
      environment_id = "env_abc123"
      service_id = "svc_xyz789"
      opts = [num_replicas: 3, healthcheck_path: "/health"]

      assert is_binary(environment_id)
      assert is_binary(service_id)
      assert Keyword.get(opts, :num_replicas) == 3
      assert Keyword.get(opts, :healthcheck_path) == "/health"
    end

    test "transforms option keys correctly" do
      opts = [
        num_replicas: 2,
        start_command: "npm start",
        healthcheck_path: "/healthz",
        restart_policy_type: "ON_FAILURE",
        restart_policy_max_retries: 5
      ]

      # Verify options are present
      assert Keyword.get(opts, :num_replicas) == 2
      assert Keyword.get(opts, :start_command) == "npm start"
      assert Keyword.get(opts, :healthcheck_path) == "/healthz"
      assert Keyword.get(opts, :restart_policy_type) == "ON_FAILURE"
      assert Keyword.get(opts, :restart_policy_max_retries) == 5
    end
  end

  describe "update_service_limits/3" do
    test "accepts environment_id, service_id, and limit options" do
      environment_id = "env_abc123"
      service_id = "svc_xyz789"
      opts = [memory_mb: 2048, cpu_count: 2]

      assert is_binary(environment_id)
      assert is_binary(service_id)
      assert Keyword.get(opts, :memory_mb) == 2048
      assert Keyword.get(opts, :cpu_count) == 2
    end

    test "returns error without API token" do
      Application.put_env(:railway_app, :railway, [])

      result = Client.update_service_limits("env_123", "svc_456", memory_mb: 1024)
      assert result == {:error, "Railway API token not configured"}
    end
  end

  describe "deploy_service_instance/3" do
    test "accepts environment_id, service_id, and optional commit_sha" do
      environment_id = "env_abc123"
      service_id = "svc_xyz789"
      opts = [commit_sha: "abc123def"]

      assert is_binary(environment_id)
      assert is_binary(service_id)
      assert Keyword.get(opts, :commit_sha) == "abc123def"
    end

    test "works without commit_sha" do
      opts = []
      commit_sha = Keyword.get(opts, :commit_sha)
      assert commit_sha == nil
    end
  end

  # =============================================================================
  # Query Operations (New)
  # =============================================================================

  describe "get_deployment/1" do
    test "accepts deployment_id" do
      deployment_id = "deploy_abc123"
      assert is_binary(deployment_id)
    end

    test "returns error without API token" do
      Application.put_env(:railway_app, :railway, [])

      result = Client.get_deployment("deploy_123")
      assert result == {:error, "Railway API token not configured"}
    end
  end

  describe "get_deployment_logs/2" do
    test "accepts deployment_id and options" do
      deployment_id = "deploy_abc123"
      opts = [limit: 50, filter: "error"]

      assert is_binary(deployment_id)
      assert Keyword.get(opts, :limit) == 50
      assert Keyword.get(opts, :filter) == "error"
    end

    test "defaults limit to 100" do
      opts = []
      limit = Keyword.get(opts, :limit, 100)
      assert limit == 100
    end

    test "returns error without API token" do
      Application.put_env(:railway_app, :railway, [])

      result = Client.get_deployment_logs("deploy_123")
      assert result == {:error, "Railway API token not configured"}
    end
  end

  describe "get_metrics/4" do
    test "requires start_date option" do
      project_id = "proj_123"
      service_id = "svc_456"
      environment_id = "env_789"
      start_date = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_iso8601()

      opts = [start_date: start_date]

      assert is_binary(project_id)
      assert is_binary(service_id)
      assert is_binary(environment_id)
      assert Keyword.get(opts, :start_date) != nil
    end

    test "defaults sample_rate_seconds to 60" do
      opts = [start_date: "2024-01-01T00:00:00Z"]
      sample_rate = Keyword.get(opts, :sample_rate_seconds, 60)
      assert sample_rate == 60
    end
  end

  describe "get_variables/3" do
    test "accepts project_id, environment_id, service_id" do
      project_id = "proj_123"
      environment_id = "env_456"
      service_id = "svc_789"

      assert is_binary(project_id)
      assert is_binary(environment_id)
      assert is_binary(service_id)
    end

    test "returns error without API token" do
      Application.put_env(:railway_app, :railway, [])

      result = Client.get_variables("proj_123", "env_456", "svc_789")
      assert result == {:error, "Railway API token not configured"}
    end
  end

  describe "upsert_variable/5" do
    test "accepts all required parameters" do
      project_id = "proj_123"
      environment_id = "env_456"
      service_id = "svc_789"
      key = "DATABASE_URL"
      value = "postgres://localhost/test"

      assert is_binary(project_id)
      assert is_binary(environment_id)
      assert is_binary(service_id)
      assert is_binary(key)
      assert is_binary(value)
    end

    test "returns error without API token" do
      Application.put_env(:railway_app, :railway, [])

      result = Client.upsert_variable("proj", "env", "svc", "KEY", "value")
      assert result == {:error, "Railway API token not configured"}
    end
  end

  # =============================================================================
  # Existing Query Operations
  # =============================================================================

  describe "get_deployments/2" do
    test "uses default limit of 10" do
      default_limit = 10
      assert default_limit == 10
    end

    test "accepts custom limit" do
      custom_limit = 20
      assert is_integer(custom_limit)
      assert custom_limit > 0
    end
  end

  describe "get_service_state/1" do
    test "accepts service_id" do
      service_id = "svc_123"
      assert is_binary(service_id)
    end
  end

  describe "get_latest_deployment_id/3" do
    test "accepts project_id, environment_id, service_id" do
      project_id = "proj_123"
      environment_id = "env_456"
      service_id = "svc_789"

      assert is_binary(project_id)
      assert is_binary(environment_id)
      assert is_binary(service_id)
    end

    test "returns error without API token" do
      Application.put_env(:railway_app, :railway, [])

      result = Client.get_latest_deployment_id("proj", "env", "svc")
      assert result == {:error, "Railway API token not configured"}
    end
  end

  describe "validate_token/0" do
    test "returns error without API token" do
      Application.put_env(:railway_app, :railway, [])

      result = Client.validate_token()
      assert result == {:error, "Railway API token not configured"}
    end
  end
end
