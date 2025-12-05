# Railway Agent

An intelligent DevOps assistant that monitors Railway-hosted services, detects production incidents, and automates remediation actions with Slack integration.

## Features

- **🔍 Incident Detection**: Automatically detects incidents from Railway log streams using pattern matching and LLM analysis
- **🚨 Smart Alerting**: Sends contextual incident alerts to Slack with severity, root cause analysis, and recommended actions
- **🤖 Auto-Remediation**: Executes safe recovery actions (restart, scale, rollback) with configurable confidence thresholds
- **💬 Conversational Interface**: Natural language commands via Slack for diagnostics and manual remediation
- **📊 Dashboard**: Real-time LiveView dashboard showing incidents, remediation actions, and service configurations
- **🔒 Audit Trail**: Complete history of all incidents, actions, and conversations for compliance and post-mortems

## Quick Start

### 1. Deploy the Template

Click the "Deploy on Railway" button to deploy this template to your Railway account.

### 2. Configure Environment Variables

After deployment, go to your service's **Variables** tab in Railway and configure the following:

#### Required Variables

| Variable            | Description                                | How to Get It                                                           |
| ------------------- | ------------------------------------------ | ----------------------------------------------------------------------- |
| `DATABASE_URL`      | PostgreSQL connection string               | Auto-configured if you added the Postgres plugin                        |
| `SECRET_KEY_BASE`   | Phoenix secret key                         | Generate with `mix phx.gen.secret` or use a 64+ character random string |
| `RAILWAY_API_TOKEN` | Railway API token for log streaming        | [Get from Railway](#getting-your-railway-api-token)                     |
| `OPENAI_API_KEY`    | OpenAI API key (required for LLM analysis) | [Get from OpenAI](#getting-your-openai-api-key)                         |

#### Slack Integration (Required for Alerts)

| Variable               | Description                           | How to Get It                                     |
| ---------------------- | ------------------------------------- | ------------------------------------------------- |
| `SLACK_BOT_TOKEN`      | Slack bot token (starts with `xoxb-`) | [Setup Slack App](#setting-up-slack)              |
| `SLACK_SIGNING_SECRET` | Slack app signing secret              | [Setup Slack App](#setting-up-slack)              |
| `SLACK_CHANNEL_ID`     | Channel ID for incident alerts        | [Find Channel ID](#finding-your-slack-channel-id) |

#### External Service Monitoring

| Variable                         | Description                                         | How to Get It                                         |
| -------------------------------- | --------------------------------------------------- | ----------------------------------------------------- |
| `RAILWAY_MONITORED_PROJECTS`     | Comma-separated Railway project IDs to monitor      | [Find Project IDs](#finding-your-railway-project-ids) |
| `RAILWAY_MONITORED_ENVIRONMENTS` | (Optional) Comma-separated environments per project | Defaults to `production`                              |

#### Optional Variables

| Variable               | Default  | Description                            |
| ---------------------- | -------- | -------------------------------------- |
| `LLM_DEFAULT_PROVIDER` | `openai` | LLM provider (`openai` or `anthropic`) |
| `ANTHROPIC_API_KEY`    | -        | Anthropic API key (if using Claude)    |
| `POOL_SIZE`            | `10`     | Database connection pool size          |

---

## Getting Your API Keys & Tokens

### Getting Your Railway API Token

1. Go to [Railway Dashboard](https://railway.app/account/tokens)
2. Click **"Create Token"**
3. Give it a name (e.g., "Railway Agent")
4. Copy the token and save it as `RAILWAY_API_TOKEN`

> **Note**: The token needs read access to the projects you want to monitor.

### Finding Your Railway Project IDs

1. Go to [Railway Dashboard](https://railway.app)
2. Select the project you want to monitor
3. Go to **Settings** → Copy the **Project ID**
4. Add it to `RAILWAY_MONITORED_PROJECTS`

**Example configurations:**

```bash
# Monitor a single project
RAILWAY_MONITORED_PROJECTS=proj_abc123

# Monitor multiple projects
RAILWAY_MONITORED_PROJECTS=proj_abc123,proj_def456,proj_ghi789

# With specific environments (optional)
RAILWAY_MONITORED_ENVIRONMENTS=production,staging,production
```

### Getting Your OpenAI API Key

1. Go to [OpenAI API Keys](https://platform.openai.com/api-keys)
2. Click **"Create new secret key"**
3. Copy the key (starts with `sk-`) and save it as `OPENAI_API_KEY`

---

## Setting Up Slack

### Step 1: Create a Slack App

1. Go to [Slack API Apps](https://api.slack.com/apps)
2. Click **"Create New App"** → **"From scratch"**
3. Name it (e.g., "Railway Agent") and select your workspace
4. Click **"Create App"**

### Step 2: Configure Bot Token Scopes

1. In your app settings, go to **OAuth & Permissions**
2. Under **Bot Token Scopes**, add:
   - `chat:write` - Send messages
   - `commands` - Slash commands
   - `im:history` - Read DM history (for conversations)

### Step 3: Enable Interactivity

1. Go to **Interactivity & Shortcuts**
2. Turn on **Interactivity**
3. Set the **Request URL** to:
   ```
   https://your-app.railway.app/api/slack/interactive
   ```
   (Replace `your-app.railway.app` with your actual Railway domain)

### Step 4: Add Slash Command (Optional)

1. Go to **Slash Commands**
2. Click **"Create New Command"**
3. Configure:
   - **Command**: `/tessera` (or your preferred name)
   - **Request URL**: `https://your-app.railway.app/api/slack/slash`
   - **Description**: "Interact with Railway Agent"

### Step 5: Install to Workspace

1. Go to **OAuth & Permissions**
2. Click **"Install to Workspace"**
3. Authorize the app

### Step 6: Get Your Credentials

After installation:

| Credential             | Where to Find                                                            |
| ---------------------- | ------------------------------------------------------------------------ |
| `SLACK_BOT_TOKEN`      | **OAuth & Permissions** → **Bot User OAuth Token** (starts with `xoxb-`) |
| `SLACK_SIGNING_SECRET` | **Basic Information** → **App Credentials** → **Signing Secret**         |

### Finding Your Slack Channel ID

1. Open Slack and go to the channel where you want alerts
2. Right-click the channel name → **"View channel details"**
3. At the bottom of the popup, copy the **Channel ID** (starts with `C`)

> **Important**: Invite the bot to your channel! Type `/invite @YourBotName` in the channel.

---

## Usage

### Automatic Monitoring

Once configured, Railway Agent automatically:

1. Connects to Railway log streams for your monitored projects
2. Analyzes logs for error patterns and anomalies
3. Sends Slack alerts when incidents are detected
4. Suggests (or automatically executes) remediation actions

### Slack Alerts

When an incident is detected, you'll receive a Slack message with:

- **Severity** and **confidence level**
- **Root cause analysis**
- **Suggested remediation action**
- Action buttons:
  - **Auto-Fix** - Execute suggested remediation
  - **Start Chat** - Begin conversational troubleshooting
  - **View Logs** - Open Railway logs
  - **Ignore** - Dismiss the alert

### Slash Commands

Use the `/tessera` command (or your configured command) in Slack:

```
/tessera restart api-service
/tessera scale memory api-service 2048
/tessera rollback api-service
/tessera status api-service
```

### Dashboard

Access the dashboard at `https://your-app.railway.app/dashboard` to:

- View recent incidents and their status
- Toggle auto-remediation per service
- Monitor remediation action history
- Filter incidents by severity or status

---

## Troubleshooting

### No incidents detected

- Check that `RAILWAY_API_TOKEN` has access to the monitored projects
- Verify `RAILWAY_MONITORED_PROJECTS` contains valid project IDs
- Check Railway logs for WebSocket connection status

### Slack notifications not working

- Verify `SLACK_BOT_TOKEN` and `SLACK_SIGNING_SECRET` are correct
- Ensure the bot is invited to the target channel
- Check that `SLACK_CHANNEL_ID` is the channel ID (not the channel name)

### LLM analysis failing

- Verify `OPENAI_API_KEY` is valid and has credits
- Check for rate limits in the application logs
- Pattern-based detection continues even if LLM is unavailable

---

## Health Check

The app exposes a health endpoint at `/health`:

```bash
curl https://your-app.railway.app/health
```

Response:

```json
{
  "status": "healthy",
  "timestamp": "2025-12-05T12:00:00Z",
  "version": "0.1.0"
}
```

---

## License

MIT
