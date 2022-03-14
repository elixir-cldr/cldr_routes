defmodule Cldr.Routes do
  @moduledoc """
  Generate localized routes and route helper
  modules.

  This module when `use`d , generates a `localize/1`
  macro that is designed to wrap the standard Phoenix
  route macros such as `get/3`, `put/3` and `resources/3`
  and localises them for each locale defined in a Gettext
  backend module attached to a CLDR backend module.

  Translations for the parts of a given route path are
  translated at compile-time which are then combined into
  a localised route that is added to the standard
  Phoenix routing framework.

  As a result, users can enter URLs using localised
  terms which can enhance user engagement and content
  relevance.

  Similarly, a localised path and URL helpers are
  generated that wrap the standard Phoenix helpers to
  supporting generating localised path and URLs.

  ### Setting up

  A Cldr backend module that configures a `Gettext`
  asosciated backend is required.

  Path parts (the parts between "/") are translated
  at compile time using `Gettext`. Therefore localization
  can only be applied to locales that are defined in
  a [gettext backend module](https://hexdocs.pm/gettext/Gettext.html#module-using-gettext)
  that is configured in a `Cldr` backend module.

  For example:

  ```elixir
  defmodule MyApp.Cldr do
    use Cldr,
      locales: ["en", "fr"],
      default_locale: "en".
      gettext: MyApp.Gettext
      providers: [Cldr.Routes]

  end
  ```

  Here the `MyApp.Cldr` backend module
  is used to instrospect the configured
  locales in order to drive the localization
  generation.

  Next, configure the router module to
  use the `localize/1` macro by adding
  `use MyApp.Cldr.Routes` to the module and invoke
  the `localize/1` macro to wrap the required
  routes. For example:

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

  The following routes are generated (assuming that
  translations are updated in the `Gettext`
  configuration). For this example, the `:fr`
  translations are the same as the english
  text with `_fr` appended.
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

  """

  @domain "routes"
  @path_separator "/"
  @interpolate ":"

  @doc false
  def cldr_backend_provider(config) do
    backend = config.backend
    gettext = config.gettext

    quote location: :keep, bind_quoted: [backend: backend, gettext: gettext] do
      defmodule Routes do
        defmacro __using__(opts) do
          caller = __CALLER__.module

          locales =
            unquote(backend).known_gettext_locale_names()
            |> Enum.map(&Cldr.Config.locale_name_to_posix/1)

          Module.put_attribute(caller, :_gettext_locale_names, locales)
          Module.put_attribute(caller, :_gettext_module, unquote(gettext))

          quote do
            require Cldr.Routes
            import Cldr.Routes, only: :macros
            @before_compile Cldr.Routes
          end
        end
      end
    end
  end

  # Here we'll generate the help module that wraps the
  # standard Phoenix path and url helpers.  Things to
  # note:
  #
  # 1. We need to know if a route has been generated
  #    as a localised route otherwise we will generate
  #    suprious functions. Perhaps annotate the assigns
  #    "temporarily" in the module attribute?
  #
  # 2. For each localized route, break apart the path
  #    so we know which parts need translation and which don't.
  #
  # 3. Use the gettext macros to do the translation at
  #    compile time

  defmacro __before_compile__(_env) do
    # env.module |> Module.get_attribute(:phoenix_routes) |> Enum.reverse |> IO.inspect
    # Enum.map(routes, &{&1, Phoenix.Router.Route.exprs(&1)}) |> IO.inspect
    nil
  end

  @doc """
  Generates localised routes for each locale defined in a
  CLDR backend.

  This macro is intended to wrap a series of standard
  route definitiosn in a `do` block. For example:

  ```elixir
  localize do
    get "/pages/:page", PageController, :show
    resources "/users", UsersController
  end
  ```

  """
  defmacro localize([do: {:__block__, meta, routes}]) do
    translated_routes =
      for route <- routes do
        quote do
          localize(unquote(route))
        end
      end

    {:__block__, meta, translated_routes}
  end

  defmacro localize([do: route]) do
    quote do
      localize(unquote(route))
    end
  end

  # For nested resources
  defmacro localize({:resources, meta, [path, aliases, [do: nested_resource]]}) do
    quote do
      unquote({:resources, meta, [path, aliases, [do: {:localize, [], [nested_resource]}]]})
    end
  end

  defmacro localize({verb, meta, [path | args]}) do
    gettext_backend = Module.get_attribute(__CALLER__.module, :_gettext_module)
    locale_names =  Module.get_attribute(__CALLER__.module, :_gettext_locale_names)

    for locale_name <- locale_names do
      translated_path = Cldr.Routes.translated_path(path, gettext_backend, locale_name)
      {verb, meta, [translated_path | args]}
    end
    |> Enum.uniq()
  end

  def translated_path(path, gettext_backend, locale) do
    Gettext.put_locale(gettext_backend, locale)

    path
    |> String.split(@path_separator)
    |> Enum.map(&translate_part(gettext_backend, &1))
    |> Enum.join(@path_separator)
  end

  defp translate_part(_gettext_backend, "" = part), do: part
  defp translate_part(_gettext_backend, @interpolate <> _rest = part), do: part
  defp translate_part(gettext_backend, part), do: Gettext.dgettext(gettext_backend, @domain, part)
end


