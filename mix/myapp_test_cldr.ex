require Cldr.Route
require MyApp.Cldr

defmodule MyApp.Test.Backend.Cldr do
  use Cldr,
    locales: ["es"],
    default_locale: "en",
    gettext: MyAppWeb.Gettext,
    providers: [Cldr.Routes, Cldr.Router]

end