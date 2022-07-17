defmodule Cldr.Route.LocalizedHelpers do
  @moduledoc """
  Generates a module that implements localised helpers.

  It introspects the generated helpers module and creates
  a wrapper function that translates (at compile time) the
  path segments.

  """
  @known_suffixes ["path", "url"]

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
    proxy_helpers = proxy_helpers(groups, helper_module, cldr_backend)
    other_proxies = other_proxies(helper_module)
    catch_all = catch_all(groups, helper_module)

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
        unquote_splicing(catch_all)
      end

    Module.create(localized_helper_module, code, line: env.line, file: env.file)
  end

  def localized_helpers(groups, cldr_backend) do
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
    Map.has_key?(route.assigns, :cldr_locale) or Map.has_key?(route.private, :cldr_locale)
  end

  defp proxy_helpers(groups, helper_module, cldr_backend) do
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
              Cldr.Route.LocalizedHelpers.raise_route_error(
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

  @doc """
  Callback for generate router catch alls.
  """
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

  defp routes_in_order(routes) do
    routes
    |> Enum.group_by(fn {_route, exprs} -> length(exprs.binding) end)
    |> Enum.sort()
  end

  @doc false
  def strip_locale(helper, locale, joiner \\ "_")
  def strip_locale(helper, %Cldr.LanguageTag{} = locale, joiner) do
    locale_name = locale.gettext_locale_name
    strip_locale(helper, locale_name, joiner)
  end

  def strip_locale(helper, locale_name, joiner) when is_binary(locale_name) do
    helper
    |> String.split(Regex.compile!("(_#{locale_name}[_/])|(_#{locale_name}$)"), trim: true)
    |> Enum.join(joiner)
  end

  def strip_locale(helper) when is_binary(helper) do
    locale =
      helper
      |> String.split("_")
      |> Enum.reverse()
      |> hd()

    strip_locale(helper, locale)
  end
end
