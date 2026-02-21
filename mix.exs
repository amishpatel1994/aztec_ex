defmodule AztecEx.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/amishpatel/aztec_ex"

  def project do
    [
      app: :aztec_ex,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "AztecEx",
      description:
        "Pure Elixir library for encoding and decoding Aztec 2D barcodes (ISO/IEC 24778).",
      source_url: @source_url,
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:stream_data, "~> 1.0", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      licenses: ["GPL-3.0-only"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "AztecEx",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
