require Cldr.Route

defmodule MyApp.Cldr do
  use Cldr,
    locales: ["en", "fr", "de", "en-GB", "de-CH", "fr-CH", "en-CH"],
    default_locale: "en",
    gettext: MyApp.Gettext,
    providers: [Cldr.Routes]

end
