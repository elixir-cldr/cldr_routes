# Cldr Routes
![Build Status](http://sweatbox.noexpectations.com.au:8080/buildStatus/icon?job=cldr_routes)
[![Hex.pm](https://img.shields.io/hexpm/v/ex_cldr_routes.svg)](https://hex.pm/packages/ex_cldr_routes)
[![Hex.pm](https://img.shields.io/hexpm/dw/ex_cldr_routes.svg?)](https://hex.pm/packages/ex_cldr_routes)
[![Hex.pm](https://img.shields.io/hexpm/dt/ex_cldr_routes.svg?)](https://hex.pm/packages/ex_cldr_routes)
[![Hex.pm](https://img.shields.io/hexpm/l/ex_cldr_routes.svg)](https://hex.pm/packages/ex_cldr_routes)

Generate localized routes and a localized path helper module.

This module when `use`d , provides a `localize/1` macro that is designed to wrap the standard [Phoenix route](https://hexdocs.pm/phoenix/routing.html) macros such as `get/3`, `put/3` and `resources/3`. The routes are localised for each locale configured in a `Gettext` backend module that is attached to a `Cldr` backend module.

Translations for the parts of a given route path are performed at compile-time and are then combined into a localised route that is added to the standard Phoenix routing framework.

As a result, users can enter URLs using localised terms which can enhance user engagement and content relevance.

Similarly, localised path and URL helpers are generated that wrap the standard [Phoenix helpers](https://hexdocs.pm/phoenix/routing.html#path-helpers) to support generating localised paths and URLs.

## Setting up

A `Cldr` backend module that configures an associated `gettext` backend is required. In addition, a `Gettext` backend must be configured and added to the `Cldr` configuration.

Path parts (the parts between "/") are translated at compile time using `Gettext`. Therefore localization can only be applied to locales that are defined in a [gettext backend module](https://hexdocs.pm/gettext/Gettext.html#module-using-gettext) that is attached to a `Cldr` backend module.

The following steps should be followed to set up the configuration for localized routes and helpers:

### Configure Gettext

The first step is to ensure there is a configured `Gettext` backend module:

```elixir
defmodule MyApp.Gettext do
  use Gettext, otp_app: :my_app
end
```

### Configure Cldr

The next step is to configure a `Cldr` backend module, including configuring it with the `Gettext` module defined in the first step. The `MyApp.Cldr` backend module is used to instrospect the configured locales that drive the route and helper localization.

```elixir
defmodule MyApp.Cldr do
  use Cldr,
    locales: ["en", "fr"],
    default_locale: "en".
    gettext: MyApp.Gettext
    providers: [Cldr.Route]

end
```

*Note* the addition of `Cldr.Route` to the `:providers` configuration key is required.

## Define Localized Routes

Now we can configure the router module to use the `localize/1` macro by adding `use MyApp.Cldr.Routes` to the module and invoke the `localize/1` macro to wrap the required routes. `use MyApp.Cldr.Routes` must be added *after* `use Phoenix.Router`. For example:

```elixir
defmodule MyApp.Router do
  use Phoenix.Router
  use MyApp.Cldr.Routes

  localize do
    get "/pages/:page", PageController, :show
    resources "/users", UserController
  end
end
```

The following routes are generated (assuming that translations are updated in the `Gettext` configuration). For this example, the `:fr` translations are the same as the `:en` text with `_fr` appended.
```bash
% mix phx.routes MyApp.Router
page_de_path  GET     /pages_de/:page     PageController :show
page_en_path  GET     /pages/:page        PageController :show
page_fr_path  GET     /pages_fr/:page     PageController :show
user_de_path  GET     /users_de           UserController :index
user_de_path  GET     /users_de/:id/edit  UserController :edit
user_de_path  GET     /users_de/new       UserController :new
user_de_path  GET     /users_de/:id       UserController :show
...
```

## Interpolating Locale Data

A route may be defined with elements of the locale interpolated into it. These interpolatins are specified using the normal `#{}` interpolation syntax. However since route translation occurs at compile time only the following interpolations are supported:

* `locale` will interpolate the Cldr locale name
* `language` will interpolate the Cldr language name
* `territory` will interpolate the Cldr territory code

Some examples are:
```elixir
localize do
  get "/#{locale}/locale/pages/:page", PageController, :show
  get "/#{language}/language/pages/:page", PageController, :show
  get "/#{territory}/territory/pages/:page", PageController, :show
end
```

## Localized Helpers

Manually constructing the localized helper names shown in the example above would be tedious. Therefore a `LocalizedHelpers` module is geenrated at compile-time. Assuming the router module is called `MyApp.Router` then the full name of the localized helper module is `MyApp.Router.LocalizedHelpers`.

The functions on this module are the non-localized versions that should be used by applications (they delegate ultimately to the localized routes based upon the current locale).

The functions on the `LocalizedHelpers` module all respect the current locale, based upon `Cldr.get_locale/1`, and will delegate to the appropriate localized function in the `Helpers` function created automatically at compile time. For example:
```elixir
iex> MyApp.Cldr.put_locale("en")
iex> MyApp.Router.LocalizedHelpers.page_path %Plug.Conn{}, :show, 1
"/pages/1"
iex> MyApp.Cldr.put_locale("fr")
iex> MyApp.Router.LocalizedHelpers.page_path %Plug.Conn{}, :show, 1
"/pages_fr/1
```

*Note* The localized helpers translate the path based upon the `:gettext_locale_name` for the currently set `Cldr` locale. It is the developers responsibility to ensure that the locale is set appropriately before calling any localized path helpers.

### Introspecting localized routes

For convenience in introspecting routes, a module called `MyApp.Router.LocalizedRoutes` is generated that can be used with the `mix phx.routes` mix task. For example:

```bash
% cldr_routes % mix phx.routes MyApp.Router.LocalizedRoutes
page_path  GET     /pages_de/:page     PageController :show
page_path  GET     /pages/:page        PageController :show
page_path  GET     /pages_fr/:page     PageController :show
user_path  GET     /users_de           UserController :index
user_path  GET     /users_de/:id/edit  UserController :edit
user_path  GET     /users_de/new       UserController :new
...
```

In addition, each localized path stores the `Cldr` locale in the `:private` field for the route under the `:cldr_locale` key. This allows the developer to recognise which locale was used to generate the localized route.

This information is also used by functions in the [ex_cldr_plugs](https://hex.pm/packages/ex_cldr_plugs) library to:

* Identify the users locale from the route in `Cldr.Plug.PutLocale`
* Store the identified locale in the session in `Cldr.Plug.PutSession`
* Propogate the locale from the session into a LiveView process during the `on_mount/3` callback with `Cldr.Session.put_locale/2`

### Configuring Localized Helpers as default

Since `LocalizedHelpers` have the same semantics and API as the standard `Helpers` module it is possible to update the generated Phoenix configuration to use the `LocalizedHelpers` module by default.  Assuming the presence of `myapp_web.ex` defining the module `MyAppWeb` then changing the `view_helpers` function from:
```elixir
defp view_helpers do
  quote do
    ...

    import MyAppWeb.ErrorHelpers
    import MyAppWeb.Gettext
    alias MyAppWeb.Router.Helpers, as: Routes
  end
end
```
to
```elixir
defp view_helpers do
  quote do
    ...

    import MyAppWeb.ErrorHelpers
    import MyAppWeb.Gettext
    alias MyAppWeb.Router.LocalizedHelpers, as: Routes
  end
end
```
will result in the automatic use of the localized helpers rather than the standard helpers.

## Translations

In order for routes to be localized, translations must be provided for each path segment. This translation is performed by `dgettext/3` with the domain "routes". Therefore for each configured locale, a "routes.pot" file is required containing the path segment translations for that locale.

Using the example Cldr backend that has "en" and "fr" Gettext locales then the directory structure would look like the following (if the default Gettext configuration is used):

    priv/gettext
    ????????? default.pot
    ????????? en
    ???   ????????? LC_MESSAGES
    ???       ????????? default.po
    ???       ????????? errors.po
    ???       ????????? routes.po
    ????????? errors.pot
    ????????? fr
        ????????? LC_MESSAGES
            ????????? default.po
            ????????? errors.po
            ????????? routes.po

The `mix` tasks `gettext.extract` and `gettext.merge` can be used to support the extraction of routing segments and to create new translation locales.


## Installation

The package can be installed by adding `ex_cldr_routes` to your list of dependencies in `mix.exs`. See also the section on [setting up](#setting-up) for configuring the `Cldr` backend module and the phoenix router.

```elixir
def deps do
  [
    {:ex_cldr_routes, "~> 0.5.0"}
  ]
end
```

The docs can be found at https://hexdocs.pm/ex_cldr_routes.

