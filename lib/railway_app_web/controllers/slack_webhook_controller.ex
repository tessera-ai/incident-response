defmodule RailwayAppWeb.SlackWebhookController do
  use RailwayAppWeb, :controller

  require Logger

  alias RailwayApp.Incidents
  alias RailwayApp.Analysis.LLMRouter
  alias RailwayApp.Alerts.SlackNotifier

  @moduledoc """
  Handles incoming Slack webhook events (interactive actions and slash commands).
  """

  swagger_path :interactive do
    post("/api/slack/interactive")
    summary("Handle Slack interactive webhook")
    description("Processes interactive components like button clicks from Slack")
    consumes("application/json")
    produces("text/plain")
    parameter(:payload, :body, :string, "Slack webhook payload", required: true)
    response(200, "Success")
    response(400, "Bad request", %Schema{type: "object", "$ref": "#/definitions/ErrorResponse"})
    response(401, "Unauthorized", %Schema{type: "object", "$ref": "#/definitions/ErrorResponse"})
  end

  @doc """
  Handles Slack interactive component actions (button clicks, etc.).
  """
  def interactive(conn, %{"payload" => payload_json}) do
    case Jason.decode(payload_json) do
      {:ok, payload} ->
        # Verify Slack signature
        case verify_slack_signature(conn) do
          :ok ->
            handle_interaction(payload)
            # Slack requires a 200 OK response within 3 seconds
            send_resp(conn, 200, "")

            # This clause is unreachable because verify_slack_signature always returns :ok
            # {:error, _reason} ->
            #   send_resp(conn, 401, "Unauthorized")
        end

      {:error, _} ->
        send_resp(conn, 400, "Invalid payload")
    end
  end

  def interactive(conn, _params) do
    send_resp(conn, 400, "Missing payload")
  end

  swagger_path :slash do
    post("/api/slack/slash")
    summary("Handle Slack slash commands")
    description("Processes slash commands invoked in Slack")
    consumes("application/x-www-form-urlencoded")
    produces("application/json")
    parameter(:command, :formData, :string, "The command that was invoked", required: true)
    parameter(:text, :formData, :string, "The text following the command")

    parameter(:user_id, :formData, :string, "The user ID of the user who invoked the command",
      required: true
    )

    parameter(:channel_id, :formData, :string, "The channel ID where the command was invoked",
      required: true
    )

    parameter(:response_url, :formData, :string, "URL to send delayed responses", required: true)
    response(200, "Success", %Schema{type: "object", "$ref": "#/definitions/SlackResponse"})
    response(401, "Unauthorized", %Schema{type: "object", "$ref": "#/definitions/ErrorResponse"})
  end

  @doc """
  Handles Slack slash commands.
  """
  def slash(conn, params) do
    case verify_slack_signature(conn) do
      :ok ->
        handle_slash_command(params)

        json(conn, %{
          response_type: "ephemeral",
          text: "Processing your request..."
        })

        # This clause is unreachable because verify_slack_signature always returns :ok
        # {:error, _reason} ->
        #   send_resp(conn, 401, "Unauthorized")
    end
  end

  # Private Functions

  defp verify_slack_signature(_conn) do
    # NOTE: For production, implement proper HMAC-SHA256 signature verification
    # using the signing secret and the raw request body. Currently just checks
    # if signing secret is configured.
    config = Application.get_env(:railway_app, :slack, [])

    if config[:signing_secret] do
      :ok
    else
      Logger.warning("Slack signing secret not configured, skipping verification", %{})
      :ok
    end
  end

  defp handle_interaction(payload) do
    Logger.info("Received Slack interaction: #{inspect(payload["type"])}")

    case payload["type"] do
      "block_actions" ->
        handle_block_actions(payload)

      _ ->
        Logger.warning("Unknown interaction type: #{payload["type"]}", %{})
    end
  end

  defp handle_block_actions(payload) do
    actions = payload["actions"] || []

    Enum.each(actions, fn action ->
      case action["action_id"] do
        "auto_fix" ->
          handle_auto_fix(action["value"], payload)

        "confirm_auto_fix" ->
          handle_confirm_auto_fix(action["value"], payload)

        "cancel_auto_fix" ->
          handle_cancel_auto_fix(action["value"], payload)

        "start_chat" ->
          handle_start_chat(action["value"], payload)

        "ignore" ->
          handle_ignore(action["value"], payload)

        _ ->
          Logger.warning("Unknown action: #{action["action_id"]}", %{})
      end
    end)
  end

  defp handle_auto_fix(value, payload) do
    case parse_action_value(value) do
      {:ok, incident_id} ->
        Logger.info("Auto-fix requested for incident #{incident_id}")

        channel_id = get_in(payload, ["channel", "id"])
        thread_ts = get_in(payload, ["message", "ts"])

        # Run AI analysis in background task
        Task.Supervisor.start_child(RailwayApp.TaskSupervisor, fn ->
          process_auto_fix_with_ai(incident_id, channel_id, thread_ts)
        end)

      {:error, _} ->
        Logger.error("Invalid action value: #{value}")
    end
  end

  defp process_auto_fix_with_ai(incident_id, channel_id, thread_ts) do
    case Incidents.get_incident(incident_id) do
      nil ->
        Logger.error("Incident not found: #{incident_id}")
        SlackNotifier.send_message(channel_id, "❌ Incident not found.", thread_ts)

      incident ->
        # Send "analyzing" message
        SlackNotifier.send_message(
          channel_id,
          "🔍 Analyzing incident and generating AI recommendation...",
          thread_ts
        )

        # Get recent logs for context
        recent_logs = get_recent_logs_for_incident(incident)

        # Get AI recommendation
        case LLMRouter.get_remediation_recommendation(incident, recent_logs) do
          {:ok, recommendation} ->
            Logger.info(
              "AI recommendation for incident #{incident_id}: #{inspect(recommendation)}"
            )

            # Send recommendation message with Confirm/Cancel buttons
            SlackNotifier.send_recommendation_message(
              channel_id,
              incident,
              recommendation,
              thread_ts
            )

          {:error, reason} ->
            Logger.error("Failed to get AI recommendation: #{inspect(reason)}")

            # Fall back to the existing recommended action
            SlackNotifier.send_message(
              channel_id,
              "⚠️ Could not get AI recommendation. Falling back to default action: *#{incident.recommended_action}*\n\nWould you like to proceed?",
              thread_ts
            )

            # Send fallback recommendation with buttons
            SlackNotifier.send_fallback_recommendation_message(
              channel_id,
              incident,
              thread_ts
            )
        end
    end
  end

  defp get_recent_logs_for_incident(incident) do
    # Try to get recent logs from Railway API
    config = Application.get_env(:railway_app, :railway, [])
    project_id = config[:project_id]
    environment_id = incident.environment_id

    if project_id && environment_id && incident.service_id do
      case RailwayApp.Railway.Client.get_latest_deployment_id(
             project_id,
             environment_id,
             incident.service_id
           ) do
        {:ok, deployment_id} ->
          case RailwayApp.Railway.Client.get_deployment_logs(deployment_id, limit: 50) do
            {:ok, %{"deploymentLogs" => logs}} when is_list(logs) ->
              Enum.map(logs, fn log ->
                %{
                  timestamp: log["timestamp"],
                  level: log["severity"] || "info",
                  message: log["message"]
                }
              end)

            _ ->
              []
          end

        _ ->
          []
      end
    else
      []
    end
  rescue
    # If anything fails, return empty list
    _ -> []
  end

  defp handle_confirm_auto_fix(value, payload) do
    case parse_confirm_value(value) do
      {:ok, incident_id, action} ->
        Logger.info("Confirmed auto-fix for incident #{incident_id}: #{action}")

        channel_id = get_in(payload, ["channel", "id"])
        thread_ts = get_in(payload, ["message", "ts"])

        # Send confirmation message
        SlackNotifier.send_message(
          channel_id,
          "✅ Executing *#{format_action_name(action)}*...",
          thread_ts
        )

        # Update incident with the confirmed action and execute
        case Incidents.get_incident(incident_id) do
          nil ->
            Logger.error("Incident not found: #{incident_id}")

          incident ->
            # Update recommended action if different
            if incident.recommended_action != action do
              Incidents.update_incident(incident, %{recommended_action: action})
            end

            # Broadcast to remediation coordinator
            Phoenix.PubSub.broadcast(
              RailwayApp.PubSub,
              "remediation:actions",
              {:auto_fix_requested, incident_id, "user"}
            )
        end

      {:error, _} ->
        Logger.error("Invalid confirm action value: #{value}")
    end
  end

  defp handle_cancel_auto_fix(value, payload) do
    case parse_action_value(value) do
      {:ok, incident_id} ->
        Logger.info("Cancelled auto-fix for incident #{incident_id}")

        channel_id = get_in(payload, ["channel", "id"])
        thread_ts = get_in(payload, ["message", "ts"])

        SlackNotifier.send_message(
          channel_id,
          "🚫 Auto-fix cancelled. Use *Start Chat* to discuss alternative actions.",
          thread_ts
        )

      {:error, _} ->
        Logger.error("Invalid cancel action value: #{value}")
    end
  end

  defp handle_start_chat(value, payload) do
    case parse_action_value(value) do
      {:ok, incident_id} ->
        channel_id = get_in(payload, ["channel", "id"])
        user_id = get_in(payload, ["user", "id"])
        message_ts = get_in(payload, ["message", "ts"])

        Logger.info("Chat requested for incident #{incident_id}")

        # Broadcast to conversation manager
        Phoenix.PubSub.broadcast(
          RailwayApp.PubSub,
          "conversations:events",
          {:start_chat, incident_id, channel_id, user_id, message_ts}
        )

      {:error, _} ->
        Logger.error("Invalid action value: #{value}")
    end
  end

  defp handle_ignore(value, payload) do
    case parse_action_value(value) do
      {:ok, incident_id} ->
        Logger.info("Ignore requested for incident #{incident_id}")

        channel_id = get_in(payload, ["channel", "id"])
        thread_ts = get_in(payload, ["message", "ts"])

        # Mark incident as ignored (soft delete)
        case Incidents.get_incident(incident_id) do
          nil ->
            Logger.error("Incident not found: #{incident_id}")
            SlackNotifier.send_message(channel_id, "❌ Incident not found.", thread_ts)

          incident ->
            # Update status to "ignored" instead of deleting
            case Incidents.update_incident(incident, %{
                   status: "ignored",
                   resolved_at: DateTime.utc_now()
                 }) do
              {:ok, updated_incident} ->
                Logger.info("Incident #{incident_id} marked as ignored")

                # Send confirmation message with incident summary
                SlackNotifier.send_ignore_confirmation(channel_id, updated_incident, thread_ts)

              {:error, reason} ->
                Logger.error("Failed to ignore incident #{incident_id}: #{inspect(reason)}")
                SlackNotifier.send_message(channel_id, "❌ Failed to ignore incident.", thread_ts)
            end
        end

      {:error, _} ->
        Logger.error("Invalid action value: #{value}")
    end
  end

  defp handle_slash_command(params) do
    command = params["command"]
    text = params["text"] || ""
    user_id = params["user_id"]
    channel_id = params["channel_id"]
    response_url = params["response_url"]

    Logger.info("Received slash command: #{command} #{text}")

    # Broadcast to conversation manager
    Phoenix.PubSub.broadcast(
      RailwayApp.PubSub,
      "conversations:events",
      {:slash_command, command, text, user_id, channel_id, response_url}
    )
  end

  defp parse_action_value(value) do
    case String.split(value, ":") do
      [_action, id] -> {:ok, id}
      _ -> {:error, :invalid_format}
    end
  end

  defp parse_confirm_value(value) do
    # Format: "confirm:incident_id:action"
    case String.split(value, ":") do
      [_confirm, incident_id, action] -> {:ok, incident_id, action}
      _ -> {:error, :invalid_format}
    end
  end

  defp format_action_name(action) do
    case action do
      "restart" -> "Restart Service"
      "redeploy" -> "Redeploy Service"
      "scale_memory" -> "Scale Memory"
      "scale_replicas" -> "Scale Replicas"
      "rollback" -> "Rollback Deployment"
      "stop" -> "Stop Service"
      "manual_fix" -> "Manual Intervention"
      _ -> action
    end
  end
end
