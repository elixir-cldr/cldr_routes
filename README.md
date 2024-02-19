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

Lastly, Localized Verified Routes, introduced in Phoenix 1.7, are supported and their use encouraged in preference to URL Helpers. Localized Verified Routes are specified with the `~q` sigil in the same manner as Phoenix Verified Routes `~p`.

## Setting up

### Installation

The first step is to configure and install by adding `ex_cldr_routes` to your list of dependencies in `mix.exs` then run `mix deps.get`.

```elixir
def deps do
  [
    {:ex_cldr_routes, "~> 1.0"}
  ]
end
```

The docs can be found at https://hexdocs.pm/ex_cldr_routes.

### Backend module configuration

A `Cldr` backend module that configures an associated `gettext` backend is required. In addition, a `Gettext` backend must be configured and added to the `Cldr` configuration.

Path parts (the parts between "/") are translated at compile time using `Gettext`. Therefore localization can only be applied to locales that are defined in a [gettext backend module](https://hexdocs.pm/gettext/Gettext.html#module-using-gettext) that is attached to a `Cldr` backend module.

The following steps should be followed to set up the configuration for localized routes and helpers:

### Configure Gettext

The first step is to ensure there is a configured `Gettext` backend module:

```elixir
defmodule MyAppWeb.Gettext do
  use Gettext, otp_app: :my_app
end
```

### Configure Cldr

The next step is to configure a `Cldr` backend module, including configuring it with the `Gettext` module defined in the first step. The `MyApp.Cldr` backend module is used to instrospect the configured locales that drive the route and helper localization.

```elixir
defmodule MyApp.Cldr do
  use Cldr,
    locales: ["en", "fr"],
    default_locale: "en",
    gettext: MyApp.Gettext,
    providers: [Cldr.Routes]

end
```

*Note* the addition of `Cldr.Routes` and `Cldr.Router` to the `:providers` configuration key is required.

## Define Localized Routes

Now we can configure the router module to use the `localize/1` macro by adding `use MyApp.Cldr.Routes` to the module and invoke the `localize/1` macro to wrap the required routes. `use MyApp.Cldr.Routes` must be added *after* `use Phoenix.Router`. For example:

```elixir
defmodule MyAppWeb.Router do
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
% mix phx.routes MyAppWeb.Router
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

> #### Warning {: .warning}
>
> Route helpers are deprecated as of Phoenix 1.7. Like Phoenix, localization route helpers are
> can still be generated. When using `mix phx.new my_app`, the `MyAppWeb` module will include
> `use Phoenix.Router, helpers: false`. This is also the recommendation when using
> `MyApp.Cldr.Router`.

Manually constructing the localized helper names shown in the example above would be tedious. Therefore a `LocalizedHelpers` module is generated at compile-time. Assuming the router module is called `MyAppWeb.Router` then the full name of the localized helper module is `MyAppWeb.Router.LocalizedHelpers`.

The functions on this module are the non-localized versions that should be used by applications (they delegate ultimately to the localized routes based upon the current locale).

The functions on the `LocalizedHelpers` module all respect the current locale, based upon `Cldr.get_locale/1`, and will delegate to the appropriate localized function in the `Helpers` function created automatically at compile time. For example:
```elixir
iex> MyApp.Cldr.put_locale("en")
iex> MyAppWeb.Router.LocalizedHelpers.page_path %Plug.Conn{}, :show, 1
"/pages/1"
iex> MyApp.Cldr.put_locale("fr")
iex> MyAppWeb.Router.LocalizedHelpers.page_path %Plug.Conn{}, :show, 1
"/pages_fr/1"
```

*Note* The localized helpers translate the path based upon the `:gettext_locale_name` for the currently set `Cldr` locale. It is the developers responsibility to ensure that the locale is set appropriately before calling any localized path helpers.

### Introspecting localized routes

For convenience in introspecting routes, a module called `MyApp.Router.LocalizedRoutes` is generated that can be used with the `mix phx.routes` mix task. For example:

```bash
% cldr_routes % mix phx.routes MyAppWeb.Router.LocalizedRoutes
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
* Propogate the locale from the session into a LiveView process during the `on_mount/3` callback with `Cldr.Plug.put_locale_from_session/2`

## Localized Verified Routes

`Sigil_q` implements localized verified routes for Phoenix 1.7 and later.

Adding
```elixir
use MyApp.Cldr.VerifiedRoutes,
  router: MyApp.Router,
  endpoint: MyApp.Endpoint
```
to a module gives access to `sigil_q` which is functionally equal to Phoenix Verified Routes `sigil_p`. In fact the result of using `sigil_q` is code that looks like this:

```elixir
# ~q"/users" generates the following code for a
# Cldr backend that has configured the locales
# :en, :fr and :de

case MyApp.Cldr.get_locale().cldr_locale_name do
  :de -> ~p"/users_de"
  :en -> ~p"/users"
  :fr -> ~p"/users_fr"
end
```

### Locale interpolation

Some use cases call for the locale, language or territory to be part of the URL. `Sigl_q` makes this easy by providing
the following interpolations into a `Sigil_q` path:

* `:locale` is replaced with Cldr locale name.
* `:language` is replaced with the Cldr language code.
* `:territory` is replaced with the Cldr territory code.

```elixir
# ~q"/users/:locale" generates the following code for a
# Cldr backend that has configured the locales
# :en, :fr and :de. Note the interpolation of the locale
# information which is performed at compile time.

case MyApp.Cldr.get_locale().cldr_locale_name do
  :de -> ~p"/users_de/de"
  :en -> ~p"/users/en"
  :fr -> ~p"/users_fr/fr"
end
```

## Phoenix MyWebApp configuration

Since localized routes, route helpers and verified routes have the same function and API as the standard Phoenix equivalent modules it is possible to update the generated Phoenix configuration. Assuming the presence of `myapp_web.ex` defining the module `MyAppWeb` then the following changes should be considered in the `my_web_app.ex` file:

### Router
```elixir
def router do
  quote do
    use Phoenix.Router, helpers: false

    # Add localized routes
    use MyApp.Cldr.Routes, helpers: false

    # Import common connection and controller functions to use in pipelines
    import Plug.Conn
    import Phoenix.Controller
    import Phoenix.LiveView.Router
  end
end
```

### Verified Routes
Change `Phoenix.VerifiedRoutes` to `MyApp.Cldr.VerifiedRoutes`:
```elixir
  def verified_routes do
    quote do
      use MyApp.Cldr.VerifiedRoutes,
        endpoint: PhxCldrWeb.Endpoint,
        router: PhxCldrWeb.Router,
        statics: PhxCldrWeb.static_paths()
    end
  end
```

## Generating link headers

When the same content is produced in multiple languages it is important to cross-link the different editions of the content to each other. This is good practise in general but strong advised by [goggle](https://developers.google.com/search/docs/advanced/crawling/localized-versions) to reduce SEO risks for your site.

This cross-linking can be done with the aid of HTTP headers or with `<link />` tags in the `<head>` section of an HTML document. Helpers are generated by `ex_cldr_routes` to facilitate the creating of these links. These functions are generated in the `MyAppWeb.Router.LocalizedHelpers` module (where `MyAppWeb.Router` is the name of your Phoenix router module).

* `MyAppWeb.Router.LocalizedHelpers.<helper>_links` generated a mapping of locales for a given route to the URLs for those locales.
* `MyAppWeb.Router.LocalizedHelpers.hreflang_links/1` take the generated map and produces link headers ready for insertion into an HTML document.

The functions can be used as follows:

1. Update the controller to generate the links and add them to `:assigns`

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  # This alias would normally be set in the
  # MyAppWeb.controller/0 and MyAppWeb.view_helpers/0
  # functions
  alias MyAppWeb.Router.LocalizedHelpers, as: Routes

  alias MyApp.Accounts
  alias MyApp.Accounts.User

  def show(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    hreflang_links = Routes.user_links(conn, :show, id)
    render(conn, "show.html", user: user, hreflang_links: hreflang_links)
  end
end
```

2. Update the root layout to add the hreflang links

```html
<html lang="en">
  <head>
    <meta charset="utf-8"/>
    <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <%= Routes.hreflang_links(assigns[:hreflang_links]) %>
    <%= csrf_meta_tag() %>
    <%= live_title_tag assigns[:page_title] || "Routing", suffix: " · Phoenix Framework" %>
    <link phx-track-static rel="stylesheet" href={Routes.static_path(@conn, "/assets/app.css")}/>
    <script defer phx-track-static type="text/javascript" src={Routes.static_path(@conn, "/assets/app.js")}></script>
  </head>
  <body>
    ...
    <%= @inner_content %>
  </body>
</html>
```

## Translations

In order for routes to be localized, translations must be provided for each path segment. This translation is performed by `dgettext/3` with the domain "routes". Therefore for each configured locale, a "routes.pot" file is required containing the path segment translations for that locale.

Using the example Cldr backend that has "en" and "fr" Gettext locales then the directory structure would look like the following (if the default Gettext configuration is used):

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

The `mix` tasks `gettext.extract` and `gettext.merge` can be used to support the extraction of routing segments and to create new translation locales.


