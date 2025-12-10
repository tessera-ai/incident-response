defmodule RailwayAppWeb.PageControllerTest do
  use RailwayAppWeb.ConnCase

  test "GET / redirects to dashboard", %{conn: conn} do
    # The root route now points to DashboardLive
    # This test verifies the dashboard loads
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Dashboard"
  end
end
