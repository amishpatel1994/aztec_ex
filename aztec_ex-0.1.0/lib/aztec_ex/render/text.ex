defmodule AztecEx.Render.Text do
  @moduledoc """
  Renders an Aztec barcode as a text/Unicode string for terminal display or debugging.
  """

  alias AztecEx.BitMatrix

  @type option ::
          {:dark, String.t()}
          | {:light, String.t()}
          | {:newline, String.t()}

  @doc """
  Renders a BitMatrix as a text string.

  ## Options

    * `:dark` - character for dark modules (default: `"██"`)
    * `:light` - character for light modules (default: `"  "`)
    * `:newline` - line separator (default: `"\\n"`)
  """
  @spec render(BitMatrix.t(), [option()]) :: String.t()
  def render(%BitMatrix{} = matrix, opts \\ []) do
    dark = Keyword.get(opts, :dark, "██")
    light = Keyword.get(opts, :light, "  ")
    newline = Keyword.get(opts, :newline, "\n")

    {w, h} = BitMatrix.dimensions(matrix)

    0..(h - 1)//1
    |> Enum.map(fn y ->
      0..(w - 1)//1
      |> Enum.map(fn x ->
        if BitMatrix.get(matrix, x, y), do: dark, else: light
      end)
      |> Enum.join()
    end)
    |> Enum.join(newline)
  end

  @doc """
  Renders an `AztecEx.Code` struct as a text string.
  """
  @spec render_code(AztecEx.Code.t(), [option()]) :: String.t()
  def render_code(%AztecEx.Code{matrix: matrix}, opts \\ []) do
    render(matrix, opts)
  end
end
