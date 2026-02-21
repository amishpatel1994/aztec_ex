defmodule AztecEx.Render.SVG do
  @moduledoc """
  Renders an Aztec barcode as an SVG string.
  """

  alias AztecEx.BitMatrix

  @type option ::
          {:module_size, pos_integer()}
          | {:margin, non_neg_integer()}
          | {:dark_color, String.t()}
          | {:light_color, String.t()}

  @doc """
  Renders a BitMatrix as an SVG string.

  ## Options

    * `:module_size` - pixel size of each module (default: `4`)
    * `:margin` - quiet zone modules around the symbol (default: `1`)
    * `:dark_color` - color for dark modules (default: `"#000000"`)
    * `:light_color` - color for light modules / background (default: `"#FFFFFF"`)
  """
  @spec render(BitMatrix.t(), [option()]) :: String.t()
  def render(%BitMatrix{} = matrix, opts \\ []) do
    module_size = Keyword.get(opts, :module_size, 4)
    margin = Keyword.get(opts, :margin, 1)
    dark = Keyword.get(opts, :dark_color, "#000000")
    light = Keyword.get(opts, :light_color, "#FFFFFF")

    {w, h} = BitMatrix.dimensions(matrix)
    svg_w = (w + 2 * margin) * module_size
    svg_h = (h + 2 * margin) * module_size

    rects =
      for y <- 0..(h - 1)//1,
          x <- 0..(w - 1)//1,
          BitMatrix.get(matrix, x, y) do
        px = (x + margin) * module_size
        py = (y + margin) * module_size

        ~s(<rect x="#{px}" y="#{py}" width="#{module_size}" height="#{module_size}" fill="#{dark}"/>)
      end

    header = [
      ~s(<?xml version="1.0" encoding="UTF-8"?>),
      ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{svg_w} #{svg_h}" width="#{svg_w}" height="#{svg_h}">),
      ~s(<rect width="#{svg_w}" height="#{svg_h}" fill="#{light}"/>)
    ]

    footer = ["</svg>"]

    Enum.join(header ++ rects ++ footer, "\n")
  end

  @doc """
  Renders an `AztecEx.Code` struct as an SVG string.
  """
  @spec render_code(AztecEx.Code.t(), [option()]) :: String.t()
  def render_code(%AztecEx.Code{matrix: matrix}, opts \\ []) do
    render(matrix, opts)
  end
end
