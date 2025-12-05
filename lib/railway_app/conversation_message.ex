defmodule RailwayApp.ConversationMessage do
  @moduledoc """
  Represents a single message in a conversation session.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(user assistant system)

  schema "conversation_messages" do
    field :role, :string
    field :content, :string
    field :timestamp, :utc_datetime
    field :action_ref, :binary_id

    belongs_to :session, RailwayApp.ConversationSession

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(conversation_message, attrs) do
    conversation_message
    |> cast(attrs, [
      :session_id,
      :role,
      :content,
      :timestamp,
      :action_ref
    ])
    |> validate_required([:session_id, :role, :content, :timestamp])
    |> validate_inclusion(:role, @roles)
    |> foreign_key_constraint(:session_id)
  end

  def roles, do: @roles
end
