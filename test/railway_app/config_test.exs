defmodule RailwayApp.ConfigTest do
  use ExUnit.Case, async: true

  test "ollama config is not present in application config" do
    config = Application.get_env(:railway_app, :llm)
    refute Keyword.has_key?(config, :ollama_endpoint)
    refute Keyword.has_key?(config, :ollama_model)
  end
end
