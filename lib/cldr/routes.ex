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

  @localizable_verbs [:resources, :get, :put, :patch, :post, :delete, :options, :head, :connect]

  @doc false
  def cldr_backend_provider(config) do
    backend = config.backend
    gettext = config.gettext

    quote location: :keep, bind_quoted: [backend: backend, gettext: gettext] do
      defmodule Routes do
        @moduledoc false

        defmacro __using__(opts) do
          Cldr.Routes.confirm_backend_has_gettext!(unquote(backend))
          caller = __CALLER__.module

          Module.put_attribute(caller, :_cldr_backend, unquote(backend))

          quote do
            import Cldr.Routes, only: :macros
            @before_compile Cldr.Routes
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
    The Cldr backend #{inspect backend} does not have a Gettext
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

  defmacro __before_compile__(env) do
    routes = env.module |> Module.get_attribute(:phoenix_routes) |> Enum.reverse
    routes_with_exprs = Enum.map(routes, &{&1, Phoenix.Router.Route.exprs(&1)})
    helpers_moduledoc = Module.get_attribute(env.module, :helpers_moduledoc)

    Cldr.Routes.LocalizedHelpers.define(env, routes_with_exprs, docs: helpers_moduledoc)
    []
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
  defmacro localize([do: {:__block__, meta, routes}]) do
    translated_routes =
      for route <- routes do
        quote do
          localize([do: unquote(route)])
        end
      end

    {:__block__, meta, translated_routes}
  end

  defmacro localize([do: route]) do
    cldr_backend = Module.get_attribute(__CALLER__.module, :_cldr_backend)
    cldr_locale_names = cldr_backend.known_locale_names()

    quote do
      localize(unquote(cldr_locale_names), [do: unquote(route)])
    end
  end

  defmacro localize(cldr_locale_names, [do: {:__block__, meta, routes}]) when is_list(cldr_locale_names) do
    translated_routes =
      for route <- routes do
        quote do
          localize(unquote(cldr_locale_names), [do: unquote(route)])
        end
      end

    {:__block__, meta, translated_routes}
  end

  defmacro localize(cldr_locale_names, [do: route]) when is_list(cldr_locale_names) do
    cldr_backend = Module.get_attribute(__CALLER__.module, :_cldr_backend)

    for cldr_locale_name <- cldr_locale_names do
      with {:ok, cldr_locale} <- cldr_backend.validate_locale(cldr_locale_name) do
        if cldr_locale.gettext_locale_name do
          quote do
            localize(unquote(cldr_locale), unquote(route))
          end
        else
          {verb, _meta, [path, _controller, _args]} = route
          IO.warn "No known gettext locale for #{inspect cldr_locale_name}. " <>
            "No #{inspect cldr_locale_name} localized routes will be generated for #{inspect verb} #{inspect path}", []
          nil
        end
      else
        {:error, {exception, reason}} -> raise exception, reason
      end
    end
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(&canonical_route/1)
  end

  defmacro localize(locale, [do: {:__block__, meta, routes}]) do
    translated_routes =
      for route <- routes do
        quote do
          localize(unquote(locale), [do: unquote(route)])
        end
      end

    {:__block__, meta, translated_routes}
  end

  defmacro localize(locale, [do: route]) do
    quote do
      localize(unquote(locale), unquote(route))
    end
  end

  # Rewrite nested resources; guard against infinite recursion
  defmacro localize(locale, {:resources, _meta, [path, controller, [do: {fun, _, _args}] = nested_resource]})
      when fun != :localize do
    quote do
      localize unquote(locale) do
        resources unquote(path), unquote(controller) do
          localize unquote(locale) do
            unquote(nested_resource)
          end
        end
      end
    end
  end

  # Do the actual translations
  defmacro localize(cldr_locale_name, {verb, meta, [path | args]})
      when verb in @localizable_verbs do
    cldr_backend = Module.get_attribute(__CALLER__.module, :_cldr_backend)
    gettext_backend = cldr_backend.__cldr__(:config).gettext
    {:ok, cldr_locale} = cldr_backend.validate_locale(cldr_locale_name)

    if cldr_locale.gettext_locale_name do
      translated_path = Cldr.Routes.translated_path(path, gettext_backend, cldr_locale.gettext_locale_name)
      args = Cldr.Routes.add_route_locale_to_assigns(args, cldr_locale)
      {verb, meta, [translated_path | args]}
    else
      IO.warn "Cldr locale #{inspect cldr_locale_name} does not have a known gettext locale." <>
        " No #{inspect cldr_locale_name} localized routes will be generated for #{inspect verb} #{inspect path}", []
      {verb, meta, [path | args]}
    end
  end

  # If the verb is unsupported for localization
  defmacro localize(_cldr_locale_name, {verb, _meta, [path |args]}) do
    {args, []} = Code.eval_quoted(args)
    args = Enum.map_join(args, ", ", &inspect/1)

    raise ArgumentError,
      """
      Invalid route for localization: #{verb} #{inspect path}, #{inspect args}
      Allowed localizable routes are #{inspect @localizable_verbs}
      """
  end

  # Gettext requires we set the current process locale
  # in order to translate. This might ordinarily disrupt
  # any user set locale. However since this is only executed
  # at compile time it does not affect runtime behaviour.

  @doc false
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

  # Add an assign :cldr_locale that is the
  # gettext locale for which this route was recognised.
  # This can be used by application code to make localization
  # decisions. Its also used to mark localised routes
  # for path and url helper generation.

  # When inserting the assigns, make sure to keep any
  # do: block in the correct place

  @doc false
  def add_route_locale_to_assigns(args, locale) do
    case Enum.reverse(args) do
      [[do: block], last | rest] ->
        last
        |> put_route_locale(locale)
        |> combine(rest, [do: block])
        |> Enum.reverse()

      [last | rest] ->
        last
        |> put_route_locale(locale)
        |> combine(rest)
        |> Enum.reverse()
    end
  end

  defp combine(first, rest) when is_list(first), do: first ++ rest
  defp combine(first, rest), do: [first | rest]

  defp combine(first, rest, block) when is_list(first), do: [block | first ++ rest]
  defp combine(first, rest, block), do: [block, first | rest]

  # Keyword list of options - update or add :assigns
  defp put_route_locale([{key, _value} | _rest] = options, locale) when is_atom(key) do
    {assigns, options} = Keyword.pop(options, :assigns)
    options = [Keyword.put(options, :assigns, Cldr.Routes.put_locale(assigns, locale))]

    quote do
      unquote(options)
    end
  end

  # Not a keyword list - fabricate one
  defp put_route_locale(last, locale) do
    options =
      quote do
        [assigns: %{cldr_locale: unquote(Macro.escape(locale))}]
      end

    [options, last]
  end

  @doc false
  # No assigns, so fabricate one
  def put_locale(nil, locale) do
    quote do
      %{cldr_locale: unquote(Macro.escape(locale))}
    end
  end

  # Existing assigns, add to them
  def put_locale({:%{}, _meta, _key_values} = assigns, locale) do
    quote do
      Map.put(unquote(assigns), :cldr_locale, unquote(Macro.escape(locale)))
    end
  end

  # Testing uniqeiness of a routez excluding options
  # We use this to eliminate duplicate routes which can occur if
  # there is no translation for a term and therefore the original
  # term is returned.

  defp canonical_route({verb, meta, [path, controller, action | _args]}) when is_atom(action) do
    {verb, meta, [path, controller, action]}
  end

  defp canonical_route({verb, meta, [path, controller | _args]}) do
    {verb, meta, [path, controller]}
  end

  defp canonical_route({:localize, _, [[do: {verb, meta, [path, controller, action]}]]}) when is_atom(action) do
    {verb, meta, [path, controller, action]}
  end

end
