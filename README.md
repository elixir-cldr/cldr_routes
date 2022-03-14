# Cldr Routes

Generate localized routes and route helper
modules.

This module when `use`d , generates a `localize/1` macro that is designed to wrap the standard Phoenix route macros such as `get/3`, `put/3` and
`resources/3` and localises them for each locale defined in a Gettext backend module attached to a CLDR backend module.

Translations for the parts of a given route path are translated at compile-time which are then combined into a localised route that is added to the standard Phoenix routing framework.

As a result, users can enter URLs using localised terms which can enhance user engagement and content relevance.

Similarly, a localised path and URL helpers are generated that wrap the standard Phoenix helpers to supporting generating localised pat
h and URLs.

### Setting up

A `Cldr` backend module that configures a `gettext` asosciated backend is required.

Path parts (the parts between "/") are translated at compile time using `Gettext`. Therefore localization can only be applied to locales that are defined in
a [gettext backend module](https://hexdocs.pm/gettext/Gettext.html#module-using-gettext) that is configured in a `Cldr` backend module. For example:

```elixir
defmodule MyApp.Cldr do
  use Cldr,
    locales: ["en", "fr"],
    default_locale: "en".
    gettext: MyApp.Gettext
    providers: [Cldr.Routes]

end
```

Here the `MyApp.Cldr` backend module is used to instrospect the configured locales in order to drive the localization generation.

Next, configure the router module to use the `localize/1` macro by adding `use MyApp.Cldr.Routes` to the module and invoke the `localize/1` macro to wrap the
required routes. For example:

```elixir
defmodule MyApp.Router do
  use Phoenix.Router
  use MyApp.Cldr.Routes

  localize do
    get "/pages/:page", PageController, :show
    resources "/users", PageController
  end
end
```

The following routes are generated (assuming that translations are updated in the `Gettext` configuration). For this example, the `:fr` translations are the
same as the english text with `_fr` appended. 

```bash % mix phx.routes MyApp.Router
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

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `cldr_routes` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cldr_routes, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/cldr_routes>.

