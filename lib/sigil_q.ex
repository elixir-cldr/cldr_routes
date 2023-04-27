defmodule SigilWrapper do
  use MyApp.Router.VerifiedRoutes, router: MyApp.Router, endpoint: MyAppWeb.Endpoint

  def x do
    import MyAppWeb.Gettext
    sigil_p("/#{dgettext("routes", "users")}", [])
  end

end