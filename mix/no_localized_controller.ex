defmodule NotLocalizedController do
  use MyAppWeb, :controller

  def show(conn, _params) do
    # %{"page" => "hello"} = params
    conn
  end
end