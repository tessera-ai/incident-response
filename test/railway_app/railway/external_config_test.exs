defmodule RailwayApp.Railway.ExternalConfigTest do
  use ExUnit.Case, async: false

  alias RailwayApp.Railway.ServiceConfig

  describe "External service configuration" do
    test "parses comma-separated projects" do
      System.put_env("RAILWAY_MONITORED_PROJECTS", "proj1,proj2,proj3")
      System.put_env("RAILWAY_MONITORED_ENVIRONMENTS", "production")

      services = ServiceConfig.parse_monitored_services()

      assert length(services) == 3

      expected_services = [
        %{project_id: "proj1", environment_id: "production", service_id: nil},
        %{project_id: "proj2", environment_id: "production", service_id: nil},
        %{project_id: "proj3", environment_id: "production", service_id: nil}
      ]

      assert services == expected_services
    end

    test "handles empty config" do
      System.delete_env("RAILWAY_MONITORED_PROJECTS")
      System.delete_env("RAILWAY_MONITORED_ENVIRONMENTS")

      services = ServiceConfig.parse_monitored_services()
      assert services == []
    end
  end
end
