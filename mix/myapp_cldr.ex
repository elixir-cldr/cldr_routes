require Cldr.Route

defmodule MyApp.Cldr do
  use Cldr,
    locales: ["en", "fr", "de", "en-GB"],
    default_locale: "en",
    gettext: MyAppWeb.Gettext,
    providers: [Cldr.Routes]

end