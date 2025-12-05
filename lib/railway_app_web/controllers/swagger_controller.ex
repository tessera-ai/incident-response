defmodule RailwayAppWeb.SwaggerController do
  use RailwayAppWeb, :controller

  @moduledoc """
  Controller to serve Swagger JSON specification and UI
  """

  def ui(conn, _params) do
    html(conn, """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Railway App API Documentation</title>
      <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@3.52.5/swagger-ui.css" />
      <style>
        html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
        *, *:before, *:after { box-sizing: inherit; }
        body { margin:0; background: #fafafa; }
      </style>
    </head>
    <body>
      <div id="swagger-ui"></div>
      <script src="https://unpkg.com/swagger-ui-dist@3.52.5/swagger-ui-bundle.js"></script>
      <script src="https://unpkg.com/swagger-ui-dist@3.52.5/swagger-ui-standalone-preset.js"></script>
      <script>
        window.onload = function() {
          const ui = SwaggerUIBundle({
            url: '/api/swagger.json',
            dom_id: '#swagger-ui',
            deepLinking: true,
            presets: [
              SwaggerUIBundle.presets.apis,
              SwaggerUIStandalonePreset
            ],
            plugins: [
              SwaggerUIBundle.plugins.DownloadUrl
            ],
            layout: "StandaloneLayout"
          });
        };
      </script>
    </body>
    </html>
    """)
  end

  def spec(conn, _params) do
    # Generate swagger spec from router
    spec =
      %{
        openapi: "3.0.0",
        info: %{
          version: "0.1.0",
          title: "Railway App API",
          description: "API for Railway App monitoring and incident management"
        },
        servers: [
          %{
            url: "http://localhost:4000",
            description: "Development server"
          },
          %{
            url: "https://${{RAILWAY_PUBLIC_DOMAIN}}",
            description: "Production server"
          }
        ],
        paths: %{
          "/health": %{
            "get" => %{
              "summary" => "Get application health status",
              "description" => "Returns the health status of the application and its components",
              "responses" => %{
                200 => %{
                  "description" => "Success",
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{"$ref" => "#/components/schemas/HealthResponse"}
                    }
                  }
                }
              }
            }
          },
          "/api/slack/interactive": %{
            "post" => %{
              "summary" => "Handle Slack interactive webhook",
              "description" => "Processes interactive components like button clicks from Slack",
              "requestBody" => %{
                "description" => "Slack webhook payload",
                "required" => true,
                "content" => %{
                  "application/json" => %{
                    "schema" => %{"type" => "string"}
                  }
                }
              },
              "responses" => %{
                200 => %{"description" => "Success"},
                400 => %{
                  "description" => "Bad request",
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{"$ref" => "#/components/schemas/ErrorResponse"}
                    }
                  }
                },
                401 => %{
                  "description" => "Unauthorized",
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{"$ref" => "#/components/schemas/ErrorResponse"}
                    }
                  }
                }
              }
            }
          },
          "/api/slack/slash": %{
            "post" => %{
              "summary" => "Handle Slack slash commands",
              "description" => "Processes slash commands invoked in Slack",
              "requestBody" => %{
                "required" => true,
                "content" => %{
                  "application/x-www-form-urlencoded" => %{
                    "schema" => %{
                      "type" => "object",
                      "required" => ["command", "user_id", "channel_id", "response_url"],
                      "properties" => %{
                        "command" => %{
                          "type" => "string",
                          "description" => "The command that was invoked"
                        },
                        "text" => %{
                          "type" => "string",
                          "description" => "The text following the command"
                        },
                        "user_id" => %{
                          "type" => "string",
                          "description" => "The user ID of the user who invoked the command"
                        },
                        "channel_id" => %{
                          "type" => "string",
                          "description" => "The channel ID where the command was invoked"
                        },
                        "response_url" => %{
                          "type" => "string",
                          "description" => "URL to send delayed responses"
                        }
                      }
                    }
                  }
                }
              },
              "responses" => %{
                200 => %{
                  "description" => "Success",
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{"$ref" => "#/components/schemas/SlackResponse"}
                    }
                  }
                },
                401 => %{
                  "description" => "Unauthorized",
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{"$ref" => "#/components/schemas/ErrorResponse"}
                    }
                  }
                }
              }
            }
          }
        },
        components: %{
          schemas: %{
            HealthResponse: %{
              type: "object",
              properties: %{
                status: %{type: "string", enum: ["ok", "degraded", "error"]},
                components: %{
                  type: "object",
                  properties: %{
                    app: %{type: "string", enum: ["ok", "degraded", "error"]},
                    database: %{type: "string", enum: ["ok", "degraded", "error"]},
                    log_stream: %{type: "string", enum: ["ok", "degraded", "error"]}
                  }
                }
              },
              example: %{
                status: "ok",
                components: %{
                  app: "ok",
                  database: "ok",
                  log_stream: "ok"
                }
              }
            },
            SlackResponse: %{
              type: "object",
              properties: %{
                response_type: %{type: "string", enum: ["ephemeral", "in_channel"]},
                text: %{type: "string"}
              },
              example: %{
                response_type: "ephemeral",
                text: "Processing your request..."
              }
            },
            ErrorResponse: %{
              type: "object",
              properties: %{
                error: %{type: "string"}
              },
              example: %{
                error: "Invalid payload"
              }
            }
          }
        }
      }

    json(conn, spec)
  end
end
