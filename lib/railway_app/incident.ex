defmodule RailwayApp.Incident do
  @moduledoc """
  Represents a detected production incident from Railway logs.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @severities ~w(critical high medium low)
  @statuses ~w(detected auto_remediated awaiting_action manual_resolved failed ignored)
  @actions ~w(restart redeploy scale_memory scale_replicas rollback stop manual_fix none)

  schema "incidents" do
    field :service_id, :string
    field :service_name, :string
    field :environment_id, :string
    field :signature, :string
    field :severity, :string
    field :status, :string, default: "detected"
    field :confidence, :float
    field :root_cause, :string
    field :recommended_action, :string
    field :reasoning, :string
    field :log_context, :map
    field :detected_at, :utc_datetime
    field :resolved_at, :utc_datetime
    field :metadata, :map

    belongs_to :service_config, RailwayApp.ServiceConfig
    has_many :remediation_actions, RailwayApp.RemediationAction

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(incident, attrs) do
    incident
    |> cast(attrs, [
      :service_id,
      :service_name,
      :environment_id,
      :signature,
      :severity,
      :status,
      :confidence,
      :root_cause,
      :recommended_action,
      :reasoning,
      :log_context,
      :detected_at,
      :resolved_at,
      :metadata,
      :service_config_id
    ])
    |> validate_required([
      :service_id,
      :service_name,
      :signature,
      :severity,
      :recommended_action,
      :detected_at
    ])
    |> validate_inclusion(:severity, @severities)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:recommended_action, @actions)
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> unique_constraint([:service_id, :signature])
  end

  def severities, do: @severities
  def statuses, do: @statuses
  def actions, do: @actions
end
