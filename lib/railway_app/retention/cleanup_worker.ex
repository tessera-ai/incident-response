defmodule RailwayApp.Retention.CleanupWorker do
  @moduledoc """
  GenServer that periodically cleans up old incidents, remediation actions, and conversations.
  Runs daily to maintain 90-day retention policy.
  """

  use GenServer
  require Logger

  alias RailwayApp.{Incidents, RemediationActions, Conversations}

  # 24 hours in milliseconds
  @cleanup_interval 24 * 60 * 60 * 1000
  @retention_days 90

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Schedule first cleanup
    schedule_cleanup()

    {:ok, %{last_cleanup: nil}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    Logger.info("Starting data retention cleanup (#{@retention_days} days)")

    Task.Supervisor.start_child(RailwayApp.TaskSupervisor, fn ->
      perform_cleanup()
    end)

    # Schedule next cleanup
    schedule_cleanup()

    {:noreply, %{state | last_cleanup: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unhandled message in CleanupWorker: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private Functions

  defp perform_cleanup do
    # Clean up old incidents
    {incidents_deleted, _} = Incidents.delete_old_incidents(@retention_days)
    Logger.info("Deleted #{incidents_deleted} old incidents")

    # Clean up old remediation actions
    {actions_deleted, _} = RemediationActions.delete_old_actions(@retention_days)
    Logger.info("Deleted #{actions_deleted} old remediation actions")

    # Clean up old conversations
    {conversations_deleted, _} = Conversations.delete_old_conversations(@retention_days)
    Logger.info("Deleted #{conversations_deleted} old conversation sessions")

    Logger.info("Data retention cleanup completed")
  rescue
    error ->
      Logger.error("Error during cleanup: #{inspect(error)}")
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end
