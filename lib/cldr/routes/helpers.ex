defmodule Cldr.Routes.LocalizedHelpers do
  @moduledoc """
  Generates a module that implements localised helpers.

  It introspects the generated helpers module and creates
  a wrapper function that translates (at compile time) the
  path segments.

  """

  @type locale_name :: String.t()
  @type url :: String.t()

  @known_suffixes ["path", "url"]

  @doc """
  For a given set of routes, define a LocalizedHelpers
  module that implements localized helpers.

  """
  def define(env, routes, opts \\ []) do
    localized_helper_module = Module.concat([env.module, LocalizedHelpers])
    helper_module = Module.concat([env.module, Helpers])
    cldr_backend = Module.get_attribute(env.module, :_cldr_backend)

    routes =
      Enum.reject(routes, fn {route, _exprs} ->
        is_nil(route.helper) or route.kind == :forward
      end)

    groups = Enum.group_by(routes, fn {route, _exprs} -> route.helper end)

    docs = Keyword.get(opts, :docs, true)
    localized_helpers = localized_helpers(groups, cldr_backend)
    non_localized_helpers = non_localized_helpers(groups, helper_module)
    delegate_helpers = delegate_helpers(groups, helper_module, cldr_backend)
    other_delegates = other_delegates(helper_module)
    catch_all = catch_all(groups, helper_module)

    code =
      quote do
        @moduledoc unquote(docs) &&
                     """
                     Module with localized helpers generated from #{inspect(unquote(env.module))}.
                     """

        alias Cldr.Routes.LocalizedHelpers

        unquote_splicing(localized_helpers)
        unquote_splicing(non_localized_helpers)
        unquote_splicing(delegate_helpers)
        unquote(other_delegates)
        unquote_splicing(catch_all)
        unquote_splicing(href_link_helpers(routes))
      end

    Module.create(localized_helper_module, code, line: env.line, file: env.file)
  end

  defp localized_helpers(groups, cldr_backend) do
    for {_helper, helper_routes} <- groups,
        {_, [{route, exprs} | _]} <- routes_in_order(helper_routes),
        suffix <- @known_suffixes,
        localized_route?(route) do
      helper_fun_name = strip_locale(route.helper)
      {_bins, vars} = :lists.unzip(exprs.binding)

      quote do
        def unquote(:"#{helper_fun_name}_#{suffix}")(
              conn_or_endpoint,
              plug_opts,
              unquote_splicing(vars)
            ) do
          locale = unquote(cldr_backend).get_locale()

          helper(
            unquote(helper_fun_name),
            unquote(suffix),
            locale,
            conn_or_endpoint,
            plug_opts,
            unquote_splicing(vars),
            %{}
          )
        end

        def unquote(:"#{helper_fun_name}_#{suffix}")(
              conn_or_endpoint,
              plug_opts,
              unquote_splicing(vars),
              params
            ) do
          locale = unquote(cldr_backend).get_locale()

          helper(
            unquote(helper_fun_name),
            unquote(suffix),
            locale,
            conn_or_endpoint,
            plug_opts,
            unquote_splicing(vars),
            params
          )
        end
      end
    end
  end

  defp non_localized_helpers(groups, helper_module) do
    for {_helper, helper_routes} <- groups,
        {_, [{route, exprs} | _]} <- routes_in_order(helper_routes),
        suffix <- @known_suffixes,
        !localized_route?(route) do
      {_bins, vars} = :lists.unzip(exprs.binding)

      quote do
        def unquote(:"#{route.helper}_#{suffix}")(
              conn_or_endpoint,
              plug_opts,
              unquote_splicing(vars)
            ) do
          unquote(helper_module).unquote(:"#{route.helper}_#{suffix}")(
            conn_or_endpoint,
            plug_opts,
            unquote_splicing(vars)
          )
        end

        def unquote(:"#{route.helper}_#{suffix}")(
              conn_or_endpoint,
              plug_opts,
              unquote_splicing(vars),
              params
            ) do
          unquote(helper_module).unquote(:"#{route.helper}_#{suffix}")(
            conn_or_endpoint,
            plug_opts,
            unquote_splicing(vars),
            params
          )
        end
      end
    end
  end

  defp localized_route?(route) do
    Map.has_key?(route.private, :cldr_locale)
  end

  defp delegate_helpers(groups, helper_module, cldr_backend) do
    for {_helper, helper_routes} <- groups,
        {_, [{route, exprs} | _]} <- routes_in_order(helper_routes),
        locale_name <- cldr_backend.known_locale_names(),
        {:ok, locale} = cldr_backend.validate_locale(locale_name),
        suffix <- @known_suffixes,
        helper_fun_name = strip_locale(route.helper, locale),
        helper_fun_name != route.helper do
      {_bins, vars} = :lists.unzip(exprs.binding)

      quote do
        @doc false
        def helper(
              unquote(helper_fun_name),
              unquote(suffix),
              %Cldr.LanguageTag{gettext_locale_name: unquote(locale.gettext_locale_name)},
              conn_or_endpoint,
              plug_opts,
              unquote_splicing(vars),
              params
            ) do
          unquote(helper_module).unquote(:"#{route.helper}_#{suffix}")(
            conn_or_endpoint,
            plug_opts,
            unquote_splicing(vars),
            params
          )
        end
      end
    end
  end

  # Define function clauses that catch error in action for a
  # valid helper with a valid locale. Does not catch errors
  # for a valid helper that is not available in the specified
  # locale.

  defp catch_all(groups, helper_module) do
    for {helper, routes_and_exprs} <- groups,
        proxy_helper = strip_locale(helper),
        helper != proxy_helper do
      routes =
        routes_and_exprs
        |> Enum.map(fn {routes, exprs} ->
          {routes.plug_opts, Enum.map(exprs.binding, &elem(&1, 0))}
        end)
        |> Enum.sort()

      params_lengths =
        routes
        |> Enum.map(fn {_, bindings} -> length(bindings) end)
        |> Enum.uniq()

      binding_lengths = Enum.reject(params_lengths, &((&1 - 1) in params_lengths))

      catch_all_no_params =
        for length <- binding_lengths do
          binding = List.duplicate({:_, [], nil}, length)
          arity = length + 2

          quote do
            def helper(
                  unquote(proxy_helper),
                  suffix,
                  locale,
                  conn_or_endpoint,
                  action,
                  unquote_splicing(binding)
                ) do
              path(conn_or_endpoint, "/")

              raise_route_error(
                unquote(proxy_helper),
                suffix,
                unquote(arity),
                action,
                locale,
                unquote(helper_module),
                unquote(helper),
                []
              )
            end
          end
        end

      catch_all_params =
        for length <- params_lengths do
          binding = List.duplicate({:_, [], nil}, length)
          arity = length + 2

          quote do
            def helper(
                  unquote(proxy_helper),
                  suffix,
                  locale,
                  conn_or_endpoint,
                  action,
                  unquote_splicing(binding),
                  params
                ) do
              path(conn_or_endpoint, "/")

              raise_route_error(
                unquote(proxy_helper),
                suffix,
                unquote(arity + 1),
                action,
                locale,
                unquote(helper_module),
                unquote(helper),
                params
              )
            end

            defp raise_route_error(
                   unquote(proxy_helper),
                   suffix,
                   arity,
                   action,
                   locale,
                   unquote(helper_module),
                   unquote(helper),
                   params
                 ) do
              Cldr.Routes.LocalizedHelpers.raise_route_error(
                __MODULE__,
                "#{unquote(proxy_helper)}_#{suffix}",
                arity,
                action,
                locale,
                unquote(helper_module),
                unquote(helper),
                unquote(Macro.escape(routes)),
                params
              )
            end
          end
        end

      quote do
        unquote_splicing(catch_all_no_params)
        unquote_splicing(catch_all_params)
      end
    end
  end

  defp other_delegates(helper_module) do
    quote do
      @doc """
      Generates the path information including any necessary prefix.
      """
      def path(data, path) do
        unquote(helper_module).path(data, path)
      end

      @doc """
      Generates the connection/endpoint base URL without any path information.
      """
      def url(data) do
        unquote(helper_module).url(data)
      end

      @doc """
      Generates path to a static asset given its file path.
      """
      def static_path(conn_or_endpoint, path) do
        unquote(helper_module).static_path(conn_or_endpoint, path)
      end

      @doc """
      Generates url to a static asset given its file path.
      """
      def static_url(conn_or_endpoint, path) do
        unquote(helper_module).static_url(conn_or_endpoint, path)
      end

      @doc """
      Generates an integrity hash to a static asset given its file path.
      """
      def static_integrity(conn_or_endpoint, path) do
        unquote(helper_module).static_integrity(conn_or_endpoint, path)
      end

      @doc """
      Generates HTML `link` tags for a given map of locale => URLs

      This function generates `<link .../>` tags that should be placed in the
      `<head>` section of an HTML document to indicate the different language
      versions of a given page.

      The `MyApp.Router.LocalizedHelpers.<helper>_link` functions can
      generate the required mapping from locale to URL for a given helper.
      These `_link` helpers take the same arguments as the `_path` and
      `_url` helpers.

      See https://developers.google.com/search/docs/advanced/crawling/localized-versions#http

      ### Example

            ===> MyApp.Helpers.LocalizedHelpers.user_links(conn, :show, 1)
            ...> |> MyApp.Helpers.LocalizedHelpers.hreflang_links()

      """
      @spec hreflang_links(%{LocalizedHelpers.locale_name() => LocalizedHelpers.url()}) ::
              Phoenix.HTML.safe()

      def hreflang_links(url_map) do
        Cldr.Routes.LocalizedHelpers.hreflang_links(url_map)
      end
    end
  end

  # Return a map of locales to URLs that can be used to
  # create HTTP headers like `Link: <url1>; rel="alternate"; hreflang="lang_code_1"`

  defp href_link_helpers(routes) do
    for {helper, routes_by_locale} <- helper_by_locale(routes),
        {vars, locales} <- routes_by_locale do
      if locales == [] do
        quiet_vars =
          Enum.map(vars, fn var ->
            quote do
              _ = unquote(var)
            end
          end)

        quote generated: true, location: :keep do
          def unquote(:"#{helper}_links")(conn_or_endpoint, plug_opts, unquote_splicing(vars)) do
            unquote_splicing(quiet_vars)
            Map.new()
          end
        end
      else
        quote generated: true, location: :keep do
          def unquote(:"#{helper}_links")(conn_or_endpoint, plug_opts, unquote_splicing(vars)) do
            for locale <- unquote(Macro.escape(locales)) do
              Cldr.with_locale(locale, fn ->
                {
                  Map.fetch!(locale, :requested_locale_name),
                  unquote(:"#{helper}_url")(conn_or_endpoint, plug_opts, unquote_splicing(vars))
                }
              end)
            end
            |> Map.new()
          end
        end
      end
    end
  end

  defp routes_in_order(routes) do
    routes
    |> Enum.group_by(fn {_route, exprs} -> length(exprs.binding) end)
    |> Enum.sort()
  end

  def helper_by_locale(routes) do
    routes
    |> Enum.group_by(fn {route, _exprs} ->
      if localized_route?(route), do: strip_locale(route.helper), else: route.helper
    end)
    |> Enum.map(fn {helper, routes} ->
      {helper, routes_by_locale(routes)}
    end)
  end

  defp routes_by_locale(routes) do
    Enum.group_by(
      routes,
      fn {_route, exprs} -> elem(:lists.unzip(exprs.binding), 1) end,
      fn {route, _exprs} -> route.private[:cldr_locale] end
    )
    |> Enum.map(fn
      {vars, [nil]} -> {vars, []}
      {vars, locales} -> {vars, Enum.uniq(locales)}
    end)
  end

  @doc false
  @dialyzer {:nowarn_function, raise_route_error: 9}
  def raise_route_error(mod, fun, arity, action, locale, helper_module, helper, routes, params) do
    cond do
      localized_fun_exists?(helper_module, helper, fun, arity) ->
        "no function clause for #{inspect(mod)}.#{fun}/#{arity} for locale #{inspect(locale)}"
        |> invalid_route_error(fun, routes)

      is_atom(action) and not Keyword.has_key?(routes, action) ->
        "no action #{inspect(action)} for #{inspect(mod)}.#{fun}/#{arity}"
        |> invalid_route_error(fun, routes)

      is_list(params) or is_map(params) ->
        "no function clause for #{inspect(mod)}.#{fun}/#{arity} and action #{inspect(action)}"
        |> invalid_route_error(fun, routes)

      true ->
        invalid_param_error(mod, fun, arity, action, routes)
    end
  end

  defp localized_fun_exists?(helper_module, helper, fun, arity) do
    suffix = String.split(fun, "_") |> Enum.reverse() |> hd()
    helper = :"#{helper}_#{suffix}"
    function_exported?(helper_module, helper, arity)
  end

  defp invalid_route_error(prelude, fun, routes) do
    suggestions =
      for {action, bindings} <- routes do
        bindings = Enum.join([inspect(action) | bindings], ", ")
        "\n    #{fun}(conn_or_endpoint, #{bindings}, params \\\\ [])"
      end

    raise ArgumentError,
          "#{prelude}. The following actions/clauses are supported:\n#{suggestions}"
  end

  defp invalid_param_error(mod, fun, arity, action, routes) do
    call_vars = Keyword.fetch!(routes, action)

    raise ArgumentError, """
    #{inspect(mod)}.#{fun}/#{arity} called with invalid params.
    The last argument to this function should be a keyword list or a map.
    For example:

        #{fun}(#{Enum.join(["conn", ":#{action}" | call_vars], ", ")}, page: 5, per_page: 10)

    It is possible you have called this function without defining the proper
    number of path segments in your router.
    """
  end

  @doc """
  Generates HTML `link` tags for a given map of locale => URLs

  This function generates `<link ... />` tags that should be placed in the
  `<head>` section of an HTML document to indicate the different language
  versions of a given page.

  The `MyApp.Router.LocalizedHelpers.<helper>_link` functions can
  generate the required mapping from locale to URL for a given helper.
  These `_link` helpers take the same arguments as the `_path` and
  `_url` helpers.

  If the helper refers to a route that is not localized then an
  empty string will be returned since there are no alternative
  localizations of this route.

  See https://developers.google.com/search/docs/advanced/crawling/localized-versions#http

  ### Examples

      iex> links = %{
      ...>   "en" => "https://localhost/users/1",
      ...>   "fr" => "https://localhost/utilisateurs/1"
      ...>  }
      iex> Cldr.Routes.LocalizedHelpers.hreflang_links(links)
      {
        :safe,
        [
          [60, "link", [32, "href", 61, 34, "https://localhost/users/1", 34, 32, "hreflang", 61, 34, "en", 34, 32, "rel", 61, 34, "alternate", 34], 62],
          10,
          [60, "link", [32, "href", 61, 34, "https://localhost/utilisateurs/1", 34, 32, "hreflang", 61, 34, "fr", 34, 32, "rel", 61, 34, "alternate", 34], 62]
        ]
      }

      iex> Cldr.Routes.LocalizedHelpers.hreflang_links(nil)
      {:safe, []}

      iex> Cldr.Routes.LocalizedHelpers.hreflang_links(%{})
      {:safe, []}

  """
  @spec hreflang_links(%{locale_name() => url()}) :: Phoenix.HTML.safe()
  def hreflang_links(nil) do
    {:safe, []}
  end

  def hreflang_links(url_map) when is_map(url_map) do
    links =
      for {locale, url} <- url_map do
        {:safe, link} =
          PhoenixHTMLHelpers.Tag.tag(:link, href: url, rel: "alternate", hreflang: locale)

        link
      end
      |> Enum.intersperse(?\n)

    {:safe, links}
  end

  @doc false
  def strip_locale(helper, locale)

  def strip_locale(helper, %Cldr.LanguageTag{} = locale) do
    locale_name = locale.gettext_locale_name
    strip_locale(helper, locale_name)
  end

  def strip_locale(helper, nil) do
    helper
  end

  def strip_locale(nil = helper, _locale) do
    helper
  end

  def strip_locale(helper, locale_name) when is_binary(locale_name) do
    helper
    |> String.split(Regex.compile!("(_#{locale_name}_)|(_#{locale_name}$)"), trim: true)
    |> Enum.join("_")
  end

  @doc false
  def strip_locale(helper) when is_binary(helper) do
    locale =
      helper
      |> String.split("_")
      |> Enum.reverse()
      |> hd()

    strip_locale(helper, locale)
  end
end
