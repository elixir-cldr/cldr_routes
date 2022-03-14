defmodule Cldr.Routes do
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

  require MyAppWeb.Gettext

  @domain "routes"
  @path_separator "/"
  @interpolate ":"

  defmacro localize({verb, meta, [path | args]}) do
    for locale <- Gettext.known_locales(MyAppWeb.Gettext) do
      translated_path = Cldr.Routes.translated_path(path, MyAppWeb.Gettext, locale)
      {verb, meta, [translated_path | args]}
    end
    |> Enum.uniq()
  end

  def translated_path(path, backend, locale) do
    Gettext.put_locale(backend, locale)

    for part <- String.split(path, @path_separator) do
      cond do
        part == "" ->
          part
        String.starts_with?(part, @interpolate) ->
          part
        true ->
          Gettext.dgettext(backend, @domain, part)
      end
    end
    |> Enum.join(@path_separator)
  end
end


