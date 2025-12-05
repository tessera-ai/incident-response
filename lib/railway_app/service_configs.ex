defmodule RailwayApp.ServiceConfigs do
  @moduledoc """
  Context for managing service configurations.
  """

  # import Ecto.Query  # Uncomment when using Ecto.Query functions
  alias RailwayApp.Repo
  alias RailwayApp.ServiceConfig

  @doc """
  Returns the list of service_configs.
  """
  def list_service_configs do
    Repo.all(ServiceConfig)
  end

  @doc """
  Gets a single service_config.
  """
  def get_service_config(id), do: Repo.get(ServiceConfig, id)

  @doc """
  Gets a single service_config, raising if not found.
  """
  def get_service_config!(id), do: Repo.get!(ServiceConfig, id)

  @doc """
  Gets a service config by service_id.
  """
  def get_by_service_id(service_id) do
    Repo.get_by(ServiceConfig, service_id: service_id)
  end

  @doc """
  Creates a service_config.
  """
  def create_service_config(attrs \\ %{}) do
    %ServiceConfig{}
    |> ServiceConfig.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a service_config.
  """
  def update_service_config(%ServiceConfig{} = service_config, attrs) do
    service_config
    |> ServiceConfig.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a service_config.
  """
  def delete_service_config(%ServiceConfig{} = service_config) do
    Repo.delete(service_config)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking service_config changes.
  """
  def change_service_config(%ServiceConfig{} = service_config, attrs \\ %{}) do
    ServiceConfig.changeset(service_config, attrs)
  end

  @doc """
  Toggles auto-remediation for a service.
  """
  def toggle_auto_remediation(service_id, enabled) do
    case get_by_service_id(service_id) do
      nil -> {:error, :not_found}
      config -> update_service_config(config, %{auto_remediation_enabled: enabled})
    end
  end
end
