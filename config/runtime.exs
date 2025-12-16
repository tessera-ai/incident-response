import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/railway_app start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :railway_app, RailwayAppWeb.Endpoint, server: true
end

# Always enable server in production
if config_env() == :prod do
  config :railway_app, RailwayAppWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :railway_app, RailwayApp.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20"),
    # Allow requests to wait longer in queue instead of timing out immediately
    queue_target: String.to_integer(System.get_env("DB_QUEUE_TARGET") || "5000"),
    queue_interval: String.to_integer(System.get_env("DB_QUEUE_INTERVAL") || "1000"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || System.get_env("RAILWAY_PUBLIC_DOMAIN") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :railway_app, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # Configure endpoint for production
  config :railway_app, RailwayAppWeb.Endpoint,
    url: [host: host, port: port],
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base,
    check_origin: false,
    server: true

  # Railway integration (required in prod)
  config :railway_app, :railway,
    api_token: System.get_env("RAILWAY_API_TOKEN"),
    # Optional: Only needed if this app itself should be monitored (rare case)
    project_id: System.get_env("RAILWAY_PROJECT_ID"),
    environment_id: System.get_env("RAILWAY_ENVIRONMENT_ID"),
    # For monitoring external services (comma-separated list) - PRIMARY METHOD
    monitored_services: System.get_env("RAILWAY_MONITORED_PROJECTS"),
    monitored_environments: System.get_env("RAILWAY_MONITORED_ENVIRONMENTS"),
    graphql_endpoint:
      System.get_env("RAILWAY_GRAPHQL_ENDPOINT") || "https://backboard.railway.app/graphql/v2",
    websocket_endpoint:
      System.get_env("RAILWAY_WS_ENDPOINT") || "wss://backboard.railway.app/graphql/v2",
    # Performance and connection settings per specifications
    # 30 seconds
    connection_timeout:
      String.to_integer(System.get_env("RAILWAY_CONNECTION_TIMEOUT") || "30000"),
    max_retry_attempts: String.to_integer(System.get_env("RAILWAY_MAX_RETRY_ATTEMPTS") || "10"),
    # 60 seconds
    max_backoff_interval: String.to_integer(System.get_env("RAILWAY_MAX_BACKOFF") || "60000"),
    # 30 seconds
    heartbeat_interval:
      String.to_integer(System.get_env("RAILWAY_HEARTBEAT_INTERVAL") || "30000"),
    # 45 seconds
    heartbeat_timeout: String.to_integer(System.get_env("RAILWAY_HEARTBEAT_TIMEOUT") || "45000"),
    # Rate limiting per Railway Pro tier limits
    rate_limit_requests_per_hour:
      String.to_integer(System.get_env("RAILWAY_RATE_LIMIT_HR") || "10000"),
    rate_limit_requests_per_second:
      String.to_integer(System.get_env("RAILWAY_RATE_LIMIT_SEC") || "50"),
    # Log ingestion settings per specifications
    # Service state polling
    polling_interval_seconds:
      String.to_integer(System.get_env("RAILWAY_POLLING_INTERVAL") || "30"),
    batch_min_size: String.to_integer(System.get_env("RAILWAY_BATCH_MIN_SIZE") || "10"),
    batch_max_size: String.to_integer(System.get_env("RAILWAY_BATCH_MAX_SIZE") || "1000"),
    batch_window_min_seconds:
      String.to_integer(System.get_env("RAILWAY_BATCH_WINDOW_MIN") || "5"),
    batch_window_max_seconds:
      String.to_integer(System.get_env("RAILWAY_BATCH_WINDOW_MAX") || "300"),
    buffer_retention_hours: String.to_integer(System.get_env("RAILWAY_BUFFER_RETENTION") || "24"),
    memory_limit_mb: String.to_integer(System.get_env("RAILWAY_MEMORY_LIMIT") || "512")

  # Slack integration (required in prod)
  config :railway_app, :slack,
    bot_token: System.get_env("SLACK_BOT_TOKEN"),
    signing_secret: System.get_env("SLACK_SIGNING_SECRET"),
    channel_id: System.get_env("SLACK_CHANNEL_ID")

  # LLM providers (OpenAI required in prod)
  openai_api_key =
    System.get_env("OPENAI_API_KEY") ||
      raise """
      environment variable OPENAI_API_KEY is missing.
      OpenAI API key is required to start the application.
      """

  config :railway_app, :llm,
    default_provider: System.get_env("LLM_DEFAULT_PROVIDER") || "openai",
    openai_api_key: openai_api_key,
    anthropic_api_key: System.get_env("ANTHROPIC_API_KEY")
end

# Configuration for dev and test environments (no required env vars)
if config_env() in [:dev, :test] do
  # Railway integration (optional in dev/test)
  config :railway_app, :railway,
    api_token: System.get_env("RAILWAY_API_TOKEN"),
    project_id: System.get_env("RAILWAY_PROJECT_ID"),
    environment_id: System.get_env("RAILWAY_ENVIRONMENT_ID"),
    graphql_endpoint:
      System.get_env("RAILWAY_GRAPHQL_ENDPOINT") || "https://backboard.railway.app/graphql/v2",
    websocket_endpoint:
      System.get_env("RAILWAY_WS_ENDPOINT") || "wss://backboard.railway.app/graphql/v2",
    # Performance and connection settings (dev/test defaults)
    # 30 seconds
    connection_timeout: 30000,
    max_retry_attempts: 10,
    # 60 seconds
    max_backoff_interval: 60000,
    # 30 seconds
    heartbeat_interval: 30000,
    # 45 seconds
    heartbeat_timeout: 45000,
    # Rate limiting settings
    rate_limit_requests_per_hour: 10000,
    rate_limit_requests_per_second: 50,
    # Log ingestion settings
    # Service state polling
    polling_interval_seconds: 30,
    batch_min_size: 10,
    batch_max_size: 1000,
    batch_window_min_seconds: 5,
    batch_window_max_seconds: 300,
    buffer_retention_hours: 24,
    memory_limit_mb: 512

  # Slack integration (optional in dev/test)
  config :railway_app, :slack,
    bot_token: System.get_env("SLACK_BOT_TOKEN"),
    signing_secret: System.get_env("SLACK_SIGNING_SECRET"),
    channel_id: System.get_env("SLACK_CHANNEL_ID")

  # LLM providers (optional in dev/test, defaults to OpenAI)
  config :railway_app, :llm,
    default_provider: System.get_env("LLM_DEFAULT_PROVIDER") || "openai",
    openai_api_key: System.get_env("OPENAI_API_KEY"),
    anthropic_api_key: System.get_env("ANTHROPIC_API_KEY")

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :railway_app, RailwayAppWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :railway_app, RailwayAppWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :railway_app, RailwayApp.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
