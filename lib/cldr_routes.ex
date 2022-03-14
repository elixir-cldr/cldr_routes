defmodule Cldr.Routes do

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
          end
        end
      end
    end
  end

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

  @domain "routes"
  @path_separator "/"
  @interpolate ":"

  # For nested
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


