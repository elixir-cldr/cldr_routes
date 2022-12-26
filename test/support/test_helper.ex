defmodule Cldr.Route.TestHelper do
  def find_route(router, path) when is_binary(path) do
    Enum.find(router.__routes__(), &(&1.path == path))
  end

  def find_routes(router, %Regex{} = regex) do
    Enum.filter(router.__routes__(), &Regex.match?(regex, &1.path))
  end
end
