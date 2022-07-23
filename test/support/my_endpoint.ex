defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :ex_cldr_routes

  plug MyApp.Router
end