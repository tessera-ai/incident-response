defmodule RailwayAppWeb.DashboardLive do
  use RailwayAppWeb, :live_view

  alias RailwayApp.{Incidents, ServiceConfigs, RemediationActions, Conversations}

  @items_per_page 10

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RailwayApp.PubSub, "dashboard:incidents")
    end

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:filter_severity, nil)
      |> assign(:filter_status, nil)
      |> assign(:incidents_page, 1)
      |> assign(:remediation_page, 1)
      |> assign(:conversations_page, 1)
      |> assign(:services, ServiceConfigs.list_service_configs())
      |> assign(:selected_session_id, nil)
      |> assign(:selected_session_messages, [])
      |> load_incidents()
      |> load_remediation_actions()
      |> load_conversation_sessions()

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_incidents", params, socket) do
    severity_filter = if params["severity"] == "", do: nil, else: params["severity"]
    status_filter = if params["status"] == "", do: nil, else: params["status"]

    socket =
      socket
      |> assign(:filter_severity, severity_filter)
      |> assign(:filter_status, status_filter)
      |> assign(:incidents_page, 1)
      |> load_incidents()

    {:noreply, socket}
  end

  @impl true
  def handle_event("incidents_page", %{"page" => page}, socket) do
    page = String.to_integer(page)

    socket =
      socket
      |> assign(:incidents_page, page)
      |> load_incidents()

    {:noreply, socket}
  end

  @impl true
  def handle_event("remediation_page", %{"page" => page}, socket) do
    page = String.to_integer(page)

    socket =
      socket
      |> assign(:remediation_page, page)
      |> load_remediation_actions()

    {:noreply, socket}
  end

  @impl true
  def handle_event("conversations_page", %{"page" => page}, socket) do
    page = String.to_integer(page)

    socket =
      socket
      |> assign(:conversations_page, page)
      |> load_conversation_sessions()

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "toggle_auto_remediation",
        %{"service_id" => service_id, "enabled" => enabled_str},
        socket
      ) do
    enabled = enabled_str == "true"

    case ServiceConfigs.toggle_auto_remediation(service_id, enabled) do
      {:ok, _config} ->
        socket =
          socket
          |> put_flash(:info, "Auto-remediation #{if enabled, do: "enabled", else: "disabled"}")
          |> assign(:services, ServiceConfigs.list_service_configs())

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update configuration")}
    end
  end

  @impl true
  def handle_event("view_conversation", %{"session_id" => session_id}, socket) do
    messages = Conversations.list_messages(session_id)

    socket =
      socket
      |> assign(:selected_session_id, session_id)
      |> assign(:selected_session_messages, messages)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_conversation_view", _params, socket) do
    socket =
      socket
      |> assign(:selected_session_id, nil)
      |> assign(:selected_session_messages, [])

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_incident, incident}, socket) do
    # Check if incident matches current filters before adding
    matches_severity =
      is_nil(socket.assigns.filter_severity) ||
        incident.severity == socket.assigns.filter_severity

    matches_status =
      is_nil(socket.assigns.filter_status) || incident.status == socket.assigns.filter_status

    socket =
      if matches_severity && matches_status do
        socket
        |> put_flash(:info, "New incident detected: #{incident.service_name}")
        |> stream_insert(:incidents, incident, at: 0)
      else
        socket
      end

    {:noreply, socket}
  end

  defp load_incidents(socket) do
    filters =
      []
      |> maybe_add_filter(:severity, socket.assigns.filter_severity)
      |> maybe_add_filter(:status, socket.assigns.filter_status)

    page = socket.assigns.incidents_page || 1
    offset = (page - 1) * @items_per_page

    filters = Keyword.put(filters, :limit, @items_per_page) |> Keyword.put(:offset, offset)

    incidents = Incidents.list_incidents(filters)

    total_count =
      Incidents.count_incidents(
        []
        |> maybe_add_filter(:severity, socket.assigns.filter_severity)
        |> maybe_add_filter(:status, socket.assigns.filter_status)
      )

    total_pages = div(total_count + @items_per_page - 1, @items_per_page)

    socket
    |> assign(:incidents_empty?, incidents == [])
    |> assign(:incidents_total, total_count)
    |> assign(:incidents_total_pages, total_pages)
    |> stream(:incidents, incidents, reset: true)
  end

  defp load_remediation_actions(socket) do
    page = socket.assigns.remediation_page || 1
    offset = (page - 1) * @items_per_page

    actions = RemediationActions.list_recent(limit: @items_per_page, offset: offset)
    total_count = RemediationActions.count_remediation_actions()
    total_pages = div(total_count + @items_per_page - 1, @items_per_page)

    socket
    |> assign(:remediation_actions, actions)
    |> assign(:remediation_total, total_count)
    |> assign(:remediation_total_pages, total_pages)
  end

  defp load_conversation_sessions(socket) do
    page = socket.assigns.conversations_page || 1
    offset = (page - 1) * @items_per_page

    sessions = Conversations.list_sessions(limit: @items_per_page, offset: offset)
    total_count = Conversations.count_sessions()
    total_pages = div(total_count + @items_per_page - 1, @items_per_page)

    socket
    |> assign(:conversation_sessions, sessions)
    |> assign(:conversations_total, total_count)
    |> assign(:conversations_total_pages, total_pages)
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, key, value), do: [{key, value} | filters]

  defp pagination_controls(assigns) do
    ~H"""
    <div class="flex items-center justify-between mt-4">
      <div class="text-sm text-base-content/70">
        Showing {(assigns.page - 1) * assigns.items_per_page + 1} - {min(
          assigns.page * assigns.items_per_page,
          assigns.total
        )} of {assigns.total}
      </div>
      <div class="join">
        <button
          class="join-item btn btn-sm"
          phx-click={assigns.page_change_event}
          phx-value-page={max(1, assigns.page - 1)}
          disabled={assigns.page <= 1}
        >
          «
        </button>
        <%= for p <- max(1, assigns.page - 2)..min(assigns.total_pages, assigns.page + 2) do %>
          <button
            class={[
              "join-item btn btn-sm",
              p == assigns.page && "btn-active"
            ]}
            phx-click={assigns.page_change_event}
            phx-value-page={p}
          >
            {p}
          </button>
        <% end %>
        <button
          class="join-item btn btn-sm"
          phx-click={assigns.page_change_event}
          phx-value-page={min(assigns.total_pages, assigns.page + 1)}
          disabled={assigns.page >= assigns.total_pages}
        >
          »
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <div class="flex justify-between items-center">
          <h1 class="text-3xl font-bold">Dashboard</h1>
        </div>

        <div class="card bg-base-200 p-6">
          <h2 class="text-xl font-semibold mb-4">Service Configurations</h2>
          <div class="overflow-x-auto">
            <table class="table">
              <thead>
                <tr>
                  <th>Service Name</th>
                  <th>Service ID</th>
                  <th>Auto-Remediation</th>
                  <th>Confidence Threshold</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={service <- @services}>
                  <td>{service.service_name}</td>
                  <td class="font-mono text-sm">{service.service_id}</td>
                  <td>
                    <input
                      type="checkbox"
                      class="toggle toggle-primary"
                      checked={service.auto_remediation_enabled}
                      phx-click="toggle_auto_remediation"
                      phx-value-service_id={service.service_id}
                      phx-value-enabled={to_string(!service.auto_remediation_enabled)}
                    />
                  </td>
                  <td>{trunc(service.confidence_threshold * 100)}%</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="card bg-base-200 p-6">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-semibold">Recent Incidents</h2>
            <.form for={%{}} as={:filter} id="incident-filters" phx-change="filter_incidents">
              <div class="flex gap-2">
                <select
                  id="severity-filter"
                  class="select select-bordered select-sm"
                  name="severity"
                >
                  <option value="" selected={@filter_severity == nil}>All Severities</option>
                  <option value="critical" selected={@filter_severity == "critical"}>Critical</option>
                  <option value="high" selected={@filter_severity == "high"}>High</option>
                  <option value="medium" selected={@filter_severity == "medium"}>Medium</option>
                  <option value="low" selected={@filter_severity == "low"}>Low</option>
                </select>

                <select
                  id="status-filter"
                  class="select select-bordered select-sm"
                  name="status"
                >
                  <option value="" selected={@filter_status == nil}>All Statuses</option>
                  <option value="detected" selected={@filter_status == "detected"}>Detected</option>
                  <option value="awaiting_action" selected={@filter_status == "awaiting_action"}>
                    Awaiting Action
                  </option>
                  <option value="auto_remediated" selected={@filter_status == "auto_remediated"}>
                    Auto-Remediated
                  </option>
                  <option value="manual_resolved" selected={@filter_status == "manual_resolved"}>
                    Manual Resolved
                  </option>
                  <option value="failed" selected={@filter_status == "failed"}>Failed</option>
                </select>
              </div>
            </.form>
          </div>

          <div id="incidents" phx-update="stream">
            <div class="hidden only:block text-center py-8 text-base-content/50">
              No incidents yet
            </div>

            <div
              :for={{id, incident} <- @streams.incidents}
              id={id}
              class="card bg-base-100 p-4 mb-4 border-l-4"
              class={[
                incident.severity == "critical" && "border-error",
                incident.severity == "high" && "border-warning",
                incident.severity == "medium" && "border-info",
                incident.severity == "low" && "border-success"
              ]}
            >
              <div class="flex justify-between items-start">
                <div class="flex-1">
                  <div class="flex items-center gap-2 mb-2">
                    <span class={[
                      "badge",
                      incident.severity == "critical" && "badge-error",
                      incident.severity == "high" && "badge-warning",
                      incident.severity == "medium" && "badge-info",
                      incident.severity == "low" && "badge-success"
                    ]}>
                      {incident.severity}
                    </span>
                    <span class="badge badge-outline">{incident.status}</span>
                    <span class="font-semibold">{incident.service_name}</span>
                  </div>

                  <p class="text-sm mb-2">{incident.root_cause || "Analysis pending..."}</p>

                  <div class="text-xs text-base-content/70">
                    <span>Detected: {format_timestamp(incident.detected_at)}</span>
                    <%= if incident.confidence do %>
                      <span class="ml-4">Confidence: {trunc(incident.confidence * 100)}%</span>
                    <% end %>
                  </div>
                </div>

                <div class="flex flex-col gap-2 ml-4">
                  <span class="badge badge-sm">{format_action(incident.recommended_action)}</span>
                </div>
              </div>
            </div>
          </div>

          <%= if @incidents_total_pages > 1 do %>
            <.pagination_controls
              page={@incidents_page}
              total={@incidents_total}
              total_pages={@incidents_total_pages}
              items_per_page={10}
              page_change_event="incidents_page"
            />
          <% end %>
        </div>

        <div class="card bg-base-200 p-6">
          <h2 class="text-xl font-semibold mb-4">Recent Remediation Actions</h2>
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Incident</th>
                  <th>Action Type</th>
                  <th>Initiator</th>
                  <th>Status</th>
                  <th>Requested At</th>
                  <th>Result</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={action <- @remediation_actions}>
                  <td class="font-mono text-xs">
                    <%= if action.incident do %>
                      {action.incident.service_name}
                    <% else %>
                      N/A
                    <% end %>
                  </td>
                  <td>
                    <span class="badge badge-sm">{format_action(action.action_type)}</span>
                  </td>
                  <td>{action.initiator_type}</td>
                  <td>
                    <span class={[
                      "badge badge-sm",
                      action.status == "succeeded" && "badge-success",
                      action.status == "failed" && "badge-error",
                      action.status == "in_progress" && "badge-info",
                      action.status == "pending" && "badge-warning"
                    ]}>
                      {action.status}
                    </span>
                  </td>
                  <td class="text-xs">{format_timestamp(action.requested_at)}</td>
                  <td class="text-xs truncate max-w-xs">
                    {action.result_message || action.failure_reason || "-"}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <%= if @remediation_total_pages > 1 do %>
            <.pagination_controls
              page={@remediation_page}
              total={@remediation_total}
              total_pages={@remediation_total_pages}
              items_per_page={10}
              page_change_event="remediation_page"
            />
          <% end %>
        </div>

        <div class="card bg-base-200 p-6">
          <h2 class="text-xl font-semibold mb-4">Conversation Sessions</h2>
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Channel</th>
                  <th>Participant</th>
                  <th>Started</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={session <- @conversation_sessions}>
                  <td>{session.channel}</td>
                  <td class="font-mono text-xs">{session.participant_id}</td>
                  <td class="text-xs">{format_timestamp(session.started_at)}</td>
                  <td>
                    <span class={[
                      "badge badge-sm",
                      is_nil(session.closed_at) && "badge-success",
                      !is_nil(session.closed_at) && "badge-neutral"
                    ]}>
                      {if is_nil(session.closed_at), do: "Active", else: "Closed"}
                    </span>
                  </td>
                  <td>
                    <button
                      class="btn btn-xs btn-ghost"
                      phx-click="view_conversation"
                      phx-value-session_id={session.id}
                    >
                      View
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <%= if @conversations_total_pages > 1 do %>
            <.pagination_controls
              page={@conversations_page}
              total={@conversations_total}
              total_pages={@conversations_total_pages}
              items_per_page={10}
              page_change_event="conversations_page"
            />
          <% end %>
        </div>

        <%= if @selected_session_id do %>
          <div class="card bg-base-200 p-6">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl font-semibold">Conversation Transcript</h2>
              <button class="btn btn-sm btn-ghost" phx-click="close_conversation_view">
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </div>
            <div class="space-y-3 max-h-96 overflow-y-auto">
              <div
                :for={message <- @selected_session_messages}
                class={[
                  "p-3 rounded-lg",
                  message.role == "user" && "bg-primary text-primary-content ml-8",
                  message.role == "assistant" && "bg-base-300 mr-8",
                  message.role == "system" && "bg-info text-info-content text-sm text-center"
                ]}
              >
                <div class="flex justify-between items-start mb-1">
                  <span class="font-semibold text-xs uppercase">{message.role}</span>
                  <span class="text-xs opacity-70">{format_time(message.timestamp)}</span>
                </div>
                <p class="text-sm whitespace-pre-wrap">{message.content}</p>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp format_timestamp(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_time(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%H:%M:%S")
  end

  defp format_action(action) do
    case action do
      "restart" -> "Restart"
      "scale_memory" -> "Scale Memory"
      "scale_replicas" -> "Scale Replicas"
      "rollback" -> "Rollback"
      "manual_fix" -> "Manual Fix"
      "none" -> "No Action"
      _ -> action
    end
  end
end
