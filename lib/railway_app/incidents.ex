defmodule RailwayApp.Incidents do
  @moduledoc """
  Context for managing incidents.
  """

  import Ecto.Query
  alias RailwayApp.Repo
  alias RailwayApp.Incident

  @doc """
  Returns the list of incidents.

  Options:
  - `:limit` - Maximum number of incidents to return
  - `:offset` - Number of incidents to skip
  - `:severity` - Filter by severity
  - `:status` - Filter by status
  - `:service_id` - Filter by service_id
  """
  def list_incidents(opts \\ []) do
    query = from i in Incident, order_by: [desc: i.detected_at]

    query
    |> apply_filters(opts)
    |> apply_pagination(opts)
    |> Repo.all()
  end

  @doc """
  Counts incidents matching the given filters.
  """
  def count_incidents(opts \\ []) do
    query = from(i in Incident)

    query
    |> apply_filters(opts)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets a single incident.
  """
  def get_incident(id), do: Repo.get(Incident, id)

  @doc """
  Gets a single incident, raising if not found.
  """
  def get_incident!(id), do: Repo.get!(Incident, id)

  @doc """
  Gets an incident by service_id and signature.
  """
  def get_by_signature(service_id, signature) do
    Repo.get_by(Incident, service_id: service_id, signature: signature)
  end

  @doc """
  Creates an incident.
  """
  def create_incident(attrs \\ %{}) do
    %Incident{}
    |> Incident.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates or updates an incident based on signature (for deduplication).
  Returns {:ok, incident, :created} for new incidents or {:ok, incident, :updated} for existing.
  Does not update incidents that are already resolved/remediated.
  """
  def create_or_update_incident(attrs) do
    service_id = attrs[:service_id] || attrs["service_id"]
    signature = attrs[:signature] || attrs["signature"]

    case get_by_signature(service_id, signature) do
      nil ->
        case create_incident(attrs) do
          {:ok, incident} -> {:ok, incident, :created}
          {:error, changeset} -> {:error, changeset}
        end

      existing ->
        # Don't update incidents that are already resolved or auto-remediated
        if existing.status in ["auto_remediated", "manual_resolved", "ignored"] do
          {:ok, existing, :skipped}
        else
          case update_incident(existing, attrs) do
            {:ok, incident} -> {:ok, incident, :updated}
            {:error, changeset} -> {:error, changeset}
          end
        end
    end
  end

  @doc """
  Updates an incident.
  """
  def update_incident(%Incident{} = incident, attrs) do
    incident
    |> Incident.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an incident.
  """
  def delete_incident(%Incident{} = incident) do
    Repo.delete(incident)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking incident changes.
  """
  def change_incident(%Incident{} = incident, attrs \\ %{}) do
    Incident.changeset(incident, attrs)
  end

  @doc """
  Marks an incident as resolved.
  """
  def resolve_incident(%Incident{} = incident, status \\ "manual_resolved") do
    update_incident(incident, %{
      status: status,
      resolved_at: DateTime.utc_now()
    })
  end

  @doc """
  Lists incidents for a specific service.
  """
  def list_by_service(service_id) do
    from(i in Incident, where: i.service_id == ^service_id, order_by: [desc: i.detected_at])
    |> Repo.all()
  end

  @doc """
  Lists unresolved incidents.
  """
  def list_unresolved do
    from(i in Incident,
      where: i.status in ["detected", "awaiting_action"],
      order_by: [desc: i.detected_at]
    )
    |> Repo.all()
  end

  @doc """
  Deletes incidents older than the specified number of days.
  """
  def delete_old_incidents(days \\ 90) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    from(i in Incident, where: i.detected_at < ^cutoff_date)
    |> Repo.delete_all()
  end

  # Private functions

  defp apply_filters(query, []), do: query

  defp apply_filters(query, [{:severity, severity} | rest]) do
    query
    |> where([i], i.severity == ^severity)
    |> apply_filters(rest)
  end

  defp apply_filters(query, [{:status, status} | rest]) do
    query
    |> where([i], i.status == ^status)
    |> apply_filters(rest)
  end

  defp apply_filters(query, [{:service_id, service_id} | rest]) do
    query
    |> where([i], i.service_id == ^service_id)
    |> apply_filters(rest)
  end

  defp apply_filters(query, [_unknown | rest]) do
    apply_filters(query, rest)
  end

  defp apply_pagination(query, opts) do
    case Keyword.get(opts, :limit) do
      nil -> query
      limit -> query |> limit(^limit)
    end
    |> then(fn q ->
      case Keyword.get(opts, :offset) do
        nil -> q
        offset -> q |> offset(^offset)
      end
    end)
  end
end
