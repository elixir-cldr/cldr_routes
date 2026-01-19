{:module, _} = Code.ensure_compiled(MyApp.Cldr)
require Cldr.Routes

defmodule MyApp.Test.Backend.Cldr do
  use Cldr,
    locales: ["es"],
    default_locale: "en",
    gettext: MyApp.Gettext,
    providers: [Cldr.Routes]

end
