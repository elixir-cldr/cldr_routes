defmodule MyApp.Cldr do
  use Cldr,
    locales: ["en", "fr"],
    default_locale: "en",
    gettext: MyAppWeb.Gettext,
    providers: []

end