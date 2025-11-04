defmodule MyAppWeb.HomeLiveController do
  use MyAppWeb, :live_component

  def show(conn, _params) do
    # %{"page" => "hello"} = params
    conn
  end
end