require Cldr.Route

defmodule Cldr.Route.Test.Backend.Cldr do
  use Cldr,
    locales: ["es"],
    default_locale: "en",
    gettext: MyAppWeb.Gettext,
    providers: [Cldr.Route]

end