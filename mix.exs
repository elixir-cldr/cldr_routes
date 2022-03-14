defmodule CldrRoutes.MixProject do
  use Mix.Project

  def project do
    [
      app: :cldr_routes,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      mix_compilers: Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_cldr, "~> 2.27"},
      {:phoenix, "~> 1.6"},
      {:jason, "~> 1.0"},
      {:gettext, "~> 0.19"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "src", "dev", "mix/support/units", "mix/tasks", "test"]
  defp elixirc_paths(:dev), do: ["lib", "mix", "src", "dev", "bench"]
  defp elixirc_paths(:release), do: ["lib", "dev", "src"]
  defp elixirc_paths(_), do: ["lib", "src"]
end
