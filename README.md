# Cldr Routes
![Build Status](http://sweatbox.noexpectations.com.au:8080/buildStatus/icon?job=cldr_routes)
[![Hex.pm](https://img.shields.io/hexpm/v/ex_cldr_routes.svg)](https://hex.pm/packages/ex_cldr_routes)
[![Hex.pm](https://img.shields.io/hexpm/dw/ex_cldr_routes.svg?)](https://hex.pm/packages/ex_cldr_routes)
[![Hex.pm](https://img.shields.io/hexpm/dt/ex_cldr_routes.svg?)](https://hex.pm/packages/ex_cldr_routes)
[![Hex.pm](https://img.shields.io/hexpm/l/ex_cldr_routes.svg)](https://hex.pm/packages/ex_cldr_routes)

Generate localized routes and route helper modules.

This module when `use`d , provides a `localize/1` macro that is designed to wrap the standard Phoenix route macros such as `get/3`, `put/3` and `resources/3`. The routes are localised for each locale configured in a `Gettext` backend module that is attached to a `Cldr` backend module.

Translations for the parts of a given route path are performed at compile-time and are then combined into a localised route that is added to the standard Phoenix routing framework.

As a result, users can enter URLs using localised terms which can enhance user engagement and content relevance.

Similarly, localised path and URL helpers are generated that wrap the standard Phoenix helpers to supporting generating localised paths and URLs.

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

### Define Localized Routes

Now we can configure the router module to use the `localize/1` macro by adding `use MyApp.Cldr.Route` to the module and invoke the `localize/1` macro to wrap the required routes. `use MyApp.Cldr.Router` must be added *after* `use Phoenix.Router`. For example:

```elixir
defmodule MyApp.Router do
  use Phoenix.Router
  use MyApp.Cldr.Route

  localize do
    get "/pages/:page", PageController, :show
    resources "/users", UsersController
  end
end
```

The following routes are generated (assuming that translations are updated in the `Gettext` configuration). For this example, the `:fr` translations are the same as the `:en` text with `_fr` appended. 

```bash 
% mix phx.routes MyApp.Router
 page_path  GET     /pages/:page        PageController :show
 page_path  GET     /pages_fr/:page     PageController :show
users_path  GET     /users              UsersController :index
users_path  GET     /users/:id/edit     UsersController :edit
users_path  GET     /users/new          UsersController :new
users_path  GET     /users/:id          UsersController :show
users_path  POST    /users              UsersController :create
users_path  PATCH   /users/:id          UsersController :update
            PUT     /users/:id          UsersController :update
users_path  DELETE  /users/:id          UsersController :delete
users_path  GET     /users_fr           UsersController :index
users_path  GET     /users_fr/:id/edit  UsersController :edit
users_path  GET     /users_fr/new       UsersController :new
users_path  GET     /users_fr/:id       UsersController :show
users_path  POST    /users_fr           UsersController :create
users_path  PATCH   /users_fr/:id       UsersController :update
            PUT     /users_fr/:id       UsersController :update
users_path  DELETE  /users_fr/:id       UsersController :delete
```

## Translations

In order for routes to be localized, translations must be provided for each path segment in each locale. This translation is performed by `Gettext.dgettext/3` with the domain "routes". Therefore for each configured locale, a "routes.pot" file is required containing the path segment translations for that locale.

Using the example `Cldr` backend that has "en" and "fr" `Gettext` locales, the directory structure will look like the following (if the default `Gettext` configuration is used):

    priv/gettext
    ├── default.pot
    ├── en
    │   └── LC_MESSAGES
    │       ├── default.po
    │       ├── errors.po
    │       └── routes.po
    ├── errors.pot
    └── fr
        └── LC_MESSAGES
            ├── default.po
            ├── errors.po
            └── routes.po

**Note** that since the translations are performed with `Gettext.dgettext/3` at compile time, the message ids are not autoamtically populated and must be manually added to the "routes.pot" file for each locale. That is, the mix tasks `mix gettext.extract` and `mix gettext.merge` will not detect or extract the route segments.

## Path Helpers

In the same way that Phoenix generates a `MyApp.Router.Helpers` module, `ex_cldr_routes` also generates a `MyApp.Router.LocalizedHelpers` module that translates localized paths. Since this module is generated alongside the standard `Helpers` module, an application can decide to generate either canonical paths or localized paths.  Here are some examples, assuming the same `Cldr` and `Gettext` configuration as the previous examples:

```elixir
iex> MyApp.Router.LocalizedHelpers.page_path %Plug.Conn{}, :show, 1
"/pages/1"
iex> Gettext.put_locale MyAppWeb.Gettext, "fr"         
nil
iex> MyApp.Router.LocalizedHelpers.page_path %Plug.Conn{}, :show, 1
"/pages_fr/1"

```

*Note* The localized helpers translate the path based upon the currently set `Gettext` locale. It is the developers responsibility to ensure that the locale is set appropriately before calling any localized path helpers.

## Assigns

For each localized path, the `Cldr` locale is added to the `:assigns` for the route under the `:cldr_locale` key. This allows the developer to recognise which locale was used to generate the localized route.

## Installation

The package can be installed by adding `ex_cldr_routes` to your list of dependencies in `mix.exs`. See also the section on [setting up](#setting-up) for configuring the `Cldr` backend module and the phoenix router.

```elixir
def deps do
  [
    {:ex_cldr_routes, "~> 0.2.0"}
  ]
end
```

The docs can be found at <https://hexdocs.pm/ex_cldr_routes>.

