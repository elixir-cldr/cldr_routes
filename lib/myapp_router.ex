defmodule MyApp.Router do
  use Phoenix.Router
  import Cldr.Routes

  localize do
    get "/pages/:page", PageController, :show
    get "/users/:user", PageController, :show
  end

end