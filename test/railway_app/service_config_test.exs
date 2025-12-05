defmodule RailwayApp.ServiceConfigTest do
  use ExUnit.Case, async: true

  alias RailwayApp.ServiceConfig

  test "ollama provider is not in allowed list" do
    changeset =
      ServiceConfig.changeset(%ServiceConfig{}, %{
        service_id: "test_service",
        service_name: "Test Service",
        llm_provider: "ollama"
      })

    refute changeset.valid?
  end

  test "auto provider still works" do
    changeset =
      ServiceConfig.changeset(%ServiceConfig{}, %{
        service_id: "test_service",
        service_name: "Test Service",
        llm_provider: "auto"
      })

    assert changeset.valid?
  end
end
