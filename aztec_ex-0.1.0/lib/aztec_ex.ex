defmodule AztecEx do
  @moduledoc """
  Pure Elixir library for encoding and decoding Aztec 2D barcodes
  per ISO/IEC 24778.

  ## Encoding

      {:ok, code} = AztecEx.encode("Hello World")
      code.compact  #=> true
      code.layers   #=> 2

  ## Decoding

      {:ok, data} = AztecEx.decode(code.matrix)
      data  #=> "Hello World"

  ## Rendering

      svg = AztecEx.to_svg(code, module_size: 4, margin: 2)
      text = AztecEx.to_text(code)

  ## Architecture

  The library is split into focused modules:

    * `AztecEx.BitMatrix` - 2D boolean grid for symbol representation
    * `AztecEx.GaloisField` - finite field arithmetic over GF(2^p)
    * `AztecEx.ReedSolomon.Encoder` / `AztecEx.ReedSolomon.Decoder` - error correction
    * `AztecEx.HighLevelEncoder` / `AztecEx.HighLevelDecoder` - character encoding modes
    * `AztecEx.BitStuffing` - bit stuffing and padding per specification
    * `AztecEx.Encoder` - full encoding pipeline (symbol layout)
    * `AztecEx.Decoder` - full decoding pipeline (finder detection, data reading)
    * `AztecEx.Render.SVG` / `AztecEx.Render.Text` - output renderers
  """

  alias AztecEx.Code

  @type encode_option ::
          {:error_correction, float()}
          | {:min_layers, pos_integer()}
          | {:compact, boolean()}

  @doc """
  Encodes binary data into an Aztec barcode.

  ## Options

    * `:error_correction` - minimum error correction ratio (default: `0.23`)
    * `:min_layers` - minimum number of data layers
    * `:compact` - force compact (`true`) or full-range (`false`) symbol

  Returns `{:ok, %AztecEx.Code{}}` on success, `{:error, reason}` on failure.
  """
  @spec encode(binary(), [encode_option()]) :: {:ok, Code.t()} | {:error, String.t()}
  def encode(data, opts \\ []) do
    AztecEx.Encoder.encode(data, opts)
  end

  @doc """
  Decodes an Aztec barcode from a bit matrix.

  The matrix should be an `AztecEx.BitMatrix` where `true` represents
  a dark module and `false` represents a light module.

  Returns `{:ok, binary}` on success, `{:error, reason}` on failure.
  """
  @spec decode(AztecEx.BitMatrix.t()) :: {:ok, binary()} | {:error, String.t()}
  def decode(matrix) do
    AztecEx.Decoder.decode(matrix)
  end

  @doc """
  Renders an encoded Aztec code as an SVG string.

  See `AztecEx.Render.SVG.render_code/2` for available options.
  """
  @spec to_svg(Code.t(), keyword()) :: String.t()
  def to_svg(%Code{} = code, opts \\ []) do
    AztecEx.Render.SVG.render_code(code, opts)
  end

  @doc """
  Renders an encoded Aztec code as a text/Unicode string.

  See `AztecEx.Render.Text.render_code/2` for available options.
  """
  @spec to_text(Code.t(), keyword()) :: String.t()
  def to_text(%Code{} = code, opts \\ []) do
    AztecEx.Render.Text.render_code(code, opts)
  end
end
