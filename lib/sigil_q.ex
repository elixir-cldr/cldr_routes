defmodule SigilWrapper do
  use MyApp.Router.VerifiedRoutes, router: MyApp.Router, endpoint: MyAppWeb.Endpoint

  def x do
    ~q"/path"
  end
end