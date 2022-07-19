require Cldr.Route

defmodule Test.Backend.Cldr do
  use Cldr,
    locales: ["es"],
    default_locale: "en",
    gettext: MyAppWeb.Gettext,
    providers: [Cldr.Route]

end