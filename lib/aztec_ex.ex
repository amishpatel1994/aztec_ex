defmodule AztecEx do
  @moduledoc """
  Pure Elixir library for encoding and decoding Aztec 2D barcodes
  per ISO/IEC 24778.

  ## Encoding

      iex> {:ok, code} = AztecEx.encode("Hello")
      iex> code.compact
      true

  ## Decoding

      iex> {:ok, code} = AztecEx.encode("Hello")
      iex> AztecEx.decode(code.matrix)
      {:ok, "Hello"}
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
end
