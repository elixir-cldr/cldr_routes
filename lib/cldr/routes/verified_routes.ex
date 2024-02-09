defmodule Cldr.VerifiedRoutes do
  @moduledoc false

  def cldr_backend_provider(config) do
    backend = config.backend
    gettext = config.gettext

    quote location: :keep do
      defmodule VerifiedRoutes do
        @moduledoc """
        Implements localized verified routes.

        This module is intended to substitute for the direct
        use of `Phoenix.VerifiedRoutes` by providing support
        for localized verified routes.

        Therefore instead of configuring with:

        ```elixir
        use Phoenix.VerifiedRoutes,
          router: MyApp.Router,
          endpoint: MyApp.Endpoint
        ```
        configure instead:

        ```
        use MyApp.Cldr.VerifiedRoutes,
          router: MyApp.Router,
          endpoint: MyApp.Endpoint
        ```

        where `MyApp.Cldr` is the name of a `Cldr` backend
        module.

        When configured, the sigil `~q` is made available
        to express localized verified routes. Sigil `~p` remains
        available for non-localized verified routes.

        """

        defmacro __using__(opts) do
          caller = __CALLER__.module
          backend = unquote(backend)
          gettext = unquote(gettext)

          quote location: :keep do
            use Phoenix.VerifiedRoutes, unquote(opts)
            require unquote(gettext)
            import unquote(backend).VerifiedRoutes, only: :macros
          end
        end

        @doc """
        Sigil_q implements localized verified routes for Phoenix
        1.7 and later.

        Adding
        ```
        use MyApp.Cldr.VerifiedRoutes,
          router: MyApp.Router,
          endpoint: MyApp.Endpoint
        ```
        to a module, where `MyApp.Cldr` is the name of a Cldr backend module,
        gives access to `sigil_q` which is functionally equal to
        Phoenix Verified Routes `sigil_p`. In fact the result of using `sigil_q`
        is code that looks like this:

        ```
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

        Some use cases call for the locale, language or territory
        to be part of the URL. `Sigl_q` makes this easy by providing
        the following interpolations:

        `:locale` is replaced with cldr locale name.
        `:language` is replaced with the cldr language code.
        `:territory` is replaced with the cldr territory code.

        """
        defmacro sigil_q({:<<>>, _meta, _segments} = route, flags) do
          import Cldr.VerifiedRoutes, only: [sigil_q_case_clauses: 5]
          import Cldr.Routes, only: [locales_from_unique_gettext_locales: 1]

          backend = unquote(backend)
          gettext = unquote(gettext)

          cldr_locale_names =
            locales_from_unique_gettext_locales(unquote(backend))

          case_clauses =
            sigil_q_case_clauses(route, flags, backend, cldr_locale_names, gettext)

          quote location: :keep do
            case unquote(backend).get_locale().cldr_locale_name do
              unquote(case_clauses)
            end
          end
        end

        defp attr!(%{function: nil}, _) do
          raise "Cldr.VerifiedRoutes can only be used inside functions, please move your usage of ~p to functions"
        end

        defp attr!(env, :endpoint) do
          Module.get_attribute(env.module, :endpoint) ||
            raise """
            expected @endpoint to be set. For dynamic endpoint resolution, use path/2 instead.

            for example:

                url_q(conn_or_socket, "/my-path")
            """
        end

        defp attr!(env, name) do
          Module.get_attribute(env.module, name) || raise "expected @#{name} module attribute to be set"
        end


        @doc """
        Generates the url with localized route verification from the connection, socket, or URI and router.

        See `url_q/1` for more information.
        """
        defmacro url_q(conn_or_socket_or_endpoint_or_uri, router, route) do
          import Cldr.VerifiedRoutes, only: [url_q_case_clauses: 6]
          import Cldr.Routes, only: [locales_from_unique_gettext_locales: 1]

          router = Macro.expand(router, __CALLER__)
          backend = unquote(backend)
          gettext = unquote(gettext)

          cldr_locale_names =
            locales_from_unique_gettext_locales(unquote(backend))

          case_clauses =
            url_q_case_clauses(conn_or_socket_or_endpoint_or_uri, router, route, backend, cldr_locale_names, gettext)

          quote location: :keep do
            case unquote(backend).get_locale().cldr_locale_name do
              unquote(case_clauses)
            end
          end
        end


        @doc ~S'''
        Generates the router url with localized route verification.

        See `sigil_q/2` for more information. Please note the missing ~q.

        ## Examples

            use MyApp.Cldr.VerifiedRoutes,
              router: MyApp.Router,
              endpoint: MyApp.Endpoint

            redirect(to: url_q(conn, "/users/top"))

            redirect(to: url_q(conn, "/users/#{@user}"))

            ~H"""
            <.link href={url_q(@uri, "/users?#{[page: @page]}")}>profile</.link>
            """

        The router may also be provided in cases where you want to verify routes for a
        router other than the one passed to `use Phoenix.VerifiedRoutes`:

            redirect(to: url_q(conn, OtherRouter, "/users"))
        '''
        defmacro url_q(route) do
          endpoint = attr!(__CALLER__, :endpoint)
          router = attr!(__CALLER__, :router)

          quote location: :keep do
            url_q(unquote(endpoint), unquote(router), unquote(route))
          end
        end


        @doc """
        Generates the router url with localized route verification from the connection, socket, or URI.

        See `url_q/1` for more information.
        """
        defmacro url_q(conn_or_socket_or_endpoint_or_uri, route) do
          router = attr!(__CALLER__, :router)

          quote location: :keep do
            url_q(unquote(conn_or_socket_or_endpoint_or_uri), unquote(router), unquote(route))
          end
        end
      end
    end
  end

  @doc false
  def sigil_q_case_clauses(route, flags, cldr_backend, cldr_locale_names, gettext_backend) do
    for cldr_locale_name <- cldr_locale_names do
      with {:ok, cldr_locale} <- cldr_backend.validate_locale(cldr_locale_name) do
        if cldr_locale.gettext_locale_name do
          translated_route =
            Cldr.Routes.interpolate_and_translate_path(route, cldr_locale, gettext_backend)

          quote location: :keep do
            unquote(cldr_locale_name) -> sigil_p(unquote(translated_route), unquote(flags))
          end
        else
          IO.warn(
            "Locale #{inspect(cldr_locale_name)} has no associated gettext locale. Cannot translate #{inspect(route)}",
            []
          )

          nil
        end
      else
        {:error, {exception, reason}} -> raise exception, reason
      end
    end
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&hd/1)
  end

  @doc false
  def url_q_case_clauses(conn_or_socket_or_endpoint_or_uri, router, route, cldr_backend, cldr_locale_names, gettext_backend) do
    for cldr_locale_name <- cldr_locale_names do
      with {:ok, cldr_locale} <- cldr_backend.validate_locale(cldr_locale_name) do
        if cldr_locale.gettext_locale_name do
          translated_route =
            Cldr.Routes.interpolate_and_translate_path(route, cldr_locale, gettext_backend)

          quote location: :keep do
            unquote(cldr_locale_name) -> url(unquote(conn_or_socket_or_endpoint_or_uri), unquote(router), sigil_p(unquote(translated_route), []))
          end
        else
          IO.warn(
            "Locale #{inspect(cldr_locale_name)} has no associated gettext locale. Cannot translate #{inspect(route)}",
            []
          )

          nil
        end
      else
        {:error, {exception, reason}} -> raise exception, reason
      end
    end
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&hd/1)
  end
end
