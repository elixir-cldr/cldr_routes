defmodule Cldr.Route do
  @moduledoc """
  Generate localized routes and route helper
  modules.

  This module when `use`d , provides a `localize/1`
  macro that is designed to wrap the standard Phoenix
  route macros such as `get/3`, `put/3` and `resources/3`
  and localizes them for each locale defined in a Gettext
  backend module attached to a Cldr backend module.

  Translations for the parts of a given route path are
  translated at compile-time and are then combined into
  a localised route that is added to the standard
  Phoenix routing framework.

  As a result, users can enter URLs using localised
  terms which can enhance user engagement and content
  relevance.

  Similarly, localised path and URL helpers are
  generated that wrap the standard Phoenix helpers to
  supporting generating localised paths and URLs.

  ### Configuration

  A Cldr backend module that configures a `Gettext`
  asosciated backend is required.

  Path parts (the parts between "/") are translated
  at compile time using `Gettext`. Therefore localization
  can only be applied to locales that are defined in
  a [gettext backend module](https://hexdocs.pm/gettext/Gettext.html#module-using-gettext)
  that is configured in a `Cldr` backend module.

  For example:
  ```
  defmodule MyApp.Cldr do
    use Cldr,
      locales: ["en", "fr"],
      default_locale: "en".
      gettext: MyApp.Gettext
      providers: [Cldr.Route]

  end
  ```

  Here the `MyApp.Cldr` backend module
  is used to instrospect the configured
  locales in order to drive the localization
  generation.

  Next, configure the router module to
  use the `localize/1` macro by adding
  `use MyApp.Cldr.Route` to the module and invoke
  the `localize/1` macro to wrap the required
  routes. For example:

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

  The following routes are generated in the `MyApp.Router`
  modeul (assuming that translations are updated in the `Gettext`
  configuration).

  For this example, the `:fr` and `:de` translations are
  the same as the `:en` text with `_fr` or `_de` appended.
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

  It is also possible to emit the routes and route helpers before
  localization using the `mix phx.routes` task on an automatically
  generated mini-router. See `h MyApp.Router.LocalizedRoutes`.

  ### Interpolating Locale Data

  A route may be defined with elements of the locale
  interpolated into it. These interpolations are specified
  using the normal `\#{}` interpolation syntax. However
  since route translation occurs at compile time only
  the following interpolations are supported:

  * `locale` will interpolate the Cldr locale name
  * `language` will interpolate the Cldr language name
  * `territory` will interpolate the Cldr territory code

  Some examples are:
  ```elixir
  localize do
    get "/\#{locale}/locale/pages/:page", PageController, :show
    get "/\#{language}/language/pages/:page", PageController, :show
    get "/\#{territory}/territory/pages/:page", PageController, :show
  end
  ```

  ### Localized Helpers

  Manually constructing the localized helper names shown in
  the example above would be tedious. Therefore a `LocalizedHelpers`
  module is generated at compile-time. Assuming the router
  module is called `MyApp.Router` then the full name of the
  localized helper module is `MyApp.Router.LocalizedHelpers`.

  The functions on this module are the non-localized versions.
  Localised routes can be printed by leveraging the `phx.routes`
  mix task.  For example:
  ```elixir
  % mix phx.routes MyApp.Router
  page_de_path  GET      /pages_de/:page     PageController :show
  page_en_path  GET      /pages/:page        PageController :show
  page_fr_path  GET      /pages_fr/:page     PageController :show
  user_de_path  GET      /users_de           UserController :index
  user_de_path  GET      /users_de/:id/edit  UserController :edit
  user_de_path  GET      /users_de/new       UserController :new
  user_de_path  GET      /users_de/:id       UserController :show
  user_de_path  POST     /users_de           UserController :create
  user_de_path  PATCH    /users_de/:id       UserController :update
                PUT   /users_de/:id       UserController :update
  .....
  ```

  The functions on the `MyApp.Router.LocalizedHelpers` module all
  respect the current locale, based upon `Cldr.get_locale/1`, and will
  delegate to the appropriate localized function in the
  `MyApp.Router.Helpers` module created automatically by Phoenix
  at compile time.

  ### Configuring Localized Helpers as default

  Since `LocalizedHelpers` have the same semantics and
  API as the standard `Helpers` module it is possible to
  update the generated Phoenix configuration to use the
  `LocalizedHelpers` module by default.  Assuming the
  presence of `myapp_web.ex` defining the module `MyAppWeb`
  then changing the `view_helpers` function from
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
  will result in the automatic use of the localized
  helpers rather than the standard helpers.

  ### Translations

  In order for routes to be localized, translations must be
  provided for each path segment. This translation is performed
  by `Gettext.dgettext/3` with the domain "routes". Therefore for
  each configured locale, a "routes.pot" file is required containing
  the path segment translations for that locale.

  Using the example Cldr backend that has "en" and "fr" Gettext
  locales then the directory structure would look like the following
  (if the default Gettext configuration is used):

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

  """

  @domain "routes"
  @path_separator "/"
  @interpolate ":"

  @localizable_verbs [
    :resources,
    :get,
    :put,
    :patch,
    :post,
    :delete,
    :options,
    :head,
    :connect,
    :live
  ]

  @doc false
  def cldr_backend_provider(config) do
    backend = config.backend
    gettext = config.gettext

    quote location: :keep, bind_quoted: [backend: backend, gettext: gettext] do
      defmodule Routes do
        @moduledoc false

        defmacro __using__(opts) do
          Cldr.Route.confirm_backend_has_gettext!(unquote(backend))
          caller = __CALLER__.module

          Module.put_attribute(caller, :_cldr_backend, unquote(backend))

          quote do
            import Cldr.Route, only: :macros
            @before_compile Cldr.Route
          end
        end
      end
    end
  end

  @doc false
  def confirm_backend_has_gettext!(backend) do
    confirm_backend_has_gettext!(backend, backend.__cldr__(:config))
  end

  @doc false
  def confirm_backend_has_gettext!(backend, %Cldr.Config{gettext: nil}) do
    raise ArgumentError,
    """
    The Cldr backend #{inspect(backend)} does not have a Gettext
    module configured.

    A Gettext module must be configured in order to define localized
    routes. In addition, translations must be provided for the Gettext
    backend under the "routes" domain (ie in a file "routes.pot" for
    each configured Gettext locale).
    """
  end

  def confirm_backend_has_gettext!(_backend, %Cldr.Config{} = _config) do
    :ok
  end

  @doc false
  def localizable_verbs do
    @localizable_verbs
  end

  @doc false
  defmacro __before_compile__(env) do
    alias Cldr.Route.LocalizedHelpers
    routes = env.module |> Module.get_attribute(:phoenix_routes) |> Enum.reverse()
    localized_routes = Cldr.Route.routes(routes)

    # Remove bookkeeping data in :private
    Module.delete_attribute(env.module, :phoenix_routes)
    Module.register_attribute(env.module, :phoenix_routes, [])
    Module.put_attribute(env.module, :phoenix_routes, Cldr.Route.delete_original_path(routes))

    routes_with_exprs = Enum.map(routes, &{&1, Phoenix.Router.Route.exprs(&1)})
    helpers_moduledoc = Module.get_attribute(env.module, :helpers_moduledoc)
    LocalizedHelpers.define(env, routes_with_exprs, docs: helpers_moduledoc)

    quote do
      defmodule LocalizedRoutes do
        @moduledoc """
        This module exists only to host route definitions.

        Localised routes can be printed by leveraging
        the `phx.routes` mix task.  For example:

            % mix phx.routes #{inspect(__MODULE__)}
            page_path  GET  /pages/:page     PageController :show
            user_path  GET  /users           UserController :index
            user_path  GET  /users/:id/edit  UserController :edit
            user_path  GET  /users/new       UserController :new
            user_path  GET  /users/:id       UserController :show
            .....

        """

        def __routes__ do
          unquote(Macro.escape(localized_routes))
        end
      end
    end
  end

  @doc false
  def delete_original_path(routes) do
    Enum.map(routes, fn route ->
      private = Map.delete(route.private, :original_path)
      Map.put(route, :private, private)
    end)
  end

  @doc """
  Generates localised routes for each locale defined in a
  Cldr backend.

  This macro is intended to wrap a series of standard
  route definitiosn in a `do` block. For example:

  ```elixir
  localize do
    get "/pages/:page", PageController, :show
    resources "/users", UsersController
  end
  ```

  """
  defmacro localize(do: {:__block__, meta, routes}) do
    translated_routes =
      for route <- routes do
        quote do
          localize(do: unquote(route))
        end
      end

    {:__block__, meta, translated_routes}
  end

  defmacro localize(do: route) do
    cldr_backend = Module.get_attribute(__CALLER__.module, :_cldr_backend)
    gettext_backend = cldr_backend.__cldr__(:config).gettext
    cldr_locale_names = cldr_backend.known_locale_names()

    unless gettext_backend do
      raise "Cldr backend #{cldr_backend} does not have a configured Gettext backend."
    end

    quote do
      require unquote(gettext_backend)
      localize(unquote(cldr_locale_names), do: unquote(route))
    end
  end

  @doc """
  Generates localised routes for each locale provided.

  This macro is intended to wrap a series of standard
  route definitiosn in a `do` block. For example:

  ```elixir
  localize [:en, :fr] do
    get "/pages/:page", PageController, :show
    resources "/users", UsersController
  end
  ```

  """
  defmacro localize(cldr_locale_names, do: {:__block__, meta, routes})
           when is_list(cldr_locale_names) do
    translated_routes =
      for route <- routes do
        quote do
          localize(unquote(cldr_locale_names), do: unquote(route))
        end
      end

    {:__block__, meta, translated_routes}
  end

  defmacro localize(cldr_locale_names, do: route) when is_list(cldr_locale_names) do
    cldr_backend = Module.get_attribute(__CALLER__.module, :_cldr_backend)

    for cldr_locale_name <- cldr_locale_names do
      with {:ok, cldr_locale} <- cldr_backend.validate_locale(cldr_locale_name) do
        if cldr_locale.gettext_locale_name do
          quote do
            localize(unquote(cldr_locale), unquote(route))
          end
        else
          warn_no_gettext_locale(cldr_locale_name, route)
        end
      else
        {:error, {exception, reason}} -> raise exception, reason
      end
    end
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(&canonical_route/1)
  end

  defmacro localize(locale, do: {:__block__, meta, routes}) do
    translated_routes =
      for route <- routes do
        quote do
          localize(unquote(locale), do: unquote(route))
        end
      end

    {:__block__, meta, translated_routes}
  end

  defmacro localize(locale, do: route) do
    quote do
      localize(unquote(locale), unquote(route))
    end
  end

  # Rewrite nested resources; guard against infinite recursion
  defmacro localize(locale, {:resources, _, [path, controller, [do: {fun, _, _}] = nested]})
      when fun != :localize do
    nested = localize_nested_resources(locale, nested)

    quote do
      localize unquote(locale) do
        resources unquote(path), unquote(controller) do
          unquote(nested)
        end
      end
    end
  end

  # Do the actual translations
  @template_verbs @localizable_verbs -- [:live]

  defmacro localize(cldr_locale_name, {verb, meta, [path | args]}) when verb in @template_verbs do
    cldr_backend = Module.get_attribute(__CALLER__.module, :_cldr_backend)
    do_localize(:assigns, cldr_locale_name, cldr_backend, {verb, meta, [path | args]})
  end

  defmacro localize(cldr_locale_name, {:live = verb, meta, [path | args]}) do
    cldr_backend = Module.get_attribute(__CALLER__.module, :_cldr_backend)
    do_localize(:private, cldr_locale_name, cldr_backend, {verb, meta, [path | args]})
  end

  # If the verb is unsupported for localization
  defmacro localize(_cldr_locale_name, {verb, _meta, [path | args]}) do
    {args, []} = Code.eval_quoted(args)
    args = Enum.map_join(args, ", ", &inspect/1)

    raise ArgumentError,
    """
    Invalid route for localization: #{verb} #{inspect(path)}, #{inspect(args)}
    Allowed localizable routes are #{inspect(@localizable_verbs)}
    """
  end

  defp do_localize(field, cldr_locale_name, cldr_backend, {verb, meta, [path | args]} = route) do
    gettext_backend = cldr_backend.__cldr__(:config).gettext
    {:ok, cldr_locale} = cldr_backend.validate_locale(cldr_locale_name)
    {original_path, _} = escape_interpolation(path) |> Code.eval_quoted()

    if cldr_locale.gettext_locale_name do
      translated_path =
        path
        |> interpolate(cldr_locale)
        |> combine_string_segments()
        |> :erlang.iolist_to_binary()
        |> translate_path(gettext_backend, cldr_locale.gettext_locale_name)

      args =
        add_to_route(args, field, :cldr_locale, cldr_locale)
        |> add_to_route(:private, :original_path, original_path)
        |> localise_helper(verb, cldr_locale.gettext_locale_name)

      quote do
        unquote({verb, meta, [translated_path | args]})
      end
    else
      warn_no_gettext_locale(cldr_locale_name, route)

      quote do
        unquote({verb, meta, [path | args]})
      end
    end
  end

  defp localize_nested_resources(locale, nested) do
    Macro.postwalk nested, fn
      {:resources, _, [_path, _meta, _args, [do: {:resources, _, _}]]} = resources ->
        quote do
          localize unquote(locale) do
            unquote(resources)
          end
        end

      {:resources, _, [_path, _meta, [do: {:resources, _, _}]]} = resources ->
        quote do
          localize unquote(locale) do
            unquote(resources)
          end
        end

      {:resources, _, _} = route ->
        quote do
          localize unquote(locale), unquote(route)
        end

      other ->
        other
    end
  end

  # Interpolates the locale, language and territory
  # into he path by splicing the AST
  defp interpolate(path, locale) do
    Macro.prewalk path, fn
      {{:., _, [Kernel, :to_string]}, _, [{:locale, _, _}]} ->
        to_string(locale.cldr_locale_name) |> String.downcase()

      {{:., _, [Kernel, :to_string]}, _, [{:language, _, _}]} ->
        to_string(locale.language) |> String.downcase()

      {{:., _, [Kernel, :to_string]}, _, [{:territory, _, _}]} ->
        to_string(locale.territory) |> String.downcase()

      other ->
        other
    end
  end

  # Since we are doing com[ile-time translation of the
  # path, the path needs to be a string (not an expression).
  # This function attempts to combine the segments and
  # raises an exception if a string cannot be created.

  defp combine_string_segments([]) do
    []
  end

  defp combine_string_segments(a) when is_binary(a) do
    [a]
  end

  defp combine_string_segments({:"::", _, [a, {:binary, _, _}]}) do
    [a]
  end

  defp combine_string_segments({:<<>>, _, [a | b]}) do
    [combine_string_segments(a) | combine_string_segments(b)]
  end

  defp combine_string_segments({:<>, _, [a, b]}) do
   [combine_string_segments(a), combine_string_segments(b)]
  end

  defp combine_string_segments([a | rest]) do
    [combine_string_segments(a) | combine_string_segments(rest)]
  end

  defp combine_string_segments(ast) do
    raise ArgumentError,
    """
    The path arugment to a localized route must be a binary that
    can be resolved at compile time. Found:

    #{Macro.to_string(ast)}
    """
  end

  # Localise the helper name for the a verb (except resources)
  defp localise_helper(args, verb, locale) when verb not in [:resources] do
    [{_aliases, _meta, controller} | _rest] = args
    configured_helper = get_option(args, :as)
    helper = helper_name(controller, locale, configured_helper)
    put_option(args, :as, String.to_atom(helper))
  end

  # It appears that `:name` is overridden by `:as` :-(
  defp localise_helper(args, :resources, locale) do
    case args do
      [controller, options, do_block] ->
        {_aliases, _meta, controller_name} = controller
        configured_helper = get_option(args, :as)

        options =
          options
          |> Keyword.put(:name, name(controller_name))
          |> Keyword.put(:as, helper_name(controller_name, locale, configured_helper))

        [controller, options, do_block]

      [controller, _options] ->
        {_aliases, _meta, controller} = controller
        configured_helper = get_option(args, :as)
        helper = helper_name(controller, locale, configured_helper)
        put_option(args, :as, helper)
    end
  end

  defp name(controller) do
    Phoenix.Naming.resource_name(Module.concat(controller), "Controller")
  end

  defp helper_name(controller, locale, nil) do
    Phoenix.Naming.resource_name(Module.concat(controller), "Controller") <> "_" <> locale
  end

  defp helper_name(_controller, locale, configured_helper) do
    configured_helper <> "_" <> locale
  end

  defp get_option([_controller, _action, options], field) do
    Keyword.get(options, field)
  end

  defp get_option([_controller, options], field) do
    Keyword.get(options, field)
  end

  # For non-live routes
  defp put_option([controller, action, options], field, value) do
    [controller, action, [{field, value} | options]]
  end

  # For live routes
  defp put_option([controller, options], field, value) do
    [controller, [{field, value} | options]]
  end

  defp warn_no_gettext_locale(cldr_locale_name, route) do
    {verb, _meta, [path, _controller | _args]} = route

    IO.warn(
      "No known gettext locale for #{inspect(cldr_locale_name)}. " <>
        "No #{inspect(cldr_locale_name)} localized routes will be generated for #{inspect(verb)} #{inspect(path)}",
      []
    )

    nil
  end

  # Gettext requires we set the current process locale
  # in order to translate. This might ordinarily disrupt
  # any user set locale. However since this is only executed
  # at compile time it does not affect runtime behaviour.

  @doc false
  def translate_path(path, gettext_backend, locale) do
    path
    |> String.split(@path_separator)
    |> Enum.map(&translate_part(gettext_backend, locale, &1))
    |> reduce_parts()
  end

  defp translate_part(_gettext_backend, _locale, "" = part), do: part
  defp translate_part(_gettext_backend, _locale, @interpolate <> _rest = part), do: part

  defp translate_part(gettext_backend, locale, part) do
    domain = @domain

    quote do
      Gettext.put_locale(unquote(gettext_backend), unquote(locale))
      unquote(gettext_backend).dgettext(unquote(domain), unquote(part))
    end
  end

  defp reduce_parts([]), do: []
  defp reduce_parts([a, b]), do: {:<>, [], [a, {:<>, [], ["/", b]}]}
  defp reduce_parts([a | b]), do: {:<>, [], [a, {:<>, [], ["/", reduce_parts(b)]}]}

  # Add an assign :cldr_locale that is the
  # gettext locale for which this route was recognised.
  # This can be used by application code to make localization
  # decisions. Its also used to mark localised routes
  # for path and url helper generation.

  # When inserting the assigns, make sure to keep any
  # do: block in the correct place

  @doc false
  def add_to_route(args, field, key, value) do
    case Enum.reverse(args) do
      [[do: block], last | rest] ->
        last
        |> put_route(field, key, value)
        |> combine(rest, do: block)
        |> Enum.reverse()

      [last | rest] ->
        last
        |> put_route(field, key, value)
        |> combine(rest)
        |> Enum.reverse()

      [] = last ->
        put_route(last, field, key, value)
    end
  end

  defp combine(first, rest) when is_list(first) and is_list(rest), do: first ++ rest
  defp combine(first, rest), do: [first | rest]

  defp combine(first, rest, block) when is_list(first) and is_list(rest),
    do: [block | first ++ rest]

  defp combine(first, rest, block), do: [block, first | rest]

  # Keyword list of options - update or add :assigns
  defp put_route([{first, _value} | _rest] = options, field, key, value) when is_atom(first) do
    {field_content, options} = Keyword.pop(options, field)
    options = [Keyword.put(options, field, put_value(field_content, key, value))]

    quote do
      unquote(options)
    end
  end

  # Not a keyword list - fabricate one
  defp put_route(last, field, key, value) do
    options =
      quote do
        [{unquote(field), %{unquote(key) => unquote(Macro.escape(value))}}]
      end

    [options, last]
  end

  @doc false
  # No assigns, so fabricate one
  def put_value(nil, key, value) do
    quote do
      %{unquote(key) => unquote(Macro.escape(value))}
    end
  end

  # Existing assigns, add to them
  def put_value({:%{}, meta, key_values}, key, value) do
    {:%{}, meta, [{key, Macro.escape(value)} | key_values]}
  end

  # Testing uniqeiness of a routes excluding options
  # We use this to eliminate duplicate routes which can occur if
  # there is no translation for a term and therefore the original
  # term is returned.

  defp canonical_route({verb, meta, [path, controller, action | _args]}) when is_atom(action) do
    {verb, meta, [path, controller, action]}
  end

  defp canonical_route({verb, meta, [path, controller | _args]}) do
    {verb, meta, [path, controller]}
  end

  defp canonical_route({:localize, _, [[do: {verb, meta, [path, controller, action]}]]})
       when is_atom(action) do
    {verb, meta, [path, controller, action]}
  end

  @route_keys [:verb, :path, :plug, :plug_opts, :helper, :metadata]

  @doc false
  def routes(routes) do
    routes
    |> Enum.map(&strip_locale_from_path/1)
    |> Enum.map(&strip_locale_from_helper/1)
    |> Enum.map(&reconstruct_original_path/1)
    |> Enum.map(&add_locales_to_metadata/1)
    |> reduce_routes()
    |> Enum.map(&Map.take(&1, @route_keys))
  end

  defp reduce_routes([]) do
    []
  end

  # When the routes match except for locale
  defp reduce_routes([
      %{path: path, helper: helper, verb: verb} = first,
      %{path: path, helper: helper, verb: verb} = second | rest]) do
    locales = Enum.uniq([locale_from_args(second) | first.metadata.locales])
    metadata = Map.put(first.metadata, :locales, locales)
    reduce_routes([%{first | metadata: metadata} | rest])
  end

  defp reduce_routes([first | rest]) do
    [first | reduce_routes(rest)]
  end

  defp add_locales_to_metadata(%{assigns: %{cldr_locale: locale}} = route) do
    metadata = Map.put(route.metadata, :locales, [locale])
    %{route | metadata: metadata}
  end

  defp add_locales_to_metadata(%{private: %{cldr_locale: locale}} = route) do
    metadata = Map.put(route.metadata, :locales, [locale])
    %{route | metadata: metadata}
  end

  defp add_locales_to_metadata(other) do
    other
  end

  defp strip_locale_from_helper(%{assigns: %{cldr_locale: locale}} = route) do
    do_strip_locale_from_helper(route, locale)
  end

  defp strip_locale_from_helper(%{private: %{cldr_locale: locale}} = route) do
    do_strip_locale_from_helper(route, locale)
  end

  defp strip_locale_from_helper(%{private: %{}} = other) do
    other
  end

  defp do_strip_locale_from_helper(%{helper: nil} = route, _locale) do
    route
  end

  defp do_strip_locale_from_helper(%{helper: helper} = route, locale) do
    helper = Cldr.Route.LocalizedHelpers.strip_locale(helper, locale)
    %{route | helper: helper}
  end

  defp strip_locale_from_path(%{assigns: %{cldr_locale: locale}} = route) do
    do_strip_locale_from_path(route, locale)
  end

  defp strip_locale_from_path(%{private: %{cldr_locale: locale}} = route) do
    do_strip_locale_from_path(route, locale)
  end

  defp strip_locale_from_path(%{private: %{}} = other) do
    other
  end

  defp do_strip_locale_from_path(%{path: path} = route, locale) do
    path = Cldr.Route.LocalizedHelpers.strip_locale(path, locale, "/")
    %{route | path: path}
  end

  defp reconstruct_original_path(%{assigns: %{cldr_locale: _locale}} = route) do
    do_reconstruct_original_path(route)
  end

  defp reconstruct_original_path(%{private: %{cldr_locale: _locale}} = route) do
    do_reconstruct_original_path(route)
  end

  defp reconstruct_original_path(%{private: %{}} = other) do
    other
  end

  defp do_reconstruct_original_path(%{path: path, private: %{original_path: original}} = route) do
    if same_segment_length(path, original) do
      private = Map.delete(route.private, :original_path)
      %{route | private: private, path: original}
    else
      path = blend_paths(path, original)
      private = Map.delete(route.private, :original_path)
      %{route | private: private, path: path}
    end
  end

  defp same_segment_length(a, b) do
    length(String.split(a, @path_separator)) == length(String.split(b, @path_separator))
  end

  # Need to take care of routes which have /new, /edit
  # When it ends in /new then we patch before the new
  # When it ends in /edit then we pathc before the [:id, edit]
  # If the segments of the original match the leading segments of
  # the path then we do nothing.

  # TODO Clean this up

  defp blend_paths(path, original) do
    path_segs = String.split(path, @path_separator)
    orig_segs = String.split(original, @path_separator)

    cond do
      Enum.take(path_segs, length(orig_segs)) == orig_segs ->
        path

      Enum.take(path_segs, -1) == ["new"] ->
        new_segs = Enum.take(path_segs, -1)
        start_segs = Enum.take(path_segs, length(path_segs) - length(orig_segs) - 1)

        start_segs ++ tl(orig_segs) ++ new_segs
        |> Enum.join(@path_separator)

      String.starts_with?(hd(Enum.take(path_segs, -1)), @interpolate) ->
        new_segs = Enum.take(path_segs, -1)
        start_segs = Enum.take(path_segs, length(path_segs) - length(orig_segs) - 1)

        start_segs ++ tl(orig_segs) ++ new_segs
        |> Enum.join(@path_separator)

      Enum.take(path_segs, -1) == ["edit"] ->
        edit_segs = Enum.take(path_segs, -2)
        start_segs = Enum.take(path_segs, length(path_segs) - length(orig_segs) - 2)

        start_segs ++ tl(orig_segs) ++ edit_segs
        |> Enum.join(@path_separator)

      true ->
        start_segs = Enum.take(path_segs, length(path_segs) - length(orig_segs))
        start_segs ++ tl(orig_segs)
        |> Enum.join(@path_separator)
    end
  end

  defp locale_from_args(%{assigns: %{cldr_locale: locale}}) do
    locale
  end

  defp locale_from_args(%{private: %{cldr_locale: locale}}) do
    locale
  end

  defp locale_from_args(_other) do
    nil
  end

  defp escape_interpolation(path) do
    Macro.prewalk path, fn
      {{:., _, [Kernel, :to_string]}, _, [{:locale, _, _}]} ->
        ~S"#{locale}"

      {{:., _, [Kernel, :to_string]}, _, [{:language, _, _}]} ->
        ~S"#{language}"

      {{:., _, [Kernel, :to_string]}, _, [{:territory, _, _}]} ->
        ~S"#{territory}"

      other ->
        other
    end
  end
end
