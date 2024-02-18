defmodule Cldr.Route do
  @doc false

  def cldr_backend_provider(config) do
    IO.warn("Cldr.Route is deprecated. Use Cldr.Routes in the Cldr providers list.", [])
    Cldr.Routes.cldr_backend_provider(config)
  end
end
