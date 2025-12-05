defmodule RailwayApp.RemediationActions do
  @moduledoc """
  Context for managing remediation actions.
  """

  import Ecto.Query
  alias RailwayApp.Repo
  alias RailwayApp.RemediationAction

  @doc """
  Returns the list of remediation_actions.
  """
  def list_remediation_actions do
    Repo.all(RemediationAction)
  end

  @doc """
  Gets a single remediation_action.
  """
  def get_remediation_action(id), do: Repo.get(RemediationAction, id)

  @doc """
  Gets a single remediation_action, raising if not found.
  """
  def get_remediation_action!(id), do: Repo.get!(RemediationAction, id)

  @doc """
  Creates a remediation_action.
  """
  def create_remediation_action(attrs \\ %{}) do
    %RemediationAction{}
    |> RemediationAction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a remediation_action.
  """
  def update_remediation_action(%RemediationAction{} = remediation_action, attrs) do
    remediation_action
    |> RemediationAction.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a remediation_action.
  """
  def delete_remediation_action(%RemediationAction{} = remediation_action) do
    Repo.delete(remediation_action)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking remediation_action changes.
  """
  def change_remediation_action(%RemediationAction{} = remediation_action, attrs \\ %{}) do
    RemediationAction.changeset(remediation_action, attrs)
  end

  @doc """
  Lists remediation actions for a specific incident.
  """
  def list_by_incident(incident_id) do
    from(r in RemediationAction,
      where: r.incident_id == ^incident_id,
      order_by: [desc: r.requested_at]
    )
    |> Repo.all()
  end

  @doc """
  Lists recent remediation actions.

  Options:
  - `:limit` - Maximum number of actions to return (default: 50)
  - `:offset` - Number of actions to skip
  """
  def list_recent(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    from(r in RemediationAction,
      order_by: [desc: r.requested_at],
      limit: ^limit,
      offset: ^offset,
      preload: [:incident]
    )
    |> Repo.all()
  end

  @doc """
  Counts all remediation actions.
  """
  def count_remediation_actions do
    Repo.aggregate(RemediationAction, :count, :id)
  end

  @doc """
  Deletes remediation actions older than the specified number of days.
  """
  def delete_old_actions(days \\ 90) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    from(r in RemediationAction, where: r.requested_at < ^cutoff_date)
    |> Repo.delete_all()
  end
end
