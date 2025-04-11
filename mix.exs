defmodule Pesapal.MixProject do
  use Mix.Project

  def project do
    [
      app: :pesapal,
      description: "A simple Elixir wrapper for the Pesapal API for payment processing.",
      version: "0.1.1",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "Pesapal"
    ]
  end

  defp package do
    [
      maintainers: ["Michael Munavu"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/MICHAELMUNAVU83/pesapal",
        "Owner Portfolio" => "https://michaelmunavu.com"
      }
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
      {:httpoison, "~> 2.1"},
      {:jason, "~> 1.2"},
      {:timex, "~> 3.7"},
      {:ex_doc, "~> 0.29.4", only: :dev, runtime: false}
    ]
  end
end
