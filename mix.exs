defmodule AztecEx.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/amishpatel1994/aztec_ex"

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
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md"],
      groups_for_modules: [
        "Public API": [AztecEx, AztecEx.Code],
        Encoding: [AztecEx.Encoder, AztecEx.HighLevelEncoder, AztecEx.CharTable],
        Decoding: [AztecEx.Decoder, AztecEx.HighLevelDecoder],
        "Error Correction": [
          AztecEx.GaloisField,
          AztecEx.ReedSolomon.Encoder,
          AztecEx.ReedSolomon.Decoder
        ],
        Data: [AztecEx.BitMatrix, AztecEx.BitStuffing],
        Rendering: [AztecEx.Render.SVG, AztecEx.Render.Text]
      ]
    ]
  end
end
