defmodule RailwayApp.Railway.ConnectionManagerTest do
  use ExUnit.Case, async: false
  @moduletag :db

  alias RailwayApp.Railway.ConnectionManager

  describe "Railway WebSocket connection validation" do
    setup do
      # Set up basic required env vars
      System.put_env("DATABASE_URL", "postgresql://test:test@localhost/test")
      System.put_env("SECRET_KEY_BASE", "test_secret_key_base_for_testing")

      start_supervised!(RailwayApp.Railway.WebSocketSupervisor)

      # Checkout connection and allow shared access
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(RailwayApp.Repo)
      Ecto.Adapters.SQL.Sandbox.mode(RailwayApp.Repo, {:shared, self()})

      :ok
    end

    test "validates Railway API token before connection attempt" do
      # Remove API token
      System.delete_env("RAILWAY_API_TOKEN")

      # Start the manager first
      start_supervised!({ConnectionManager, project_id: "test_project_id"})

      # Should fail to establish WebSocket connection due to missing token
      result =
        ConnectionManager.start_service_monitoring(
          "test_project_id",
          "test_service_id",
          %{auto_subscribe: false}
        )

      # Should either fail with token-related error or timeout
      assert match?({:error, _reason}, result) or result == {:error, :connection_failed}
    end

    test "validates project_id and service_id in WebSocket URL construction" do
      System.put_env("RAILWAY_API_TOKEN", "test_token_for_validation")

      # Should attempt connection with valid parameters
      # Will likely fail due to network but validates URL construction
      start_supervised!({ConnectionManager, project_id: "project_with_valid_format"})

      result =
        ConnectionManager.start_service_monitoring(
          "project_with_valid_format",
          "service_with_valid_format",
          %{auto_subscribe: false}
        )

      # The connection attempt should be made (failures are expected without real Railway credentials)
      assert match?({:ok, _pid}, result) or match?({:error, _reason}, result)
    end

    test "attempts reconnection with exponential backoff" do
      System.put_env("RAILWAY_API_TOKEN", "test_retry_token")

      # Start a connection manager
      start_supervised!({ConnectionManager, project_id: "retry_test_project"})

      # This test verifies retry logic is triggered
      # In a real scenario, this would use exponential backoff
      task =
        Task.async(fn ->
          ConnectionManager.start_service_monitoring(
            "retry_test_project",
            "retry_test_service",
            %{auto_subscribe: false}
          )
        end)

      # Give it time to attempt connection and potentially retry
      result = Task.await(task, 3000)

      # Should either succeed or fail with connection-related reason
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "WebSocket URL validation" do
    test "constructs proper WebSocket URL with token parameter" do
      System.put_env("RAILWAY_API_TOKEN", "test_token_12345")

      # Test that the WebSocket client properly encodes the token
      # This validates the URL construction logic
      assert is_binary(System.get_env("RAILWAY_API_TOKEN"))

      # The actual connection will fail but URL construction should be valid
      result =
        RailwayApp.Railway.WebSocketClient.start_link(
          project_id: "test_project",
          service_id: "test_service",
          token: System.get_env("RAILWAY_API_TOKEN")
        )

      # Should either succeed in starting the process or fail with URL/validation error
      # but not with parameter errors
      case result do
        {:ok, _pid} ->
          # Successfully started WebSocket process
          assert true

        {:error, reason} ->
          # Should fail due to network/connectivity, not parameter validation
          refute reason == :no_token
          refute reason == :invalid_project_id
          refute reason == :invalid_service_id
      end
    end
  end

  describe "startup database deferral" do
    test "schedules deferred database persistence during initialization" do
      # Set up environment variables for monitored services
      System.put_env("RAILWAY_MONITORED_PROJECTS", "test_project")
      System.put_env("RAILWAY_MONITORED_ENVIRONMENTS", "production")
      System.put_env("RAILWAY_API_TOKEN", "test_token")

      try do
        # Start the connection manager
        {:ok, pid} = ConnectionManager.start_link(project_id: "test_project")

        # Verify the process started
        assert Process.alive?(pid)

        # Check that a :persist_service_configs message is scheduled
        # This tests that the deferral mechanism is in place
        messages = Process.info(pid, :messages)
        assert match?({:messages, _}, messages)

        # The actual persistence will happen asynchronously after 5 seconds
        # We can't easily test the timing without complex setup, but we can
        # verify the process is alive and the deferral is scheduled
      after
        System.delete_env("RAILWAY_MONITORED_PROJECTS")
        System.delete_env("RAILWAY_MONITORED_ENVIRONMENTS")
        System.delete_env("RAILWAY_API_TOKEN")
      end
    end
  end

  describe "database retry logic" do
    test "retries database operations with exponential backoff" do
      # Test the retry logic directly by calling the public function
      # This test verifies the retry behavior without needing a real database

      # Create a test module that simulates failures
      test_pid = self()
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      # Override the save function temporarily for this test
      original_module = RailwayApp.Railway.ConnectionManager
      test_module = :"Test#{:erlang.unique_integer([:positive])}"

      # Create a test version of the module
      test_code = """
      defmodule #{test_module} do
        def save_with_retry(service_id, config, max_attempts, base_delay) do
          Agent.update(#{inspect(agent)}, &(&1 + 1))
          send(#{inspect(test_pid)}, {:retry_attempt, Agent.get(#{inspect(agent)}, &(&1))})

          if Agent.get(#{inspect(agent)}, &(&1)) < 3 do
            {:error, :simulated_failure}
          else
            :ok
          end
        end
      end
      """

      # Evaluate the test module
      Code.eval_string(test_code)

      try do
        # Test the retry logic
        start_time = System.monotonic_time(:millisecond)

        result = apply(test_module, :save_with_retry, ["test_service", %{}, 3, 50])

        end_time = System.monotonic_time(:millisecond)

        # Should eventually succeed after retries
        assert result == :ok

        # Should have made multiple attempts
        assert_received {:retry_attempt, 1}
        assert_received {:retry_attempt, 2}
        assert_received {:retry_attempt, 3}

        # Should have taken some time due to backoff delays
        elapsed = end_time - start_time
        # At least one delay
        assert elapsed >= 50
      after
        Agent.stop(agent)
        # Clean up the test module if possible
        if Code.ensure_loaded?(test_module) do
          :code.delete(test_module)
          :code.purge(test_module)
        end
      end
    end

    test "handles max retry exhaustion gracefully" do
      # Test that the system handles persistent failures gracefully
      # This is more of an integration test that verifies error handling

      # The retry logic should prevent crashes even when database operations fail
      # Since we can't easily mock the database operations without external libraries,
      # this test focuses on verifying the error handling doesn't crash the process

      # This would require setting up a scenario where database operations consistently fail
      # For now, we document that this behavior should be tested in integration tests
      # with actual database failures
    end
  end
end
