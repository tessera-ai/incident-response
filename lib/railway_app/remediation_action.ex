defmodule RailwayApp.RemediationAction do
  @moduledoc """
  Represents a remediation action taken for an incident.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @initiator_types ~w(automated user)
  @action_types ~w(restart scale_memory scale_replicas rollback diagnostic none)
  @statuses ~w(pending in_progress succeeded failed)

  schema "remediation_actions" do
    field :initiator_type, :string
    field :initiator_ref, :string
    field :action_type, :string
    field :parameters, :map
    field :requested_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :status, :string, default: "pending"
    field :result_message, :string
    field :failure_reason, :string

    belongs_to :incident, RailwayApp.Incident

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(remediation_action, attrs) do
    remediation_action
    |> cast(attrs, [
      :incident_id,
      :initiator_type,
      :initiator_ref,
      :action_type,
      :parameters,
      :requested_at,
      :completed_at,
      :status,
      :result_message,
      :failure_reason
    ])
    |> validate_required([:incident_id, :initiator_type, :action_type, :requested_at])
    |> validate_inclusion(:initiator_type, @initiator_types)
    |> validate_inclusion(:action_type, @action_types)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:incident_id)
  end

  def initiator_types, do: @initiator_types
  def action_types, do: @action_types
  def statuses, do: @statuses
end
