defmodule AztecEx.Code do
  @moduledoc """
  Represents an encoded Aztec barcode symbol.

  Fields:

    * `:matrix` - the `AztecEx.BitMatrix` representing the symbol grid
    * `:compact` - `true` for compact Aztec codes, `false` for full-range
    * `:layers` - number of data layers (1-4 compact, 1-32 full)
    * `:codeword_size` - bit width of Reed-Solomon codewords (6, 8, 10, or 12)
    * `:data_codewords` - number of data codewords in the symbol
    * `:size` - side length of the symbol in modules (pixels)
  """

  @type t :: %__MODULE__{
          matrix: AztecEx.BitMatrix.t() | nil,
          compact: boolean(),
          layers: pos_integer(),
          codeword_size: 6 | 8 | 10 | 12,
          data_codewords: non_neg_integer(),
          size: pos_integer()
        }

  defstruct [
    :matrix,
    :compact,
    :layers,
    :codeword_size,
    :data_codewords,
    :size
  ]
end
