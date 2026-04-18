defmodule ExpressLrs.MixProject do
  use Mix.Project

  def project do
    [
      app: :express_lrs,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ExpressLrs.Application, []}
    ]
  end

  defp deps do
    [
      {:circuits_uart, "~> 1.5"},
      {:crc, "~> 0.10"},
      {:saxy, "~> 1.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
