defmodule MyApp.Router do
  use Phoenix.Router
  use MyApp.Cldr.Routes

  localize do
    get "/pages/:page", PageController, :show
    resources "/users", UserController
  end
end