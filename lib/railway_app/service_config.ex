defmodule RailwayApp.ServiceConfig do
  @moduledoc """
  Represents configuration settings for monitored Railway services.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "service_configs" do
    field :service_id, :string
    field :service_name, :string
    field :auto_remediation_enabled, :boolean, default: false
    field :memory_scale_default, :integer
    field :replica_scale_default, :integer
    field :llm_provider, :string, default: "auto"
    field :confidence_threshold, :float, default: 0.7

    has_many :incidents, RailwayApp.Incident

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(service_config, attrs) do
    service_config
    |> cast(attrs, [
      :service_id,
      :service_name,
      :auto_remediation_enabled,
      :memory_scale_default,
      :replica_scale_default,
      :llm_provider,
      :confidence_threshold
    ])
    |> validate_required([:service_id, :service_name])
    |> validate_inclusion(:llm_provider, ["openai", "anthropic", "auto"])
    |> validate_number(:confidence_threshold,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> unique_constraint(:service_id)
  end
end
