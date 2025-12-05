defmodule RailwayApp.ConversationSession do
  @moduledoc """
  Represents a conversation session with a user, typically initiated from Slack.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @channels ~w(slack)

  schema "conversation_sessions" do
    field :channel, :string
    field :channel_ref, :string
    field :participant_id, :string
    field :started_at, :utc_datetime
    field :closed_at, :utc_datetime
    field :context, :map

    belongs_to :incident, RailwayApp.Incident
    has_many :conversation_messages, RailwayApp.ConversationMessage, foreign_key: :session_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(conversation_session, attrs) do
    conversation_session
    |> cast(attrs, [
      :incident_id,
      :channel,
      :channel_ref,
      :participant_id,
      :started_at,
      :closed_at,
      :context
    ])
    |> validate_required([:channel, :channel_ref, :participant_id, :started_at])
    |> validate_inclusion(:channel, @channels)
    |> foreign_key_constraint(:incident_id)
  end

  def channels, do: @channels
end
