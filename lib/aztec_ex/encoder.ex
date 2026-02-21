defmodule AztecEx.Encoder do
  @moduledoc """
  Aztec barcode encoder that produces a complete symbol as a BitMatrix.

  Orchestrates the full encoding pipeline: high-level encoding,
  symbol sizing, bit stuffing, Reed-Solomon encoding, mode message
  construction, and matrix layout.
  """

  alias AztecEx.{BitMatrix, BitStuffing, HighLevelEncoder}
  alias AztecEx.ReedSolomon

  @compact_sizes [
    {1, 6, 104, 15},
    {2, 6, 250, 19},
    {3, 8, 408, 23},
    {4, 8, 608, 27}
  ]

  @full_sizes (for layers <- 1..32 do
                 cw_bits =
                   cond do
                     layers <= 2 -> 6
                     layers <= 8 -> 8
                     layers <= 22 -> 10
                     true -> 12
                   end

                 total_bits = (112 + 16 * layers) * layers
                 size = 27 + 4 * layers + 2 * div(max(layers - 4, 0) + 14, 15)
                 {layers, cw_bits, total_bits, size}
               end)

  @doc """
  Determines the codeword bit size for the given number of layers.
  """
  @spec codeword_size(pos_integer()) :: 6 | 8 | 10 | 12
  def codeword_size(layers) when layers <= 2, do: 6
  def codeword_size(layers) when layers <= 8, do: 8
  def codeword_size(layers) when layers <= 22, do: 10
  def codeword_size(_layers), do: 12

  @doc """
  Total data bit capacity for a compact Aztec code with the given layers.
  """
  @spec compact_capacity(pos_integer()) :: pos_integer()
  def compact_capacity(layers), do: (88 + 16 * layers) * layers

  @doc """
  Total data bit capacity for a full Aztec code with the given layers.
  """
  @spec full_capacity(pos_integer()) :: pos_integer()
  def full_capacity(layers), do: (112 + 16 * layers) * layers

  @doc """
  Computes the symbol size (side length in modules) for a compact code.
  """
  @spec compact_size(pos_integer()) :: pos_integer()
  def compact_size(layers), do: 11 + 4 * layers

  @doc """
  Computes the symbol size (side length in modules) for a full code.
  """
  @spec full_size(pos_integer()) :: pos_integer()
  def full_size(layers) do
    ref_grid_count = div(max(layers - 4, 0) + 14, 15)
    27 + 4 * layers + 2 * ref_grid_count
  end

  @doc """
  Selects the optimal symbol parameters for the given data bits.

  Returns `{:ok, {compact, layers, cw_size, total_bits, symbol_size}}`
  or `{:error, reason}` if the data is too large.
  """
  @spec select_symbol(list(0 | 1), keyword()) ::
          {:ok, {boolean(), pos_integer(), pos_integer(), pos_integer(), pos_integer()}}
          | {:error, String.t()}
  def select_symbol(data_bits, opts \\ []) do
    ec_ratio = Keyword.get(opts, :error_correction, 0.23)
    min_layers = Keyword.get(opts, :min_layers, 1)
    force_compact = Keyword.get(opts, :compact, nil)

    try_compact = force_compact != false
    try_full = force_compact != true

    compact_result =
      if try_compact do
        find_compact_fit(data_bits, ec_ratio, min_layers)
      else
        nil
      end

    full_result =
      if try_full do
        find_full_fit(data_bits, ec_ratio, min_layers)
      else
        nil
      end

    case {compact_result, full_result} do
      {nil, nil} ->
        {:error, "data too large for Aztec encoding"}

      {compact, nil} ->
        {:ok, compact}

      {nil, full} ->
        {:ok, full}

      {compact, full} ->
        {_, _, _, _, cs} = compact
        {_, _, _, _, fs} = full
        if cs <= fs, do: {:ok, compact}, else: {:ok, full}
    end
  end

  defp find_compact_fit(data_bits, ec_ratio, min_layers) do
    @compact_sizes
    |> Enum.filter(fn {layers, _, _, _} -> layers >= min_layers and layers <= 4 end)
    |> Enum.find_value(fn {layers, cw_bits, _total_bits, symbol_size} ->
      total_capacity = compact_capacity(layers)
      stuffed = BitStuffing.stuff(data_bits, cw_bits)
      padded = BitStuffing.pad(stuffed, cw_bits)
      data_codewords = div(length(padded), cw_bits)
      total_codewords = div(total_capacity, cw_bits)
      check_codewords = total_codewords - data_codewords
      min_check = max(round(total_codewords * ec_ratio), 3)

      if data_codewords <= total_codewords and check_codewords >= min_check do
        {true, layers, cw_bits, total_capacity, symbol_size}
      end
    end)
  end

  defp find_full_fit(data_bits, ec_ratio, min_layers) do
    @full_sizes
    |> Enum.filter(fn {layers, _, _, _} -> layers >= min_layers end)
    |> Enum.find_value(fn {layers, cw_bits, _total_bits, symbol_size} ->
      total_capacity = full_capacity(layers)
      stuffed = BitStuffing.stuff(data_bits, cw_bits)
      padded = BitStuffing.pad(stuffed, cw_bits)
      data_codewords = div(length(padded), cw_bits)
      total_codewords = div(total_capacity, cw_bits)
      check_codewords = total_codewords - data_codewords
      min_check = max(round(total_codewords * ec_ratio), 3)

      if data_codewords <= total_codewords and check_codewords >= min_check do
        {false, layers, cw_bits, total_capacity, symbol_size}
      end
    end)
  end

  @doc """
  Builds the mode message bits for a compact or full Aztec code.

  The mode message encodes the number of layers and data codewords,
  protected by its own Reed-Solomon error correction over GF(16).
  """
  @spec build_mode_message(boolean(), pos_integer(), pos_integer()) :: list(0 | 1)
  def build_mode_message(compact, layers, data_codewords) do
    if compact do
      layer_bits = int_to_bits(layers - 1, 2)
      data_bits = int_to_bits(data_codewords - 1, 6)
      mode_word = layer_bits ++ data_bits

      codewords = BitStuffing.to_codewords(mode_word, 4)
      check = ReedSolomon.Encoder.encode(4, codewords, 5)
      BitStuffing.from_codewords(codewords ++ check, 4)
    else
      layer_bits = int_to_bits(layers - 1, 5)
      data_bits = int_to_bits(data_codewords - 1, 11)
      mode_word = layer_bits ++ data_bits

      codewords = BitStuffing.to_codewords(mode_word, 4)
      check = ReedSolomon.Encoder.encode(4, codewords, 6)
      BitStuffing.from_codewords(codewords ++ check, 4)
    end
  end

  @doc """
  Draws the bull's-eye finder pattern centered at `{cx, cy}` in the matrix.

  Compact codes use a 9x9 core (5 rings), full codes use 13x13 (7 rings).
  """
  @spec draw_finder(BitMatrix.t(), boolean(), non_neg_integer(), non_neg_integer()) ::
          BitMatrix.t()
  def draw_finder(matrix, compact, cx, cy) do
    rings = if compact, do: 4, else: 6

    Enum.reduce(0..rings, matrix, fn ring, mat ->
      value = rem(ring, 2) == 0
      half = ring

      Enum.reduce(-half..half, mat, fn offset, m ->
        m
        |> BitMatrix.set(cx - half, cy + offset, value)
        |> BitMatrix.set(cx + half, cy + offset, value)
        |> BitMatrix.set(cx + offset, cy - half, value)
        |> BitMatrix.set(cx + offset, cy + half, value)
      end)
    end)
  end

  @doc """
  Draws the orientation marks at the four corners of the finder core.

  The corners encode rotation information with 3, 2, 1, and 0 black pixels
  starting from the top-right corner (clockwise).
  """
  @spec draw_orientation(BitMatrix.t(), boolean(), non_neg_integer(), non_neg_integer()) ::
          BitMatrix.t()
  def draw_orientation(matrix, compact, cx, cy) do
    half = if compact, do: 5, else: 7

    matrix
    |> BitMatrix.set(cx - half, cy - half, true)
    |> BitMatrix.set(cx - half + 1, cy - half, true)
    |> BitMatrix.set(cx - half, cy - half + 1, true)
    |> BitMatrix.set(cx + half, cy - half, true)
    |> BitMatrix.set(cx + half, cy - half + 1, true)
    |> BitMatrix.set(cx + half - 1, cy - half, true)
    |> BitMatrix.set(cx + half, cy + half, false)
    |> BitMatrix.set(cx - half, cy + half, true)
  end

  @doc """
  Places the mode message bits around the finder core.
  """
  @spec place_mode_message(
          BitMatrix.t(),
          boolean(),
          list(0 | 1),
          non_neg_integer(),
          non_neg_integer()
        ) :: BitMatrix.t()
  def place_mode_message(matrix, compact, mode_bits, cx, cy) do
    half = if compact, do: 5, else: 7
    positions = mode_message_positions(compact, cx, cy, half)

    positions
    |> Enum.zip(mode_bits)
    |> Enum.reduce(matrix, fn {{x, y}, bit}, mat ->
      BitMatrix.set(mat, x, y, bit == 1)
    end)
  end

  defp mode_message_positions(compact, cx, cy, half) do
    if compact do
      top = for x <- (cx - 3)..(cx + 3), do: {x, cy - half}
      right = for y <- (cy - 3)..(cy + 3), do: {cx + half, y}
      bottom = for x <- (cx + 3)..(cx - 3)//-1, do: {x, cy + half}
      left = for y <- (cy + 3)..(cy - 3)//-1, do: {cx - half, y}
      top ++ right ++ bottom ++ left
    else
      top_l = for x <- (cx - 5)..(cx - 1), do: {x, cy - half}
      top_r = for x <- (cx + 1)..(cx + 5), do: {x, cy - half}
      right_t = for y <- (cy - 5)..(cy - 1), do: {cx + half, y}
      right_b = for y <- (cy + 1)..(cy + 5), do: {cx + half, y}
      bottom_r = for x <- (cx + 5)..(cx + 1)//-1, do: {x, cy + half}
      bottom_l = for x <- (cx - 1)..(cx - 5)//-1, do: {x, cy + half}
      left_b = for y <- (cy + 5)..(cy + 1)//-1, do: {cx - half, y}
      left_t = for y <- (cy - 1)..(cy - 5)//-1, do: {cx - half, y}
      top_l ++ top_r ++ right_t ++ right_b ++ bottom_r ++ bottom_l ++ left_b ++ left_t
    end
  end

  @doc false
  def int_to_bits(value, width) do
    HighLevelEncoder.int_to_bits(value, width)
  end
end
