defmodule MyApp.Router do
  use Phoenix.Router
  use MyApp.Cldr.Routes

  localize do
    get "/pages/:page", PageController, :show
    get "/users/:user", PageController, :show
    resources "/users", PageController do
      resources "/objects", PageController
    end
  end

end