defmodule RailwayApp.Conversations.ConversationManagerTest do
  use RailwayApp.DataCase, async: false

  alias RailwayApp.Conversations
  alias RailwayApp.{Incidents, ServiceConfigs}

  setup do
    # Create test service config
    {:ok, service_config} =
      ServiceConfigs.create_service_config(%{
        service_id: "test-service-789",
        service_name: "Test Service",
        auto_remediation_enabled: false
      })

    # Create test incident
    {:ok, incident} =
      Incidents.create_incident(%{
        service_id: service_config.service_id,
        service_name: service_config.service_name,
        signature: "conv-test-#{System.unique_integer()}",
        severity: "high",
        recommended_action: "restart",
        detected_at: DateTime.utc_now(),
        service_config_id: service_config.id
      })

    {:ok, incident: incident, service_config: service_config}
  end

  # =============================================================================
  # Conversation Sessions
  # =============================================================================

  describe "conversation sessions" do
    test "creates session for new chat", %{incident: incident} do
      channel_id = "C#{System.unique_integer([:positive])}"
      user_id = "U123456"
      thread_ts = "#{System.unique_integer([:positive])}.123456"

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:start_chat, incident.id, channel_id, user_id, thread_ts}
      )

      Process.sleep(500)

      session_key = "#{channel_id}:#{thread_ts}"
      session = Conversations.get_session_by_channel_ref(session_key)

      assert session != nil
      assert session.incident_id == incident.id
      assert session.channel == "slack"
      assert session.participant_id == user_id
      assert session.closed_at == nil
    end

    test "creates system message when starting chat", %{incident: incident} do
      channel_id = "C#{System.unique_integer([:positive])}"
      user_id = "U123456"
      thread_ts = "#{System.unique_integer([:positive])}.123456"

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:start_chat, incident.id, channel_id, user_id, thread_ts}
      )

      Process.sleep(500)

      session_key = "#{channel_id}:#{thread_ts}"
      session = Conversations.get_session_by_channel_ref(session_key)

      messages = Conversations.list_messages(session.id)
      assert length(messages) > 0

      system_msg = Enum.find(messages, fn msg -> msg.role == "system" end)
      assert system_msg != nil
      assert String.contains?(system_msg.content, "Chat session started")
    end

    test "reuses existing session for same channel_ref", %{incident: incident} do
      channel_id = "C#{System.unique_integer([:positive])}"
      user_id = "U123456"
      thread_ts = "#{System.unique_integer([:positive])}.123456"

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:start_chat, incident.id, channel_id, user_id, thread_ts}
      )

      Process.sleep(300)

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:start_chat, incident.id, channel_id, user_id, thread_ts}
      )

      Process.sleep(300)

      session_key = "#{channel_id}:#{thread_ts}"
      session = Conversations.get_session_by_channel_ref(session_key)
      assert session != nil

      all_sessions = Conversations.list_sessions(100)
      matching = Enum.filter(all_sessions, fn s -> s.channel_ref == session_key end)
      assert length(matching) == 1
    end
  end

  # =============================================================================
  # Slash Command Handling
  # =============================================================================

  describe "slash command handling" do
    test "processes slash command and creates session" do
      command = "/tessera"
      text = "restart test-service"
      user_id = "U#{System.unique_integer([:positive])}"
      channel_id = "C#{System.unique_integer([:positive])}"
      response_url = "https://hooks.slack.com/commands/test"

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:slash_command, command, text, user_id, channel_id, response_url}
      )

      Process.sleep(500)

      session_key = "#{channel_id}:slash:#{user_id}"
      session = Conversations.get_session_by_channel_ref(session_key)

      assert session != nil
      assert session.channel == "slack"
      assert session.participant_id == user_id
    end

    test "creates user message for slash command" do
      command = "/tessera"
      text = "status api-service"
      user_id = "U#{System.unique_integer([:positive])}"
      channel_id = "C#{System.unique_integer([:positive])}"
      response_url = "https://hooks.slack.com/commands/test"

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:slash_command, command, text, user_id, channel_id, response_url}
      )

      Process.sleep(500)

      session_key = "#{channel_id}:slash:#{user_id}"
      session = Conversations.get_session_by_channel_ref(session_key)

      messages = Conversations.list_messages(session.id)
      user_messages = Enum.filter(messages, fn msg -> msg.role == "user" end)

      assert length(user_messages) > 0
      user_msg = List.first(user_messages)
      assert user_msg.content == text
    end

    test "handles help command" do
      command = "/tessera"
      text = "help"
      user_id = "U#{System.unique_integer([:positive])}"
      channel_id = "C#{System.unique_integer([:positive])}"
      response_url = "https://hooks.slack.com/commands/test"

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:slash_command, command, text, user_id, channel_id, response_url}
      )

      Process.sleep(500)

      session_key = "#{channel_id}:slash:#{user_id}"
      session = Conversations.get_session_by_channel_ref(session_key)

      messages = Conversations.list_messages(session.id)
      assert length(messages) > 0
    end

    test "handles restart command" do
      command = "/tessera"
      text = "restart"
      user_id = "U#{System.unique_integer([:positive])}"
      channel_id = "C#{System.unique_integer([:positive])}"
      response_url = "https://hooks.slack.com/commands/test"

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:slash_command, command, text, user_id, channel_id, response_url}
      )

      Process.sleep(500)

      session_key = "#{channel_id}:slash:#{user_id}"
      session = Conversations.get_session_by_channel_ref(session_key)
      assert session != nil
    end

    test "handles scale memory command" do
      command = "/tessera"
      text = "scale memory 2048"
      user_id = "U#{System.unique_integer([:positive])}"
      channel_id = "C#{System.unique_integer([:positive])}"
      response_url = "https://hooks.slack.com/commands/test"

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:slash_command, command, text, user_id, channel_id, response_url}
      )

      Process.sleep(500)

      session_key = "#{channel_id}:slash:#{user_id}"
      session = Conversations.get_session_by_channel_ref(session_key)
      assert session != nil
    end

    test "handles scale replicas command" do
      command = "/tessera"
      text = "scale replicas 3"
      user_id = "U#{System.unique_integer([:positive])}"
      channel_id = "C#{System.unique_integer([:positive])}"
      response_url = "https://hooks.slack.com/commands/test"

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:slash_command, command, text, user_id, channel_id, response_url}
      )

      Process.sleep(500)

      session_key = "#{channel_id}:slash:#{user_id}"
      session = Conversations.get_session_by_channel_ref(session_key)
      assert session != nil
    end

    test "handles rollback command" do
      command = "/tessera"
      text = "rollback"
      user_id = "U#{System.unique_integer([:positive])}"
      channel_id = "C#{System.unique_integer([:positive])}"
      response_url = "https://hooks.slack.com/commands/test"

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:slash_command, command, text, user_id, channel_id, response_url}
      )

      Process.sleep(500)

      session_key = "#{channel_id}:slash:#{user_id}"
      session = Conversations.get_session_by_channel_ref(session_key)
      assert session != nil
    end

    test "handles status command" do
      command = "/tessera"
      text = "status"
      user_id = "U#{System.unique_integer([:positive])}"
      channel_id = "C#{System.unique_integer([:positive])}"
      response_url = "https://hooks.slack.com/commands/test"

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:slash_command, command, text, user_id, channel_id, response_url}
      )

      Process.sleep(500)

      session_key = "#{channel_id}:slash:#{user_id}"
      session = Conversations.get_session_by_channel_ref(session_key)
      assert session != nil
    end

    test "handles logs command" do
      command = "/tessera"
      text = "logs"
      user_id = "U#{System.unique_integer([:positive])}"
      channel_id = "C#{System.unique_integer([:positive])}"
      response_url = "https://hooks.slack.com/commands/test"

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:slash_command, command, text, user_id, channel_id, response_url}
      )

      Process.sleep(500)

      session_key = "#{channel_id}:slash:#{user_id}"
      session = Conversations.get_session_by_channel_ref(session_key)
      assert session != nil
    end

    test "handles deployments command" do
      command = "/tessera"
      text = "deployments"
      user_id = "U#{System.unique_integer([:positive])}"
      channel_id = "C#{System.unique_integer([:positive])}"
      response_url = "https://hooks.slack.com/commands/test"

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:slash_command, command, text, user_id, channel_id, response_url}
      )

      Process.sleep(500)

      session_key = "#{channel_id}:slash:#{user_id}"
      session = Conversations.get_session_by_channel_ref(session_key)
      assert session != nil
    end

    test "handles stop command" do
      command = "/tessera"
      text = "stop"
      user_id = "U#{System.unique_integer([:positive])}"
      channel_id = "C#{System.unique_integer([:positive])}"
      response_url = "https://hooks.slack.com/commands/test"

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:slash_command, command, text, user_id, channel_id, response_url}
      )

      Process.sleep(500)

      session_key = "#{channel_id}:slash:#{user_id}"
      session = Conversations.get_session_by_channel_ref(session_key)
      assert session != nil
    end

    test "handles redeploy command" do
      command = "/tessera"
      text = "redeploy"
      user_id = "U#{System.unique_integer([:positive])}"
      channel_id = "C#{System.unique_integer([:positive])}"
      response_url = "https://hooks.slack.com/commands/test"

      Phoenix.PubSub.broadcast(
        RailwayApp.PubSub,
        "conversations:events",
        {:slash_command, command, text, user_id, channel_id, response_url}
      )

      Process.sleep(500)

      session_key = "#{channel_id}:slash:#{user_id}"
      session = Conversations.get_session_by_channel_ref(session_key)
      assert session != nil
    end
  end

  # =============================================================================
  # Message Persistence
  # =============================================================================

  describe "message persistence" do
    test "creates and retrieves messages in order" do
      {:ok, session} =
        Conversations.create_session(%{
          channel: "slack",
          channel_ref: "test-#{System.unique_integer()}",
          participant_id: "U123",
          started_at: DateTime.utc_now()
        })

      messages_data = [
        {DateTime.utc_now() |> DateTime.add(-3, :second), "user", "Hello"},
        {DateTime.utc_now() |> DateTime.add(-2, :second), "assistant", "Hi there!"},
        {DateTime.utc_now() |> DateTime.add(-1, :second), "user", "Need help"}
      ]

      Enum.each(messages_data, fn {timestamp, role, content} ->
        Conversations.create_message(%{
          session_id: session.id,
          role: role,
          content: content,
          timestamp: timestamp
        })
      end)

      messages = Conversations.list_messages(session.id)

      assert length(messages) == 3
      assert Enum.at(messages, 0).content == "Hello"
      assert Enum.at(messages, 1).content == "Hi there!"
      assert Enum.at(messages, 2).content == "Need help"
    end

    test "gets latest message" do
      {:ok, session} =
        Conversations.create_session(%{
          channel: "slack",
          channel_ref: "test-latest-#{System.unique_integer()}",
          participant_id: "U456",
          started_at: DateTime.utc_now()
        })

      Conversations.create_message(%{
        session_id: session.id,
        role: "user",
        content: "First message",
        timestamp: DateTime.utc_now() |> DateTime.add(-2, :second)
      })

      Conversations.create_message(%{
        session_id: session.id,
        role: "assistant",
        content: "Latest message",
        timestamp: DateTime.utc_now()
      })

      latest = Conversations.get_latest_message(session.id)
      assert latest.content == "Latest message"
      assert latest.role == "assistant"
    end
  end

  # =============================================================================
  # Session Management
  # =============================================================================

  describe "session management" do
    test "closes session" do
      {:ok, session} =
        Conversations.create_session(%{
          channel: "slack",
          channel_ref: "close-test-#{System.unique_integer()}",
          participant_id: "U789",
          started_at: DateTime.utc_now()
        })

      assert session.closed_at == nil

      {:ok, closed_session} = Conversations.close_session(session)

      assert closed_session.closed_at != nil
      assert DateTime.compare(closed_session.closed_at, session.started_at) in [:gt, :eq]
    end

    test "updates session context" do
      {:ok, session} =
        Conversations.create_session(%{
          channel: "slack",
          channel_ref: "context-test-#{System.unique_integer()}",
          participant_id: "U111",
          started_at: DateTime.utc_now(),
          context: %{}
        })

      new_context = %{last_command: "restart", service: "api-service"}
      {:ok, updated} = Conversations.update_session(session, %{context: new_context})

      assert updated.context == new_context
    end

    test "lists recent sessions" do
      Enum.each(1..5, fn i ->
        Conversations.create_session(%{
          channel: "slack",
          channel_ref: "list-test-#{i}-#{System.unique_integer()}",
          participant_id: "U#{i}",
          started_at: DateTime.utc_now()
        })
      end)

      sessions = Conversations.list_sessions(10)
      assert length(sessions) >= 5
    end
  end

  # =============================================================================
  # Data Cleanup
  # =============================================================================

  describe "data cleanup" do
    test "deletes old conversations" do
      old_timestamp = DateTime.utc_now() |> DateTime.add(-91 * 24 * 60 * 60, :second)

      {:ok, old_session} =
        Conversations.create_session(%{
          channel: "slack",
          channel_ref: "old-#{System.unique_integer()}",
          participant_id: "UOLD",
          started_at: old_timestamp
        })

      {:ok, recent_session} =
        Conversations.create_session(%{
          channel: "slack",
          channel_ref: "recent-#{System.unique_integer()}",
          participant_id: "URECENT",
          started_at: DateTime.utc_now()
        })

      {deleted_count, _} = Conversations.delete_old_conversations(90)

      assert deleted_count >= 1
      assert Conversations.get_session(recent_session.id) != nil
      assert Conversations.get_session(old_session.id) == nil
    end
  end
end
