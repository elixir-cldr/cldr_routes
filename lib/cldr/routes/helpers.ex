defmodule Cldr.Routes.LocalizedHelpers do
  # Module that generates the routing helpers.
  # This version is forked from the Phoenix default
  # version to generate localized paths based
  # upon gettext translations.

  @moduledoc false

  alias Phoenix.Router.Route
  alias Plug.Conn

  @dont_localize ["edit", "new"]
  @gettext_domain "routes"

  @doc """
  Callback invoked by the url generated in each helper module.
  """
  def url(_router, %Conn{private: private}) do
    case private do
      %{phoenix_router_url: url} when is_binary(url) -> url
      %{phoenix_endpoint: endpoint} -> endpoint.url()
    end
  end

  def url(_router, %_{endpoint: endpoint}) do
    endpoint.url()
  end

  def url(_router, %URI{} = uri) do
    URI.to_string(%{uri | path: nil})
  end

  def url(_router, endpoint) when is_atom(endpoint) do
    endpoint.url()
  end

  def url(router, other) do
    raise ArgumentError,
      "expected a %Plug.Conn{}, a %Phoenix.Socket{}, a %URI{}, a struct with an :endpoint key, " <>
      "or a Phoenix.Endpoint when building url for #{inspect(router)}, got: #{inspect(other)}"
  end

  @doc """
  Callback invoked by path generated in each helper module.
  """
  def path(router, %Conn{} = conn, path) do
    conn
    |> build_own_forward_path(router, path)
    |> Kernel.||(build_conn_forward_path(conn, router, path))
    |> Kernel.||(path_with_script(path, conn.script_name))
  end

  def path(_router, %URI{} = uri, path) do
    (uri.path || "") <> path
  end

  def path(_router, %_{endpoint: endpoint}, path) do
    endpoint.path(path)
  end

  def path(_router, endpoint, path) when is_atom(endpoint) do
    endpoint.path(path)
  end

  def path(router, other, _path) do
    raise ArgumentError,
      "expected a %Plug.Conn{}, a %Phoenix.Socket{}, a %URI{}, a struct with an :endpoint key, " <>
      "or a Phoenix.Endpoint when building path for #{inspect(router)}, got: #{inspect(other)}"
  end

  ## Helpers

  defp build_own_forward_path(conn, router, path) do
    case Map.fetch(conn.private, router) do
      {:ok, {local_script, _}} ->
        path_with_script(path, local_script)
      :error -> nil
    end
  end

  defp build_conn_forward_path(%Conn{private: %{phoenix_router: phx_router}} = conn, router, path) do
    case Map.fetch(conn.private, phx_router) do
      {:ok, {script_name, forwards}} ->
        case Map.fetch(forwards, router) do
          {:ok, local_script} ->
            path_with_script(path, script_name ++ local_script)
          :error -> nil
        end
      :error -> nil
    end
  end
  defp build_conn_forward_path(_conn, _router, _path), do: nil

  defp path_with_script(path, []) do
    path
  end
  defp path_with_script(path, script) do
    "/" <> Enum.join(script, "/") <> path
  end

  @doc """
  Generates the helper module for the given environment and routes.
  """
  def define(env, routes, opts \\ []) do
    # Ignore any route without helper or forwards.
    routes =
      Enum.reject(routes, fn {route, _exprs} ->
        is_nil(route.helper) or route.kind == :forward
      end)

    trailing_slash? = Enum.any?(routes, fn {route, _} -> route.trailing_slash? end)
    groups = Enum.group_by(routes, fn {route, _exprs} -> route.helper end)

    impls =
      for {_helper, helper_routes} <- groups,
          {_, [{route, exprs} | _]} <-
            helper_routes
            |> Enum.group_by(fn {route, exprs} -> [length(exprs.binding) | route.plug_opts] end)
            |> Enum.sort(),
          do: defhelper(route, exprs)

    catch_all = Enum.map(groups, &defhelper_catch_all/1)

    defhelper = quote [generated: true, unquote: false] do
      defhelper = fn helper, vars, opts, bins, segs, trailing_slash? ->
        def unquote(:"#{helper}_path")(conn_or_endpoint, unquote(Macro.escape(opts)), unquote_splicing(vars)) do
          unquote(:"#{helper}_path")(conn_or_endpoint, unquote(Macro.escape(opts)), unquote_splicing(vars), [])
        end

        def unquote(:"#{helper}_path")(conn_or_endpoint, unquote(Macro.escape(opts)), unquote_splicing(vars), params)
            when is_list(params) or is_map(params) do
          path(conn_or_endpoint, segments(unquote(segs), params, unquote(bins), unquote(trailing_slash?),
                {unquote(helper), unquote(Macro.escape(opts)), unquote(Enum.map(vars, &Macro.to_string/1))}))
        end

        def unquote(:"#{helper}_url")(conn_or_endpoint, unquote(Macro.escape(opts)), unquote_splicing(vars)) do
          unquote(:"#{helper}_url")(conn_or_endpoint, unquote(Macro.escape(opts)), unquote_splicing(vars), [])
        end

        def unquote(:"#{helper}_url")(conn_or_endpoint, unquote(Macro.escape(opts)), unquote_splicing(vars), params)
            when is_list(params) or is_map(params) do
          url(conn_or_endpoint) <> unquote(:"#{helper}_path")(conn_or_endpoint, unquote(Macro.escape(opts)), unquote_splicing(vars), params)
        end
      end
    end

    defcatch_all = quote [generated: true, unquote: false] do
      defcatch_all = fn helper, binding_lengths, params_lengths, routes ->
	      for length <- binding_lengths do
	        binding = List.duplicate({:_, [], nil}, length)
	        arity = length + 2

          def unquote(:"#{helper}_path")(conn_or_endpoint, action, unquote_splicing(binding)) do
            path(conn_or_endpoint, "/")
            raise_route_error(unquote(helper), :path, unquote(arity), action, [])
          end

          def unquote(:"#{helper}_url")(conn_or_endpoint, action, unquote_splicing(binding)) do
            url(conn_or_endpoint)
            raise_route_error(unquote(helper), :url, unquote(arity), action, [])
          end
        end

        for length <- params_lengths do
          binding = List.duplicate({:_, [], nil}, length)
          arity = length + 2

          def unquote(:"#{helper}_path")(conn_or_endpoint, action, unquote_splicing(binding), params) do
            path(conn_or_endpoint, "/")
            raise_route_error(unquote(helper), :path, unquote(arity + 1), action, params)
          end

          def unquote(:"#{helper}_url")(conn_or_endpoint, action, unquote_splicing(binding), params) do
            url(conn_or_endpoint)
            raise_route_error(unquote(helper), :url, unquote(arity + 1), action, params)
          end
        end

        defp raise_route_error(unquote(helper), suffix, arity, action, params) do
          Phoenix.Router.Helpers.raise_route_error(
            __MODULE__,
            "#{unquote(helper)}_#{suffix}",
            arity,
            action,
            unquote(Macro.escape(routes)),
            params
          )
        end
      end
    end

    docs = Keyword.get(opts, :docs, true)

    # It is in general bad practice to generate large chunks of code
    # inside quoted expressions. However, we can get away with this
    # here for two reasons:
    #
    # * Helper modules are quite uncommon, typically one per project.
    #
    # * We inline most of the code for performance, so it is specific
    #   per helper module anyway.
    #
    code = quote do
      @moduledoc unquote(docs) && """
      Module with named helpers generated from #{inspect unquote(env.module)}.

      This module provides localized helpers. Routes that are generated in
      the scope of the `Cldr.Routes.localize/1` macro also generate
      localized path helpers in this module.

      For example:
      ```elixir
      iex> MyApp.Router.LocalizedHelpers.page_path %Plug.Conn{}, :show, 1
      "/pages/1"
      iex> Gettext.put_locale MyAppWeb.Gettext, "fr"
      iex> MyApp.Router.LocalizedHelpers.page_path %Plug.Conn{}, :show, 1
      "/pages_fr/1"
      ```

      """
      unquote(defhelper)
      unquote(defcatch_all)
      unquote_splicing(impls)
      unquote_splicing(catch_all)

      @doc """
      Generates the path information including any necessary prefix.
      """
      def path(data, path) do
        Cldr.Routes.LocalizedHelpers.path(unquote(env.module), data, path)
      end

      @doc """
      Generates the connection/endpoint base URL without any path information.
      """
      def url(data) do
        Cldr.Routes.LocalizedHelpers.url(unquote(env.module), data)
      end

      @doc """
      Generates path to a static asset given its file path.
      """
      def static_path(%Conn{private: private} = conn, path) do
        private.phoenix_endpoint.static_path(path)
      end

      def static_path(%_{endpoint: endpoint} = conn, path) do
        endpoint.static_path(path)
      end

      def static_path(endpoint, path) when is_atom(endpoint) do
        endpoint.static_path(path)
      end

      @doc """
      Generates url to a static asset given its file path.
      """
      def static_url(%Conn{private: private}, path) do
        case private do
          %{phoenix_static_url: url} when is_binary(url) -> url <> path
          %{phoenix_endpoint: endpoint} -> static_url(endpoint, path)
        end
      end

      def static_url(%_{endpoint: endpoint} = conn, path) do
        static_url(endpoint, path)
      end

      def static_url(endpoint, path) when is_atom(endpoint) do
        endpoint.static_url() <> endpoint.static_path(path)
      end

      @doc """
      Generates an integrity hash to a static asset given its file path.
      """
      def static_integrity(%Conn{private: %{phoenix_endpoint: endpoint}}, path) do
        static_integrity(endpoint, path)
      end

      def static_integrity(%_{endpoint: endpoint}, path) do
        static_integrity(endpoint, path)
      end

      def static_integrity(endpoint, path) when is_atom(endpoint) do
        endpoint.static_integrity(path)
      end

      # Functions used by generated helpers
      # Those are inlined here for performance

      defp to_param(int) when is_integer(int), do: Integer.to_string(int)
      defp to_param(bin) when is_binary(bin), do: bin
      defp to_param(false), do: "false"
      defp to_param(true), do: "true"
      defp to_param(data), do: Phoenix.Param.to_param(data)

      defp segments(segments, [], _reserved, trailing_slash?, _opts) do
        maybe_append_slash(segments, trailing_slash?)
      end

      defp segments(segments, query, reserved, trailing_slash?, _opts) when is_list(query) or is_map(query) do
        dict = for {k, v} <- query,
               not ((k = to_string(k)) in reserved),
               do: {k, v}


        case Conn.Query.encode dict, &to_param/1 do
          "" -> maybe_append_slash(segments, trailing_slash?)
          o  -> maybe_append_slash(segments, trailing_slash?) <> "?" <> o
        end
      end

      if unquote(trailing_slash?) do
        defp maybe_append_slash("/", _), do: "/"
        defp maybe_append_slash(path, true), do: path <> "/"
      end

      defp maybe_append_slash(path, _), do: path
    end

    Module.create(Module.concat(env.module, LocalizedHelpers), code, line: env.line, file: env.file)
  end

  @doc """
  Receives a route and returns the quoted definition for its helper function.

  In case a helper name was not given, or route is forwarded, returns nil.
  """
  def defhelper(%Route{} = route, exprs) do
    helper = route.helper
    opts = route.plug_opts
    trailing_slash? = route.trailing_slash?

    {bins, vars} = :lists.unzip(exprs.binding)
    segs = expand_segments(exprs.path, route.assigns)

    quote do
      defhelper.(
        unquote(helper),
        unquote(Macro.escape(vars)),
        unquote(Macro.escape(opts)),
        unquote(Macro.escape(bins)),
        unquote(Macro.escape(segs)),
        unquote(Macro.escape(trailing_slash?))
      )
    end
  end

  def defhelper_catch_all({helper, routes_and_exprs}) do
    routes =
      routes_and_exprs
      |> Enum.map(fn {routes, exprs} -> {routes.plug_opts, Enum.map(exprs.binding, &elem(&1, 0))} end)
      |> Enum.sort()

    params_lengths =
	    routes
	    |> Enum.map(fn {_, bindings} -> length(bindings) end)
	    |> Enum.uniq()

    # Each helper defines catch alls like this:
    #
    #     def helper_path(context, action, ...binding)
    #     def helper_path(context, action, ...binding, params)
    #
    # Given the helpers are ordered by binding length, the additional
    # helper with param for a helper_path/n will always override the
    # binding for helper_path/n+1, so we skip those here to avoid warnings.
    binding_lengths =
      Enum.reject(params_lengths, &(&1 - 1 in params_lengths))

    quote do
      defcatch_all.(
        unquote(helper),
        unquote(binding_lengths),
        unquote(params_lengths),
        unquote(Macro.escape(routes))
      )
    end
  end

  @doc """
  Callback for properly encoding parameters in routes.
  """
  def encode_param(str), do: URI.encode(str, &URI.char_unreserved?/1)

  defp expand_segments([], _assigns), do: "/" |> IO.inspect(label: "Root")

  defp expand_segments(segments, assigns) when is_list(segments) do
    expand_segments(segments, "", assigns)
  end

  defp expand_segments(segments, _assigns) do
    quote(do: "/" <> Enum.map_join(unquote(segments), "/", &unquote(__MODULE__).encode_param/1))
  end

  defp expand_segments([{:|, _, [h, t]}], acc, assigns),
    do: quote(do: unquote(expand_segments([h], acc, assigns)) <> "/" <> Enum.map_join(unquote(t), "/", &unquote(__MODULE__).encode_param/1))

  defp expand_segments([h|t], acc, assigns) when is_binary(h),
    do: expand_segments(t, quote(do: unquote(acc) <> "/" <> unquote(__MODULE__).localize(unquote(h), unquote(Macro.escape(assigns)))), assigns)
    # do: expand_segments(t, quote(do: unquote(acc) <> unquote("/" <> h)))

  defp expand_segments([h|t], acc, assigns),
    do: expand_segments(t, quote(do: unquote(acc) <> "/" <> unquote(__MODULE__).encode_param(to_param(unquote(h)))), assigns)

  defp expand_segments([], acc, _assigns),
    do: acc

  @doc false
  def localize(string, _assigns) when string in @dont_localize do
    string
  end

  def localize(string, %{cldr_locale: %Cldr.LanguageTag{backend: backend}}) do
    if (gettext = backend.__cldr__(:config).gettext) do
      Gettext.dgettext(gettext, @gettext_domain, string)
    else
      string
    end
  end

  def localize(string, _assigns) do
    string
  end
end
