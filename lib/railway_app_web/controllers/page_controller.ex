defmodule RailwayAppWeb.PageController do
  use RailwayAppWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
