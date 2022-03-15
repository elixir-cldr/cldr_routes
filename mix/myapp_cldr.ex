defmodule MyApp.Cldr do
  use Cldr,
    locales: ["en", "fr", "ja"],
    default_locale: "en",
    gettext: MyAppWeb.Gettext,
    providers: [Cldr.Routes]

end