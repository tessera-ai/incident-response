defmodule RailwayApp.ApplicationTest do
  use ExUnit.Case, async: true

  test "no ollama endpoint validation on startup" do
    # Test that application starts without OLLAMA_ENDPOINT
    System.delete_env("OLLAMA_ENDPOINT")
    assert {:ok, _} = Application.ensure_all_started(:railway_app)
  end

  test "application source does not contain OLLAMA_ENDPOINT reference" do
    # Read the application.ex file and verify it doesn't contain OLLAMA_ENDPOINT
    app_file = File.read!("lib/railway_app/application.ex")
    refute String.contains?(app_file, "OLLAMA_ENDPOINT")
  end

  describe "Railway configuration validation in production" do
    setup do
      # Store original environment
      original_env = %{
        "DATABASE_URL" => System.get_env("DATABASE_URL"),
        "SECRET_KEY_BASE" => System.get_env("SECRET_KEY_BASE"),
        "RAILWAY_API_TOKEN" => System.get_env("RAILWAY_API_TOKEN"),
        "RAILWAY_PROJECT_ID" => System.get_env("RAILWAY_PROJECT_ID"),
        "RAILWAY_ENVIRONMENT_ID" => System.get_env("RAILWAY_ENVIRONMENT_ID"),
        "MIX_ENV" => System.get_env("MIX_ENV")
      }

      on_exit(fn ->
        # Restore original environment
        Enum.each(original_env, fn {key, value} ->
          if value do
            System.put_env(key, value)
          else
            System.delete_env(key)
          end
        end)
      end)

      :ok
    end

    test "fails to start without RAILWAY_API_TOKEN in production" do
      # Set up minimal required variables
      System.put_env("DATABASE_URL", "postgresql://test:test@localhost/test")
      System.put_env("SECRET_KEY_BASE", "test_secret_key_base_for_testing")
      System.put_env("RAILWAY_PROJECT_ID", "test_project_id")
      System.put_env("RAILWAY_ENVIRONMENT_ID", "test_environment_id")
      # Missing RAILWAY_API_TOKEN
      System.delete_env("RAILWAY_API_TOKEN")

      # Should fail to start - set application environment to :prod
      Application.put_env(:railway_app, :env, :prod)

      assert_raise RuntimeError,
                   ~r/RAILWAY_API_TOKEN environment variable is required in production/,
                   fn ->
                     RailwayApp.Application.start(:normal, [])
                   end
    end

    test "starts successfully with all required Railway variables in production" do
      System.put_env("DATABASE_URL", "postgresql://test:test@localhost/test")
      System.put_env("SECRET_KEY_BASE", "test_secret_key_base_for_testing")
      System.put_env("RAILWAY_API_TOKEN", "test_railway_api_token")
      System.put_env("RAILWAY_PROJECT_ID", "test_project_id")
      System.put_env("RAILWAY_ENVIRONMENT_ID", "test_environment_id")
      System.put_env("MIX_ENV", "prod")

      # Should start successfully (may have other warnings about missing optional vars)
      assert {:ok, _} = Application.ensure_all_started(:railway_app, :permanent)
    end
  end
end
