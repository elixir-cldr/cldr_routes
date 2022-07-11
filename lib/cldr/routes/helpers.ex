defmodule Cldr.Route.LocalizedHelpers do
  @moduledoc """
  Generates a module that implements localised helpers.

  It introspects the generated helpers module and creates
  a wrapper function that translates (at compile time) the
  path segments.

  """

  def define(env, routes, opts \\ []) do
    localized_helper_module = Module.concat([env.module, LocalizedHelpers])
    helper_module = Module.concat([env.module, Helpers])
    cldr_backend = Module.get_attribute(env.module, :_cldr_backend)
    default_locale = cldr_backend.default_locale()

    routes =
      Enum.reject(routes, fn {route, _exprs} ->
        is_nil(route.helper) or route.kind == :forward
      end)

    groups = Enum.group_by(routes, fn {route, _exprs} -> route.helper end)

    docs = Keyword.get(opts, :docs, true)
    localized_helpers = localized_helpers(groups, cldr_backend, default_locale)
    non_localized_helpers = non_localized_helpers(groups, helper_module)
    proxy_helpers = proxy_helpers(groups, helper_module, cldr_backend)
    other_proxies = other_proxies(helper_module)

    code =
      quote do
        @moduledoc unquote(docs) &&
        """
        Module with localized helpers generated from #{inspect(unquote(env.module))}.
        """
        unquote_splicing(localized_helpers)
        unquote_splicing(non_localized_helpers)
        unquote_splicing(proxy_helpers)
        unquote(other_proxies)
      end

    Module.create(localized_helper_module, code, line: env.line, file: env.file)
  end

  def localized_helpers(groups, cldr_backend, default_locale) do
    for {_helper, helper_routes} <- groups,
        {_, [{route, exprs} | _]} <- unique_routes_in_order(helper_routes, default_locale),
        suffix <- ["path", "url"] do
      helper_fun_name = strip_locale(route.helper, default_locale)
      {_bins, vars} = :lists.unzip(exprs.binding)

      quote do
        def unquote(:"#{helper_fun_name}#{suffix}")(
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
            unquote_splicing(vars), %{}
          )
        end

        def unquote(:"#{helper_fun_name}#{suffix}")(
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
        suffix <- ["path", "url"],
        !Map.has_key?(route.assigns, :cldr_locale) do
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

  defp proxy_helpers(groups, helper_module, cldr_backend) do
    for {_helper, helper_routes} <- groups,
        {_, [{route, exprs} | _]} <- routes_in_order(helper_routes),
        locale_name <- cldr_backend.known_locale_names(),
        {:ok, locale} = cldr_backend.validate_locale(locale_name),
        suffix <- ["path", "url"] do
      helper_fun_name = strip_locale(route.helper, locale)
      {_bins, vars} = :lists.unzip(exprs.binding)

      quote do
        @doc false
        def helper(
              unquote(helper_fun_name),
              unquote(suffix),
              unquote(Macro.escape(locale)),
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

  defp other_proxies(helper_module) do
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

    end
  end

  defp unique_routes_in_order(routes, default_locale) do
    routes
    |> Enum.filter(fn {route, _exprs} -> route.assigns[:cldr_locale] == default_locale end)
    |> Enum.group_by(fn {_route, exprs} -> length(exprs.binding) end)
    |> Enum.map(fn {len, routes} -> {len, uniq_helper(routes)} end)
    |> Enum.sort()
  end

  defp routes_in_order(routes) do
    routes
    |> Enum.group_by(fn {_route, exprs} -> length(exprs.binding) end)
    |> Enum.sort()
  end

  defp strip_locale(helper, %Cldr.LanguageTag{} = locale) do
    locale_name = locale.gettext_locale_name
    strip_locale(helper, locale_name)
  end

  defp strip_locale(helper, locale_name) when is_binary(locale_name) do
    helper
    |> String.split(Regex.compile!("(_#{locale_name}_)|(_#{locale_name}$)"))
    |> Enum.join("_")
  end

  defp uniq_helper(routes) do
    Enum.uniq_by(routes, fn {route, _exprs} -> route.helper end)
  end
end
